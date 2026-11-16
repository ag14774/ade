import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { fileURLToPath } from "node:url"
import { test } from "node:test"

const cli = fileURLToPath(new URL("../src/cli.ts", import.meta.url))
const ade = (...args: string[]) =>
  spawnSync(process.execPath, [cli, ...args], { encoding: "utf8", env: { ...process.env, ZELLIJ: "" } })

test("ade help names every command", () => {
  const help = ade("help")
  assert.equal(help.status, 0)
  for (const command of ["open", "send", "review", "agent", "restart-agent", "where", "worktree"])
    assert.match(help.stdout, new RegExp(`^(usage: | {7})ade ${command}( |$)`, "m"))
})

test("wrong usage: the usage on stderr, exit status 2", () => {
  for (const args of [
    ["nonsense"],
    ["open"],
    ["review", "x"],
    ["restart-agent", "a", "b"],
    ["agent", "--prompt"],
    ["agent", "--resume", "x"],
    ["agent", "--model", "m"],
    ["where", "x"],
    ["tabs", "."],
  ]) {
    const result = ade(...args)
    assert.equal(result.status, 2, args.join(" "))
    assert.match(result.stderr, /^usage: ade open/)
  }
})

test("the actions in a tab need a multiplexer session: exit status 1, saying so", () => {
  const result = ade("restart-agent")
  assert.equal(result.status, 1)
  assert.equal(result.stderr, "ade restart-agent: not inside Zellij\n")
})

test("ade works from a folder that is gone (ade worktree rm run inside the worktree it removes)", () => {
  const gone = mkdtempSync(join(realpathSync(tmpdir()), "ade-gone-"))
  const result = spawnSync(
    "sh",
    ["-c", 'cd "$1" && rmdir "$1" && exec "$2" "$3" restart-agent /', "sh", gone, process.execPath, cli],
    {
      encoding: "utf8",
      env: { ...process.env, ZELLIJ: "" },
    },
  )
  assert.equal(result.stderr, "ade restart-agent: not inside Zellij\n")
})

// A stand-in for OpenCode: `opencode api get` answers $SESSIONS; otherwise it
// prints its arguments, what is left of ade agent's start in its environment,
// and its parent's command line (what a multiplexer saves for the pane).
const agentHome = realpathSync(mkdtempSync(join(tmpdir(), "ade-agent-cli-")))
mkdirSync(join(agentHome, "bin"))
writeFileSync(
  join(agentHome, "bin", "opencode"),
  `#!/bin/sh
if [ "$1" = api ]; then printf '%s\\n' "$SESSIONS"; exit 0; fi
echo "args: $*"
echo "start: \${ADE_AGENT_START-none}"
echo "parent: $(ps -o args= -p $PPID)"
exit \${EXIT:-0}
`,
)
chmodSync(join(agentHome, "bin", "opencode"), 0o755)
writeFileSync(join(agentHome, "config.json"), "{}\n")
const agent = (args: string[], env: Record<string, string> = {}) =>
  spawnSync(process.execPath, [cli, "agent", ...args], {
    encoding: "utf8",
    cwd: agentHome,
    env: {
      ...process.env,
      ZELLIJ: "",
      ADE_CONFIG: join(agentHome, "config.json"),
      PATH: `${join(agentHome, "bin")}:${process.env.PATH}`,
      SESSIONS: '{"data":[]}',
      ...env,
    },
  })

test("ade agent: the agent on the start given, run as `ade agent --resume` with the start out of sight", () => {
  const result = agent(["--session", "ses_1", "--prompt", "do it"])
  assert.equal(result.status, 0, result.stderr)
  const [args, start, parent] = result.stdout.trim().split("\n")
  assert.equal(args, "args: --session ses_1 --prompt do it")
  assert.equal(start, "start: none")
  assert.match(parent, / agent --resume$/)
  assert.doesNotMatch(parent, /do it/)
})

test("ade agent --resume: carries on with the folder's latest conversation, else starts afresh; the agent's exit status", () => {
  const resumed = agent(["--resume"], { SESSIONS: '{"data":[{"id":"ses_1"}]}' })
  assert.equal(resumed.stdout.split("\n")[0], "args: --continue")
  const fresh = agent(["--resume"], { EXIT: "3" })
  assert.equal(fresh.stdout.split("\n")[0], "args: ")
  assert.equal(fresh.status, 3)
})
