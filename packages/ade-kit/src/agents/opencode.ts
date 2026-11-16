// OpenCode, reached through its pane: its app has no way to take text from
// outside yet (2.2.5 handles a `tui.prompt.append` event, but nothing outside
// the app can send it), so text is pasted. OpenCode shows a paste of 3 lines
// or more, or 150 characters or more, as "[Pasted ~N lines]" and sends its
// text. Options: "opencode": { "command": [...] } starts it (default:
// opencode).
//
// Its shared service keeps a location for every folder it served, also once
// the folder is gone, and its reload (`opencode reload`) then fails with
// "Directory not found" (2.2.5). forgetGone evicts those locations through
// the service's API. A conversation (a session) located in a folder that is
// gone fails on its next step, and every prompt after that; one that isn't
// running can be moved elsewhere at any time (moveConversations), while a
// running one is moved only at the end of its current step. Only a running
// service is asked: `opencode api` would start one. resume is the exception:
// the agent it answers for is about to start the service anyway.
import { realpathSync, statSync } from "node:fs"
import type { Agent, Conversation, Kit, RunResult } from "../types.ts"

type Env = Record<string, string | undefined>

const LOCATIONS = "/api/debug/location"
const SESSIONS = "/api/session"
const PAGE = 1000 // sessions per request
const MOVING = 4 // moves at a time

const isDirectory = (path: string) => statSync(path, { throwIfNoEntry: false })?.isDirectory() ?? false
const firstLine = (text: string) => text.trim().split("\n")[0]
const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value)
const parsed = (text: string): unknown => {
  try {
    return JSON.parse(text)
  } catch {
    return undefined
  }
}
// Why a request failed: the message of the error the service answered with,
// else what `opencode api` said.
const why = (result: RunResult) => {
  const answer = parsed(result.stdout)
  if (isObject(answer) && typeof answer.message === "string") return firstLine(answer.message)
  return firstLine(result.stderr || result.stdout)
}
// The folder itself, or one inside it.
const within = (path: string, dir: string) => path === dir || path.startsWith(dir.endsWith("/") ? dir : `${dir}/`)
const real = (path: string) => {
  try {
    return realpathSync(path)
  } catch {
    return path
  }
}

export default (kit: Kit) => {
  const options = kit.config.opencode as { command?: unknown } | undefined
  const command = options?.command ?? ["opencode"]
  if (!Array.isArray(command) || !command.length || command.some((word) => typeof word !== "string"))
    throw new Error("ade: opencode.command must be a list of strings")
  const opencode = (args: string[], env: Env) => kit.run(["opencode", ...args], { env })
  const serving = async (env: Env) => {
    const status = await opencode(["service", "status"], env)
    return status.ok && /^https?:\/\//.test(status.stdout.trim())
  }
  // The service's answer to `GET path`, if `fits` it; else an error saying
  // what could not be done.
  const get = async <T>(path: string, env: Env, fits: (answer: unknown) => answer is T, what: string) => {
    const result = await opencode(["api", "get", path], env)
    const answer = parsed(result.stdout)
    if (!result.ok || !fits(answer)) throw new Error(`could not ${what}: ${why(result)}`)
    return answer
  }
  type Session = { id?: unknown; title?: unknown; parentID?: unknown; location?: { directory?: unknown } }
  type Page = { data: Session[]; cursor?: { next?: unknown } }
  const isPage = (answer: unknown): answer is Page => isObject(answer) && Array.isArray(answer.data)
  type Active = { data: Record<string, unknown> }
  const isActive = (answer: unknown): answer is Active => isObject(answer) && isObject(answer.data)
  return {
    ...kit.pasteAgent({
      name: "opencode",
      label: "OpenCode",
      start: (o) => [
        ...(command as string[]),
        ...(o.session ? ["--session", o.session] : []),
        ...(o.prompt ? ["--prompt", o.prompt] : []),
      ],
    }),
    // OpenCode marks the commands its agents run.
    ranByAgent: (env) => Boolean(env.OPENCODE_TERMINAL),
    // --continue, when the folder has a top-level conversation to carry on.
    resume: async (dir, env) => {
      const path = `${SESSIONS}?limit=1&order=desc&parentID=null&directory=${encodeURIComponent(dir)}`
      const result = await opencode(["api", "get", path], env)
      const answer = parsed(result.stdout)
      return result.ok && isPage(answer) && answer.data.length ? [...(command as string[]), "--continue"] : undefined
    },
    forgetGone: async (env) => {
      if (!(await serving(env))) return []
      const locations = await get(LOCATIONS, env, Array.isArray, "list OpenCode's locations")
      const gone = (locations as { directory?: unknown }[])
        .map((location) => location?.directory)
        .filter((dir): dir is string => typeof dir === "string" && !isDirectory(dir))
      for (const dir of gone) {
        const evicted = await opencode(
          ["api", "delete", `${LOCATIONS}?location%5Bdirectory%5D=${encodeURIComponent(dir)}`],
          env,
        )
        if (!evicted.ok) throw new Error(`OpenCode could not let go of ${dir}: ${why(evicted)}`)
      }
      return gone
    },
    // Every session, archived ones too, page by page until one comes back
    // empty. The service's own filter matches only a session located in the
    // folder itself, and as it was given (not resolving links).
    conversationsIn: async (dir, env) => {
      if (!(await serving(env))) return []
      const sessions: Session[] = []
      for (let cursor = ""; ;) {
        const after = cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""
        const page = await get(`${SESSIONS}?limit=${PAGE}${after}`, env, isPage, "list OpenCode's conversations")
        sessions.push(...page.data)
        const next = page.cursor?.next
        if (!page.data.length || typeof next !== "string" || next === cursor) break
        cursor = next
      }
      const resolved = real(dir)
      const inside = sessions.filter((session) => {
        const at = session?.location?.directory
        if (typeof session?.id !== "string" || typeof at !== "string") return false
        return within(at, dir) || within(real(at), resolved)
      })
      if (!inside.length) return []
      const active = await get(`${SESSIONS}/active`, env, isActive, "ask OpenCode which conversations are running")
      return inside.map((session): Conversation => {
        const id = session.id as string
        return {
          id,
          title: typeof session.title === "string" ? session.title : "",
          running: Object.hasOwn(active.data, id),
          ...(typeof session.parentID === "string" ? { parent: session.parentID } : {}),
        }
      })
    },
    // A session moves alone, without its subagents' sessions.
    moveConversations: async (ids, dir, env) => {
      if (!(await serving(env)))
        throw new Error(`OpenCode's service stopped; its conversations were not moved to ${dir}`)
      const failed: string[] = []
      const body = JSON.stringify({ directory: dir })
      let next = 0
      const mover = async () => {
        while (next < ids.length) {
          const id = ids[next++]
          const moved = await opencode(
            ["api", "post", `${SESSIONS}/${encodeURIComponent(id)}/move`, "--data", body],
            env,
          )
          if (!moved.ok) failed.push(`${id}: ${why(moved)}`)
        }
      }
      await Promise.all(Array.from({ length: Math.min(MOVING, ids.length) }, mover))
      if (failed.length)
        throw new Error(
          `OpenCode could not move ${failed.length} of ${ids.length} conversations to ${dir}: ${failed.join("; ")}`,
        )
    },
  } satisfies Agent
}
