# ade.sh: short names for `ade worktree` that also cd where it says. Plain
# POSIX shell, for bash, zsh and the like: source it from your shell's rc file
# (~/.bashrc, ~/.zshrc).
#
#   wtclone <url> [dir]   clone a repository laid out for worktrees
#   wt <branch> [base]    cd into the branch's worktree, making it if needed;
#                         -s stays and prints its path, -t goes to its tab,
#                         -b opens the tab in the background, -p PROMPT opens
#                         a background tab whose agent starts on PROMPT
#   wtrm [-f] <name>      remove a worktree and close its tabs, except yours
#   wtprune [-ynm]        remove the worktrees whose remote branch was deleted
#                         (-m: also those merged through a GitHub PR)
#   wtls                  list the worktrees
#   wtconvert [-y]        turn the normal clone you are in into the configured
#                         layout, and cd into it
#   wthelp                show every option
#
# A program can't change the folder of the shell that runs it, so `ade
# worktree --cwd-file FILE` writes the folder to go to into FILE, and the
# function goes there. Everything else is `ade worktree` itself: call it
# directly from any shell or script. ADE_SEED and ADE_SEED_FILE (the seed
# files) must be exported to reach it.

# Run an `ade worktree` command, then cd where it says. Its variables have
# this file's prefix: POSIX shells have no local variables.
_ade_wt() {
  _ade_wt_file=$(mktemp "${TMPDIR:-/tmp}/ade-wt.XXXXXX") || return 1
  ade worktree --cwd-file "$_ade_wt_file" "$@"
  _ade_wt_status=$?
  _ade_wt_dir=$(cat "$_ade_wt_file")
  rm -f "$_ade_wt_file"
  if [ -n "$_ade_wt_dir" ]; then
    cd "$_ade_wt_dir" || return
  fi
  return "$_ade_wt_status"
}

wtclone() { _ade_wt clone "$@"; }
wt() { _ade_wt open "$@"; }
wtrm() { _ade_wt rm "$@"; }
wtls() { _ade_wt ls "$@"; }
wtprune() { _ade_wt prune "$@"; }
wtconvert() { _ade_wt convert "$@"; }
wthelp() {
  printf '%s\n\n' 'wtclone, wt, wtrm, wtls, wtprune and wtconvert run ade worktree clone, open, rm, ls, prune and convert, and cd where it reports (wt without -s/-t/-b/-p).'
  ade worktree help
}
