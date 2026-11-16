#!/usr/bin/env bash
# Install ade (../install.sh) and link the starter's config into place.
#
#   starter/link.sh
#
# Everything links into this checkout, so a `git pull` here updates it. A file
# that is already there stays, unless it is a link this script could have
# made (into this checkout, the same file in another ade checkout, or a link
# to nothing): for a config of your own it says what to copy instead. Safe to
# rerun.
set -eu

# shellcheck source-path=SCRIPTDIR source=../install.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/install.sh"
STARTER=$ROOT/starter

install_ade

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

grep -qsF "$STARTER/shell/ade.sh" "$HOME/.zshrc" "$HOME/.bashrc" ||
  notes+=("for wt and the other short names, add to your shell's rc file (~/.zshrc, ~/.bashrc): . $STARTER/shell/ade.sh")
notes+=("grant the top bar its permission once: inside Zellij, run zellij plugin -f -- \"<url>\" with the URL in $STARTER/zellij/layouts/dev.kdl, press y, and close that pane")

finish
