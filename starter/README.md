# The ade starter

A setup to start from: copy it, or link it as it is, then make it yours.
Each file says what its parts do.

## What you get

Every git worktree gets a Zellij tab: a shell, OpenCode on the right, and
Helix above the shell once you open a file.

| | |
| --- | --- |
| `wt <branch>` | cd into the branch's worktree, creating it; `-t` goes to its tab, `-b` opens the tab in the background |
| `wt -p "task" <branch>` | a background tab whose OpenCode starts on the task |
| `wtrm`, `wtprune`, `wtls`, `wtclone`, `wtconvert` | remove, prune, list worktrees; clone a repository for worktrees; turn a clone into one (`wthelp`: every option) |
| `Alt-t` | a new tab with the ade layout |
| `Alt-y` | Yazi as a picker; files open in the tab's Helix |
| Helix `+` `a` | the selected lines go to the tab's OpenCode, for your question |
| Helix `Ctrl-r` | reload the files agents changed |
| `Alt-v` | review everything the worktree changed in tuicr; `y` hands your comments to OpenCode, `e` opens a file in Helix |
| "delegate this" | OpenCode starts the work in a new worktree tab |
| "how are the other worktrees doing?" | OpenCode's `status` tool |
| `ocreload` | restart the tab's OpenCode in the current folder |
| tab mode `g`, `G` | collapse or expand the current group of tabs in the bar, or all |

Each tab's name in the top bar starts with its agents' most urgent status
(working, waiting for you, done, failed); done and failed clear once you have
seen the pane. Tabs ade opens are named `project: worktree` and grouped by
project.

## Requirements

Node 24 or newer, git, jq, Zellij 0.46, Helix, OpenCode 2.2.5 or newer,
Yazi, tuicr, and zsh for the shell functions. The GitHub CLI is optional
(`wtprune -m`). A Nerd Font shows the status icons.

## Install

```sh
git clone https://github.com/ag14774/ade ~/.local/share/ade
~/.local/share/ade/starter/link.sh
```

`link.sh` links `ade`, `opencode-pane`, the OpenCode plugins and the files
below into place, so a `git pull` in the clone updates them. A config file
you already have stays as it is; the script lists what to copy into it. Then:

1. Add `source ~/.local/share/ade/starter/shell/ade.zsh` to `~/.zshrc`, after
   `compinit`.
2. `opencode service restart`, so OpenCode's service loads the plugins.
3. Start Zellij. The top bar needs a permission once per release: inside
   Zellij, run `zellij plugin -f -- "<url>"` with the URL from
   `layouts/dev.kdl`, press `y`, and close that pane.

To start Zellij with every terminal, put this at the top of `~/.zshrc`:

```zsh
if [[ -z $ZELLIJ ]] && command -v zellij >/dev/null; then
  zellij attach --create --force-run-commands ade && exit
fi
```

## The files

| File | Linked to | What it does |
| --- | --- | --- |
| `zellij/config.kdl` | `~/.config/zellij/` | `Alt-t`, `Alt-y`, `Alt-v`, tab mode `g`/`G`, the restore hook; only additions to Zellij's defaults |
| `zellij/layouts/dev.kdl` | `~/.config/zellij/layouts/` | the tab: top bar ([ade-zjstatus](https://github.com/ag14774/ade-zjstatus)), shell, OpenCode, and Helix when a file opens |
| `zellij/yazi-picker.sh` | `~/.config/zellij/` | `Alt-y` |
| `zellij/resurrect-command.sh` | `~/.config/zellij/` | which commands a restored session reruns |
| `helix/config.toml` | `~/.config/helix/` | `+ a` and `Ctrl-r` |
| `ade/config.json` | `~/.config/ade/` | OpenCode through `opencode-pane`; tabs named `project: worktree` |
| `opencode/cli.json` | copied to `~/.config/opencode/` | the ade status plugin plays OpenCode's sounds, once, in the right tab |
| `shell/ade.zsh` | sourced from `~/.zshrc` | `wt*`, `ocreload`, completions |
| `bin/opencode-pane` | `~/.local/bin/` | OpenCode in a pane that continues its conversation after a restart |

## Make it yours

- The ADE config (`~/.config/ade/config.json`): the editor, agent, reviewer,
  multiplexer, worktree layout and more; see
  [ade-kit's README](../packages/ade-kit/README.md).
- Adapters of your own, named in the config by their path:
  [AGENTS.md](../AGENTS.md), "Where changes belong".
- Replace a link with a copy of the file to change it without a fork.
