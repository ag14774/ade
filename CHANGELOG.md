# Changelog

What changed, and what to do after pulling. The code and the README describe
only how things are now; this file is where the changes live. Newest first.

## Unreleased: a repository of its own

The packages moved here from
[ag14774/dotfiles](https://github.com/ag14774/dotfiles), with their history
and tests. Nothing changes in how they work.

**If you used them from the dotfiles:** clone this repository, run
`npm install --omit=dev --omit=optional --omit=peer` in it, and point the
`ade` link and the three plugin links in `~/.config/opencode/plugins/` at
its `packages/` (README, "Install"). Then `opencode service restart`.

- `starter/`: a setup to start from, and `starter/link.sh` to link it (or
  with `--core`, only `ade` and the plugins) into place. Zellij's keys
  (`Alt-t`, `Alt-y`, `Alt-v`, tab mode `g`/`G`) as additions to its
  defaults, the tab layout, the picker and the restore hook; Helix's `+ a`
  and `Ctrl-r`; the ADE config; `cli.json`; the `wt*` functions and
  `ocreload` (running `ade` from `PATH`); `opencode-pane` (in your shell if
  it is zsh or bash).
- `ade forget-gone`: the agent forgets the folders that no longer exist.
  OpenCode's service failed its reload on them, so `ocreload` stopped before
  restarting the agent. `ade worktree rm`, `prune` and OpenCode's own
  worktree removals now do it too, and `ocreload` runs it first. After
  pulling: `opencode service restart`. Agent adapters of your own can have a
  `forgetGone`. (Ported from the dotfiles, #2.)
- `ocreload` (restart the tab's agent) is in the starter's `shell/ade.zsh`,
  with the `wt*` functions.
- The test sandbox takes the config under test from `SANDBOX_CONFIG`,
  `SANDBOX_BIN` and `SANDBOX_LAYOUT` (default: the starter), and puts this
  checkout's `ade` on `PATH`.

## 2026-11-16 (in the dotfiles, `cbf95bd`)

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
