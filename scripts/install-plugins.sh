#!/usr/bin/env bash
# install-plugins.sh — opt-in installer for zachflow plugins.
#
# Usage:
#   bash scripts/install-plugins.sh recall              # install one plugin
#   bash scripts/install-plugins.sh recall foo bar      # install multiple
#   bash scripts/install-plugins.sh --list              # list available plugins
#   bash scripts/install-plugins.sh --help
#
# Each plugin must have plugins/<name>/scripts/install.sh which symlinks
# ~/.claude/skills/<name> -> $PROJECT_ROOT/plugins/<name>.
#
# Plugins are user-installable (system-wide via ~/.claude/), separate from
# zachflow workflows (project-bundled via .claude/skills/{sprint,qa-fix}).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -eq 0 ]; then
  echo "Error: specify plugin name(s) or --list" >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

if [ "$1" = "--list" ]; then
  echo "Available plugins:"
  for d in "$PROJECT_ROOT"/plugins/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    echo "  - $name"
  done
  exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit 0
fi

for plugin in "$@"; do
  PLUGIN_DIR="$PROJECT_ROOT/plugins/$plugin"
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Error: plugin '$plugin' not found at $PLUGIN_DIR" >&2
    exit 1
  fi
  INSTALL_SH="$PLUGIN_DIR/scripts/install.sh"
  if [ ! -x "$INSTALL_SH" ]; then
    echo "Error: $INSTALL_SH not executable" >&2
    exit 1
  fi
  echo "Installing plugin: $plugin"
  bash "$INSTALL_SH"
done

echo
echo "Done. Plugins are now available system-wide via ~/.claude/skills/."
