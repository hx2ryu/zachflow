#!/usr/bin/env bash
# uninstall.sh — remove the recall plugin symlink
set -euo pipefail

TARGET_DIR="$HOME/.claude/skills/recall"

if [[ -L "$TARGET_DIR" ]]; then
  rm "$TARGET_DIR"
  echo "removed: $TARGET_DIR"
elif [[ -e "$TARGET_DIR" ]]; then
  echo "ERROR: $TARGET_DIR exists and is not a symlink. Inspect manually." >&2
  exit 1
else
  echo "not installed: $TARGET_DIR does not exist"
fi
