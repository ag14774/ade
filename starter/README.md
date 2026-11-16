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
| `ade restart-agent --reload` | restart the tab's OpenCode in the current folder, after its service reloads its configuration and plugins |
| tab mode `g`, `G` | collapse or expand the current group of tabs in the bar, or all |

Each tab's name in the top bar starts with its agents' most urgent status
(working, waiting for you, done, failed); done and failed clear once you have
seen the pane. Tabs ade opens are named `project: worktree` and grouped by
project.

The `wt*` names are shell functions (`shell/ade.sh`) because only the shell
can change its own folder; everything else they do is `ade worktree`, which
works from any shell or script.

## Restarts

Zellij saves the session every minute, and a session started with
`--force-run-commands` comes back with its tabs, panes and folders after a
reboot, a crash or `Ctrl-q`. The restore hook (`zellij/resurrect-command.sh`)
decides what reruns: Helix reopens its files, a plain `opencode` carries on
with its folder's latest conversation, and other commands come back as
shells. OpenCode panes started by ade or the layout run `ade agent`, which
Zellij saves as `ade agent --resume`: they carry on with their conversation
too, and a tab started on a task never gets the task again. The last minute
before a crash can be missing.

A saved tab keeps the top bar it was opened with, so a new bar release
reaches restored tabs only once they are opened again; it needs its
permission granted once, as below.

## Requirements

Node 24 or newer, git, Zellij 0.46, Helix, OpenCode 2.2.5 or newer, Yazi,
tuicr, and a POSIX shell such as bash or zsh. The GitHub CLI is optional
(`wtprune -m`). A Nerd Font shows the status icons.

## Install

```sh
git clone https://github.com/ag14774/ade ~/.local/share/ade
~/.local/share/ade/starter/link.sh
```

`link.sh` links `ade`, the OpenCode plugins and the files below into place,
so a `git pull` in the clone updates them. A config file you already have
stays as it is; the script lists what to copy into it. Then:

1. Add `. ~/.local/share/ade/starter/shell/ade.sh` to your shell's rc file
   (`~/.zshrc`, `~/.bashrc`).
2. `opencode service restart`, so OpenCode's service loads the plugins.
3. Start Zellij. The top bar needs a permission once per release: inside
   Zellij, run `zellij plugin -f -- "<url>"` with the URL from
   `layouts/dev.kdl`, press `y`, and close that pane.

To start Zellij with every terminal, and have the session come back after a
restart, put this at the top of your rc file:

```sh
if [ -z "$ZELLIJ" ] && command -v zellij >/dev/null; then
  zellij attach --create --force-run-commands ade && exit
fi
```

Panes get the environment Zellij started with, so export what agents need
(API keys, PATH) before that line.

## The files

| File | Linked to | What it does |
| --- | --- | --- |
| `zellij/config.kdl` | `~/.config/zellij/` | `Alt-t`, `Alt-y`, `Alt-v`, tab mode `g`/`G`, the restore hook; only additions to Zellij's defaults |
| `zellij/layouts/dev.kdl` | `~/.config/zellij/layouts/` | the tab: top bar ([ade-zjstatus](https://github.com/ag14774/ade-zjstatus)), shell, OpenCode (`ade agent`), and Helix when a file opens |
| `zellij/yazi-picker.sh` | `~/.config/zellij/` | `Alt-y` |
| `zellij/resurrect-command.sh` | `~/.config/zellij/` | which commands a restored session reruns |
| `helix/config.toml` | `~/.config/helix/` | `+ a` and `Ctrl-r` |
| `ade/config.json` | `~/.config/ade/` | tabs named `project: worktree` |
| `opencode/cli.json` | copied to `~/.config/opencode/` | the ade status plugin plays OpenCode's sounds, once, in the right tab |
| `shell/ade.sh` | sourced from your rc file | `wt*` |

## Make it yours

- The ADE config (`~/.config/ade/config.json`): the editor, agent, reviewer,
  multiplexer, worktree layout and more; see
  [ade-kit's README](../packages/ade-kit/README.md).
- Adapters of your own, named in the config by their path:
  [AGENTS.md](../AGENTS.md), "Where changes belong".
- Replace a link with a copy of the file to change it without a fork.
- Test your copy with ade's live tests:
  `SANDBOX_CONFIG=<your config folder> zsh tests/keys_smoke.zsh` (also
  `zellij_restore_smoke.zsh`), with folders named as here (`zellij/`,
  `helix/`, `ade/`).
