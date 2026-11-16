# ade

A terminal agentic development environment: one tab per git worktree, with
your editor, coding agent and reviewer wired together. It ships with Zellij,
Helix, OpenCode and tuicr; each is an adapter you can swap. Made to fork.

- `wt -p "fix the flaky test" fix-flaky` opens a tab for a new worktree, with
  OpenCode already working on the task.
- From Helix, send a selection to the tab's agent; the agent opens files in
  your editor.
- Review everything a worktree changed in tuicr, and hand your comments to
  the agent.
- Ask the agent to delegate work to a new worktree tab, or how the other
  worktrees are doing.
- The top bar ([ade-zjstatus](https://github.com/ag14774/ade-zjstatus)) shows
  what every tab's agents are doing.

## What is here

|                                                                      |                                                                                                                                     |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| [`packages/ade-kit`](packages/ade-kit)                               | the `ade` command and library: adapters for the multiplexer, editor, agent, reviewer and worktree layout, and the worktree commands |
| [`packages/opencode-ade`](packages/opencode-ade)                     | OpenCode plugin: `show_file`, `delegate` and `status`                                                                               |
| [`packages/opencode-ade-status`](packages/opencode-ade-status)       | OpenCode plugin: done and failed statuses for the tabs, and OpenCode's sounds once, in the right tab                                |
| [`packages/opencode-ade-worktrees`](packages/opencode-ade-worktrees) | OpenCode plugin: OpenCode's own worktrees through ade-kit                                                                           |
| `starter/`                                                           | a setup to start from (in progress): the ADE config, the `wt*` shell functions and `ocreload`, `opencode-pane`, the tab layout                     |
| `tests/`                                                             | the zsh tests, and the sandbox the live ones run in                                                                                 |

## Requirements

Node 23.6 or newer (the TypeScript runs as it is, with no build step), git,
Zellij 0.46, Helix, OpenCode 2.2.5 or newer, tuicr, Yazi and jq. The GitHub CLI
is optional (`ade worktree prune -m`).

## Install

From a clone; nothing comes from npm:

```sh
git clone https://github.com/ag14774/ade ~/.local/share/ade
cd ~/.local/share/ade
npm install --omit=dev --omit=optional --omit=peer   # links the packages, downloads nothing
ln -s ~/.local/share/ade/packages/ade-kit/src/cli.ts ~/.local/bin/ade
mkdir -p ~/.config/opencode/plugins
for p in ade ade-status ade-worktrees; do
  ln -s ~/.local/share/ade/packages/opencode-$p ~/.config/opencode/plugins/$p
done
```

Then `opencode service restart`, so the service loads the plugins. Add
`"-opencode.notifications"` to the `plugins` list in
`~/.config/opencode/cli.json` so that opencode-ade-status plays the sounds
instead of OpenCode. Wiring Zellij, Helix and your shell to `ade` is what the
starter is for; until it is complete, see each package's README.

## Make it yours

- Settings: `~/.config/ade/config.json`, merged key by key over the
  defaults ([ade-kit's README](packages/ade-kit/README.md) lists the keys).
- Behaviour: an adapter file of your own, named in the config by its path. It
  can wrap a built-in (`kit.builtin.multiplexer("zellij")`) and change only
  what you need, so a fork can stay small.
- [AGENTS.md](AGENTS.md): where changes belong, and the code conventions.
- [CHANGELOG.md](CHANGELOG.md): what changed, and what to do after pulling.

## Development

```sh
npm install      # links the workspaces, with the dev dependencies
npm test         # every test that needs no Zellij session, OpenCode service or model
npm run check    # tsc, strict
npm run format   # Prettier, and shfmt for the shell scripts
```

The live tests take a few minutes each. They run in a sandbox
(`tests/lib/zellij-sandbox.zsh`: their own Zellij server, HOME and OpenCode
service, with the starter's config), so they never reach your session or
service.

| After changing                                                     | Run                                                                                           |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `opencode-ade`, `opencode-ade-status`, OpenCode (upgrade)          | `zsh tests/ade_plugin_smoke.zsh` (nine short model calls, with your OpenCode provider config) |
| `opencode-ade-status`'s sounds, OpenCode (upgrade)                 | `zsh tests/opencode_attention_smoke.zsh`                                                      |
| `opencode-ade-worktrees`, `ade worktree`, `ade forget-gone`, `ocreload` | `zsh tests/opencode_worktrees_smoke.zsh` (no Zellij) |
| the keys and their scripts, Zellij, Helix, Yazi or tuicr (upgrade) | `zsh tests/keys_smoke.zsh` (needs the starter's Zellij and Helix config; not yet)             |

## License

MIT
