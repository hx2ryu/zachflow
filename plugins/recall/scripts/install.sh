#!/usr/bin/env bash
# install.sh — symlink the recall plugin into ~/.claude/skills/recall/
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$HOME/.claude/skills/recall"

mkdir -p "$HOME/.claude/skills"

if [[ -L "$TARGET_DIR" ]]; then
  current=$(readlink "$TARGET_DIR")
  if [[ "$current" == "$PLUGIN_DIR" ]]; then
    echo "already linked: $TARGET_DIR -> $current"
    exit 0
  fi
  echo "removing stale symlink: $TARGET_DIR -> $current"
  rm "$TARGET_DIR"
elif [[ -e "$TARGET_DIR" ]]; then
  echo "ERROR: $TARGET_DIR exists and is not a symlink. Aborting." >&2
  exit 1
fi

ln -s "$PLUGIN_DIR" "$TARGET_DIR"
echo "linked: $TARGET_DIR -> $PLUGIN_DIR"
echo "Restart Claude Code session to pick up the new skill."
