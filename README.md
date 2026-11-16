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
- After a restart, every tab comes back, and each agent carries on with its
  conversation.

## What is here

| | |
| --- | --- |
| [`packages/ade-kit`](packages/ade-kit) | the `ade` command and library: adapters for the multiplexer, editor, agent, reviewer and worktree layout, and the worktree commands |
| [`packages/opencode-ade`](packages/opencode-ade) | OpenCode plugin: `show_file`, `delegate` and `status` |
| [`packages/opencode-ade-status`](packages/opencode-ade-status) | OpenCode plugin: done and failed statuses for the tabs, and OpenCode's sounds once, in the right tab |
| [`packages/opencode-ade-worktrees`](packages/opencode-ade-worktrees) | OpenCode plugin: OpenCode's own worktrees through ade-kit |
| [`starter/`](starter) | a setup to start from: Zellij keys, layout and restore hook, Helix keys, the ADE config, the `wt*` shell functions, `link.sh` |
| [`install.sh`](install.sh) | links `ade` and the OpenCode plugins into place |
| `tests/` | the zsh tests, and the sandbox the live ones run in |

## Requirements

Node 24 or newer (the TypeScript runs as it is, with no build step) with npm,
and git. The built-in adapters need Zellij 0.46, Helix, OpenCode 2.2.5 or
newer and tuicr, and the starter also Yazi. The GitHub CLI is optional
(`ade worktree prune -m`).

## Install

From a clone; nothing comes from npm:

```sh
git clone https://github.com/ag14774/ade ~/.local/share/ade
~/.local/share/ade/starter/link.sh
```

[`starter/link.sh`](starter/link.sh) links `ade`, the OpenCode plugins and the
[starter](starter)'s config into place (a config you already have stays) and
says what is left to do: a line in your shell's rc file,
`opencode service restart`, and granting the top bar its permission once.
With a setup of your own, [`install.sh`](install.sh) links only `ade` and the
plugins (and keeps your own config, so a fork's or a dotfiles' installer can
call it).

After a `git pull`: rerun the script, `opencode service restart` (it keeps a
plugin's server part until then; OpenCode panes warn when it runs old code),
and `ade restart-agent --reload` in a tab for its OpenCode to load the new app
part. [CHANGELOG.md](CHANGELOG.md) says what else a change needs.

## Make it yours

- Settings: `~/.config/ade/config.json`, merged key by key over the
  defaults ([ade-kit's README](packages/ade-kit/README.md) lists the keys).
- Behaviour: an adapter file of your own, named in the config by its path. It
  can wrap a built-in (`kit.builtin.multiplexer("zellij")`) and change only
  what you need, so a fork can stay small.
- Your shell: `ade worktree --cwd-file FILE …` writes the folder to go to
  into FILE, for a shell function to `cd` there; `starter/shell/ade.sh` is
  one for bash and zsh.
- [AGENTS.md](AGENTS.md): where changes belong, and the code conventions.

## Development

```sh
npm install      # links the workspaces, with the dev dependencies
npm test         # every test that needs no Zellij session, OpenCode service or model
npm run check    # tsc, strict
npm run format   # Prettier, and shfmt for the shell scripts
```

The tests need zsh and jq. The live ones take a few minutes each. They run in
a sandbox (`tests/lib/zellij-sandbox.zsh`: their own Zellij server, HOME and
OpenCode service), so they never reach your session or service. They test the
starter's config, or yours with `SANDBOX_CONFIG` (see the starter's README).

| After changing | Run |
| --- | --- |
| `opencode-ade`, `opencode-ade-status`, OpenCode (upgrade) | `zsh tests/ade_plugin_smoke.zsh` (nine short model calls, with your OpenCode provider config) |
| `opencode-ade-status`'s sounds, OpenCode (upgrade) | `zsh tests/opencode_attention_smoke.zsh` |
| `opencode-ade-worktrees`, `ade worktree`, `ade forget-gone`, `ade restart-agent --reload` | `zsh tests/opencode_worktrees_smoke.zsh` (no Zellij) |
| `ade agent`, the starter's layout or restore hook, Zellij, Helix or OpenCode (upgrade) | `zsh tests/zellij_restore_smoke.zsh` |
| the keys and their scripts, Zellij, Helix, Yazi or tuicr (upgrade) | `zsh tests/keys_smoke.zsh` (a stand-in for OpenCode) |

## License

MIT
