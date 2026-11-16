#!/usr/bin/env bash
# Install ade from this checkout by linking it into place.
#
#   starter/link.sh          ade, the OpenCode plugins and the starter's config
#   starter/link.sh --core   only ade and the OpenCode plugins
#
# Everything links into this checkout, so a `git pull` here updates it. A file
# that is already there stays, unless it is a link this script could have
# made (into this checkout, the same file in another ade checkout, or a link
# to nothing): for a config of your own it says what to copy instead. Safe to
# rerun.
set -eu

core=false
case "${1:-}" in
  --core) core=true ;;
  "") ;;
  *)
    echo "usage: starter/link.sh [--core]" >&2
    exit 2
    ;;
esac

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
STARTER=$ROOT/starter
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

# The plugins import ade-kit by name: npm links the workspace packages
# (it downloads nothing with these options).
(cd "$ROOT" && npm_config_update_notifier=false npm install --omit=dev --omit=optional --omit=peer --no-audit --no-fund --loglevel=error)

link "$ROOT/packages/ade-kit/src/cli.ts" "$BIN/ade"
for p in ade ade-status ade-worktrees; do
  link "$ROOT/packages/opencode-$p" "$CONFIG/opencode/plugins/$p"
done

if ! $core; then
  link "$STARTER/bin/opencode-pane" "$BIN/opencode-pane"
  for f in config.kdl layouts/dev.kdl yazi-picker.sh resurrect-command.sh; do
    link "$STARTER/zellij/$f" "$CONFIG/zellij/$f"
  done
  link "$STARTER/helix/config.toml" "$CONFIG/helix/config.toml"
  link "$STARTER/ade/config.json" "$CONFIG/ade/config.json"

  # OpenCode writes its own settings to cli.json, so it is a copy.
  cli=$CONFIG/opencode/cli.json
  if [ ! -e "$cli" ]; then
    cp "$STARTER/opencode/cli.json" "$cli"
    echo "created $cli"
  elif ! grep -q -- '-opencode.notifications' "$cli"; then
    notes+=("add \"-opencode.notifications\" to \"plugins\" in $cli, so opencode-ade-status plays the sounds instead of OpenCode")
  fi

  grep -qsF "$STARTER/shell/ade.zsh" "$HOME/.zshrc" ||
    notes+=("add to ~/.zshrc, after compinit: source $STARTER/shell/ade.zsh")
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) notes+=("put $BIN on your PATH") ;;
esac
notes+=("run \`opencode service restart\` so OpenCode's service loads the plugins")
printf '\n'
for n in "${notes[@]}"; do printf -- '- %s\n' "$n"; done
