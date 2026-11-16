# Changelog

What changed, and what to do after pulling. The code and the README describe
only how things are now; this file is where the changes live. Newest first.

## Unreleased: a repository of its own

The packages moved here from
[ag14774/dotfiles](https://github.com/ag14774/dotfiles), with their history
and tests, and the agent panes no longer need a script of their own.

**After pulling, in this order:**

1. Rerun `./install.sh` in your clone (`starter/link.sh` with the starter),
   or, coming from the dotfiles, their `install.sh`, which runs it. It links
   `ade` and the three plugins from this clone.
2. If you copied the starter's files: drop `"command": ["opencode-pane"]`
   from your ADE config and `~/.local/bin/opencode-pane`, use the layout's
   new agent pane (`ade agent`) and restore hook, and source
   `starter/shell/ade.sh` instead of `ade.zsh` (`ocreload` is gone:
   `ade restart-agent` starts a fresh agent in the current folder).
3. `opencode service restart` (interrupts running conversations), then
   `ade restart-agent` in each tab, so its agent pane runs `ade agent`. A
   saved session's panes still name `opencode-pane`: until each tab has been
   restarted, a restored agent pane closes; `ade restart-agent` in that tab
   brings it back.

**What changes for you:**

- `ade agent [--session ID] [--prompt TEXT]` runs the agent panes ade and the
  starter's layout start. It runs again as `ade agent --resume`, which is what
  Zellij saves: a restored pane carries on with its folder's latest
  conversation and never gets its task again. It replaces the starter's
  `opencode-pane` script; the ADE config needs no `opencode.command` for it.
- The starter's `ocreload` is gone. `ade restart-agent` starts a fresh agent,
  on a new conversation, in the current folder; it never reloads the agent's
  configuration for every pane (OpenCode: `opencode reload`, which cancels
  the questions waiting in every tab).
- `ade worktree rm`, `prune` and OpenCode's own worktree removals have the
  agent forget the removed worktree: OpenCode's service failed its reload on
  folders that are gone. (From the dotfiles,
  [ag14774/dotfiles#2](https://github.com/ag14774/dotfiles/pull/2), without
  its `ade forget-gone` command.)
- Removing a worktree no longer strands its conversations in a folder that
  is gone, where every prompt failed. `ade worktree rm`, `prune` and
  OpenCode's own removals (the agents' `worktree_remove`) move the idle ones
  to the default branch's worktree (the project folder when that is the one
  removed), and refuse a worktree with a running conversation, `-f` or not,
  naming it: a running conversation moves only at the end of its step, after
  the folder is gone. An agent removing its own worktree moves out first
  (`session_move`), then removes it in a later step; the ADE plugin's
  instructions say so.
- Agent adapters of your own can have `resume`, `forgetGone`,
  `conversationsIn` and `moveConversations`.
- `starter/`: a setup to copy and own, with `starter/link.sh`, which runs
  `install.sh` and links the starter's config into place: Zellij's keys
  (`Alt-t`, `Alt-y`, `Alt-v`, tab mode `g`/`G`) as additions to its defaults,
  the tab layout, the picker and the restore hook; Helix's `+ a` and
  `Ctrl-r`; the ADE config; `cli.json`; and the `wt*` functions in POSIX
  shell (`shell/ade.sh`, for bash and zsh).
- `install.sh` links `ade` and the plugins (npm links the packages first,
  downloading nothing), and stops with a message for a Node older than 24 or
  a missing npm. Node 24 or newer is required.
- The test sandbox takes the config under test from `SANDBOX_CONFIG`,
  `SANDBOX_BIN` and `SANDBOX_LAYOUT` (default: the starter), and puts this
  checkout's `ade` on `PATH`. `tests/zellij_restore_smoke.zsh` moved here from
  the dotfiles.

## 2026-11-16: a review (in the dotfiles, [`cbf95bd`](https://github.com/ag14774/dotfiles/commit/cbf95bdd4207b08d3616a9de13ed4d64618af81a))

A review: clearer packages, fewer leftovers, the same daily flow.

**After pulling:** link the packages before OpenCode reloads its plugins
(without `node_modules/ade-kit` they can't load):
`npm install --omit=dev --omit=optional --omit=peer`. Then
`opencode service restart`, and restart the OpenCode panes.

**What changes for you:**

- OpenCode 2 is required.
- Seed settings are renamed: `WT_SEED` → `ADE_SEED`, `WT_SEED_FILE` →
  `ADE_SEED_FILE`, and a repository's `<common-dir>/wt-seed` →
  `<common-dir>/ade-seed`. The old names are ignored; rename yours.
- Messages and help say `ade worktree …` instead of `wt`, `wtrm` and the
  like.
- `ade workspace`, `ade tabs` and `ade close-tabs` are removed.
- New: `ade restart-agent` (replaces the tab's agent) and `ade where` (the
  folder of the pane you were in).
- `zellij.newPanes` in the ADE config: where a new pane of a role opens. A
  new agent pane opens on the right by default.
- `ade review` and the `status` tool count changes from `worktrees.base`
  (default `origin/HEAD`), the same base new branches start from.
- Your own adapters get `kit.git`, `kit.fail` and
  `kit.builtin.multiplexer`, so a custom layout or a wrapped multiplexer
  needs no fork. Plugins import `"ade-kit"`.
- New: an MIT licence, a README per package, `npm test`, `npm run check` and
  `npm run format`.
