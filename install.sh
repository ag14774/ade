#!/usr/bin/env bash
# Install ade from this checkout: the `ade` command into ~/.local/bin and the
# OpenCode plugins into ~/.config/opencode/plugins, as links, so a `git pull`
# here updates them. npm links the packages to each other first (it downloads
# nothing).
#
#   ./install.sh
#
# A file that is already there stays, unless it is a link this script could
# have made (into this checkout, the same file in another ade checkout, or a
# link to nothing). Safe to rerun. starter/link.sh runs this, then links the
# starter's config.
set -eu

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
BIN=$HOME/.local/bin
notes=()

# link TARGET LINK
link() {
  local target=$1 link=$2 current
  mkdir -p "$(dirname "$link")"
  if [ -L "$link" ]; then
    current=$(readlink "$link")
    [ "$current" = "$target" ] && return 0
    case "$current" in
      "$ROOT"/* | */"${target#"$ROOT"/}") ;;
      *)
        if [ -e "$link" ]; then
          notes+=("kept $link (it links to $current); ade's is $target")
          return 0
        fi
        ;;
    esac
  elif [ -e "$link" ]; then
    notes+=("kept your $link; copy what you want from $target")
    return 0
  fi
  ln -sfn "$target" "$link"
  echo "linked $link"
}

install_ade() {
  (cd "$ROOT" && npm_config_update_notifier=false npm install --omit=dev --omit=optional --omit=peer --no-audit --no-fund --loglevel=error)
  link "$ROOT/packages/ade-kit/src/cli.ts" "$BIN/ade"
  local p
  for p in ade ade-status ade-worktrees; do
    link "$ROOT/packages/opencode-$p" "$CONFIG/opencode/plugins/$p"
  done
}

finish() {
  case ":$PATH:" in
    *":$BIN:"*) ;;
    *) notes+=("put $BIN on your PATH") ;;
  esac
  notes+=("run \`opencode service restart\` so OpenCode's service loads the plugins")
  printf '\n'
  local n
  for n in "${notes[@]}"; do printf -- '- %s\n' "$n"; done
}

# Sourced by starter/link.sh: only the functions.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
install_ade
finish
