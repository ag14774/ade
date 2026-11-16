#!/usr/bin/env bash
# Alt-y (config.kdl): pick files in Yazi, in a floating pane; they open in
# this tab's editor (`ade open`), which starts if the tab has none.
#
# Yazi starts in the folder you last left it in, remembered per repository,
# else in the folder of the pane you pressed Alt-y in (`ade where`: a floating
# pane itself starts in the session's folder).
set -u

ADE="$HOME/.local/bin/ade"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/yazi-picker"
mkdir -p "$CACHE"

chooser="$(mktemp "${TMPDIR:-/tmp}/yazi-picker.XXXXXX")"
trap 'rm -f "$chooser"' EXIT

dir="$("$ADE" where 2>/dev/null)"
[ -n "$dir" ] && [ -d "$dir" ] || dir="$PWD"
root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
key="$(printf '%s' "$root" | cksum)"
last="$CACHE/last-cwd-${key%% *}"
start="$dir"
if [ -s "$last" ]; then
  d="$(cat "$last")"
  [ -d "$d" ] && start="$d"
fi

yazi "$start" --chooser-file="$chooser" --cwd-file="$last"

files=()
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] && files+=("$line")
done <"$chooser"
[ "${#files[@]}" -gt 0 ] || exit 0
exec "$ADE" open "${files[@]}"
