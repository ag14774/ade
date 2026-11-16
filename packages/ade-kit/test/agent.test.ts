import assert from "node:assert/strict"
import { mkdirSync, mkdtempSync, realpathSync, symlinkSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { test } from "node:test"
import { pasteAgent } from "../src/agent.ts"
import opencode from "../src/agents/opencode.ts"
import { DEFAULTS } from "../src/config.ts"
import { makeKit } from "../src/kit.ts"
import type { Config, Key, Multiplexer, RunResult } from "../src/types.ts"

const workspace = { dir: "/w", session: "ade-12345678" }

// A multiplexer that only records what it was asked to paste and type.
const recorder = () => {
  const calls: unknown[][] = []
  const mux = {
    paste: async (pane: string, text: string) => void calls.push(["paste", pane, text]),
    type: async (pane: string, keys: Key[]) => void calls.push(["type", pane, keys]),
  } as unknown as Multiplexer
  return { mux, calls }
}

test("pasteAgent: insert pastes into the agent's pane; submit pastes, then presses Enter", async () => {
  const agent = pasteAgent({ name: "claude-code", label: "Claude Code", start: () => ["claude"] })
  const { mux, calls } = recorder()
  await agent.insert("a question", { workspace, mux, pane: "3" })
  await agent.submit("comments", { workspace, mux, pane: "3" })
  assert.deepEqual(calls, [
    ["paste", "3", "a question"],
    ["paste", "3", "comments"],
    ["type", "3", [{ key: "enter" }]],
  ])
  assert.deepEqual(agent.start({}), ["claude"])
  await assert.rejects(
    agent.insert("x", { workspace }),
    /^Error: Claude Code is reached through its pane, which needs a multiplexer$/,
  )
})

test("OpenCode: pasted into; started with the configured command, on a conversation or a prompt; marks its agents' commands", () => {
  const plain = opencode(makeKit({ config: DEFAULTS }))
  assert.deepEqual([plain.name, plain.label], ["opencode", "OpenCode"])
  assert.deepEqual(plain.start({}), ["opencode"])
  const config = { ...DEFAULTS, opencode: { command: ["opencode-pane"] } } as Config
  assert.deepEqual(opencode(makeKit({ config })).start({ session: "ses_1", prompt: "go" }), [
    "opencode-pane",
    "--session",
    "ses_1",
    "--prompt",
    "go",
  ])
  assert.equal(plain.ranByAgent?.({ OPENCODE_TERMINAL: "1" }), true)
  assert.equal(plain.ranByAgent?.({ OPENCODE_TERMINAL: "" }), false)
  assert.equal(plain.ranByAgent?.({}), false)
  for (const command of ["opencode", [], [1]])
    assert.throws(
      () => opencode(makeKit({ config: { ...DEFAULTS, opencode: { command } } as Config })),
      /opencode\.command must be a list of strings/,
    )
})

// OpenCode, its CLI answering each command (by its arguments) as given, and
// the commands it ran (anything else succeeds with no output).
const opencodeAnswering = (answers: Record<string, RunResult>) => {
  const ran: { argv: string[]; env?: Record<string, string | undefined> }[] = []
  const run = async (argv: string[], o?: { env?: Record<string, string | undefined> }) => {
    ran.push({ argv, env: o?.env })
    return answers[argv.slice(1).join(" ")] ?? { ok: true, stdout: "", stderr: "" }
  }
  return { agent: opencode(makeKit({ config: DEFAULTS, run })), ran }
}
const ok = (stdout: string) => ({ ok: true, stdout, stderr: "" })
const failed = (stderr: string) => ({ ok: false, stdout: "", stderr })

test("OpenCode forgetGone: a stopped service, or no opencode, is asked nothing more (opencode api would start one)", async () => {
  for (const status of [ok("stopped\n"), failed("spawn opencode ENOENT")]) {
    const { agent, ran } = opencodeAnswering({ "service status": status })
    assert.deepEqual(await agent.forgetGone?.({}), [])
    assert.deepEqual(
      ran.map((r) => r.argv),
      [["opencode", "service", "status"]],
    )
  }
})

test("OpenCode forgetGone: the running service evicts only the locations whose folders are gone; failures say why", async () => {
  const here = realpathSync(mkdtempSync(join(tmpdir(), "ade-agent-")))
  const gone = join(here, "removed worktree")
  const evict = `api delete /api/debug/location?location%5Bdirectory%5D=${encodeURIComponent(gone)}`
  const running = {
    "service status": ok("http://127.0.0.1:4096\n"),
    "api get /api/debug/location": ok(JSON.stringify([{ directory: here }, { directory: gone }])),
  }
  const env = { HOME: "/home/me" }
  const { agent, ran } = opencodeAnswering(running)
  assert.deepEqual(await agent.forgetGone?.(env), [gone])
  assert.deepEqual(
    ran.map((r) => r.argv.slice(1).join(" ")),
    ["service status", "api get /api/debug/location", evict],
  )
  assert.ok(ran.every((r) => r.env === env))
  for (const [listed, why] of [
    [failed("Error: Not Found\n    at cli.api"), "Error: Not Found"],
    [ok("<!doctype html>\n<html>"), "<!doctype html>"],
  ] as const)
    await assert.rejects(
      opencodeAnswering({ ...running, "api get /api/debug/location": listed }).agent.forgetGone!({}),
      new Error(`could not list OpenCode's locations: ${why}`),
    )
  await assert.rejects(
    opencodeAnswering({ ...running, [evict]: failed("Error: boom") }).agent.forgetGone!({}),
    new Error(`OpenCode could not let go of ${gone}: Error: boom`),
  )
})

test("OpenCode conversations: a stopped service, or no opencode, is asked nothing more, and nothing is moved", async () => {
  for (const status of [ok("stopped\n"), failed("spawn opencode ENOENT")]) {
    const { agent, ran } = opencodeAnswering({ "service status": status })
    assert.deepEqual(await agent.conversationsIn?.("/w/feat", {}), [])
    await assert.rejects(
      agent.moveConversations!(["ses_a"], "/w/main", {}),
      new Error("OpenCode's service stopped; its conversations were not moved to /w/main"),
    )
    assert.deepEqual(
      ran.map((r) => r.argv),
      [
        ["opencode", "service", "status"],
        ["opencode", "service", "status"],
      ],
    )
  }
})

test("OpenCode conversationsIn: every session, page by page, located in the folder or inside it (also through a link), running or not", async () => {
  const here = realpathSync(mkdtempSync(join(tmpdir(), "ade-agent-")))
  const feat = join(here, "feat")
  mkdirSync(join(feat, "sub"), { recursive: true })
  symlinkSync(feat, join(here, "link"))
  const session = (id: string, directory: string, more: object = {}) => ({
    id,
    title: id.slice(4),
    location: { directory },
    time: { created: 1, updated: 1 },
    ...more,
  })
  const first = "/api/session?limit=1000"
  const page = (sessions: unknown[], next: string) => ok(JSON.stringify({ data: sessions, cursor: { next } }))
  const running = {
    "service status": ok("http://127.0.0.1:4096\n"),
    [`api get ${first}`]: page(
      [
        session("ses_plan", feat),
        session("ses_task", join(feat, "sub"), { parentID: "ses_plan" }),
        session("ses_linked", join(here, "link")),
        session("ses_beside", `${feat}-2`),
        session("ses_elsewhere", "/elsewhere"),
        { id: "ses_nowhere" },
      ],
      "c1",
    ),
    [`api get ${first}&cursor=c1`]: page(
      [session("ses_old", feat, { time: { created: 0, updated: 0, archived: 5 } })],
      "c2",
    ),
    [`api get ${first}&cursor=c2`]: page([], "c3"),
    "api get /api/session/active": ok(JSON.stringify({ data: { ses_linked: { type: "running" } } })),
  }
  const env = { HOME: "/home/me" }
  const { agent, ran } = opencodeAnswering(running)
  assert.deepEqual(await agent.conversationsIn?.(feat, env), [
    { id: "ses_plan", title: "plan", running: false },
    { id: "ses_task", title: "task", running: false, parent: "ses_plan" },
    { id: "ses_linked", title: "linked", running: true },
    { id: "ses_old", title: "old", running: false },
  ])
  assert.deepEqual(
    ran.map((r) => r.argv.slice(1).join(" ")),
    [
      "service status",
      `api get ${first}`,
      `api get ${first}&cursor=c1`,
      `api get ${first}&cursor=c2`,
      "api get /api/session/active",
    ],
  )
  assert.ok(ran.every((r) => r.env === env))
  // None there: the service isn't asked which are running.
  const elsewhere = opencodeAnswering(running)
  assert.deepEqual(await elsewhere.agent.conversationsIn?.(join(here, "other"), env), [])
  assert.ok(!elsewhere.ran.some((r) => r.argv.includes("/api/session/active")))
  for (const [answers, why] of [
    [
      { [`api get ${first}`]: failed("HTTP 401 Unauthorized") },
      "could not list OpenCode's conversations: HTTP 401 Unauthorized",
    ],
    [{ [`api get ${first}`]: ok("[]") }, "could not list OpenCode's conversations: []"],
    [
      { "api get /api/session/active": failed("HTTP 500 Internal Server Error") },
      "could not ask OpenCode which conversations are running: HTTP 500 Internal Server Error",
    ],
  ] as const)
    await assert.rejects(opencodeAnswering({ ...running, ...answers }).agent.conversationsIn!(feat, {}), new Error(why))
})

test("OpenCode moveConversations: each session is moved to the folder; failures say which and why", async () => {
  const move = (id: string) => `api post /api/session/${id}/move --data {"directory":"/w/main"}`
  const running = { "service status": ok("http://127.0.0.1:4096\n") }
  const env = { HOME: "/home/me" }
  const { agent, ran } = opencodeAnswering(running)
  await agent.moveConversations?.(["ses_a", "ses_b", "ses_c", "ses_d", "ses_e"], "/w/main", env)
  const calls = ran.map((r) => r.argv.slice(1).join(" "))
  assert.equal(calls[0], "service status")
  assert.deepEqual(calls.slice(1).sort(), ["ses_a", "ses_b", "ses_c", "ses_d", "ses_e"].map(move))
  assert.ok(ran.every((r) => r.env === env))
  // The service's own message (on stdout, as `opencode api` prints it), else what opencode said.
  const notFound = {
    ok: false,
    stdout: JSON.stringify({ _tag: "SessionNotFoundError", message: "Session not found: ses_b" }),
    stderr: "HTTP 404 Not Found",
  }
  await assert.rejects(
    opencodeAnswering({ ...running, [move("ses_b")]: notFound }).agent.moveConversations!(
      ["ses_a", "ses_b"],
      "/w/main",
      {},
    ),
    new Error("OpenCode could not move 1 of 2 conversations to /w/main: ses_b: Session not found: ses_b"),
  )
})
