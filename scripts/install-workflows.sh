#!/usr/bin/env bash
# install-workflows.sh — symlink workflows/<name> into .claude/skills/<name>
# Idempotent: skip if symlink already correct, error if non-symlink exists at target.
# Run on fresh clone or after workflow directory restructure.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${PROJECT_ROOT}/.claude/skills"

for workflow in sprint qa-fix; do
  TARGET="${PROJECT_ROOT}/.claude/skills/${workflow}"
  SOURCE_REL="../../workflows/${workflow}"
  SOURCE_ABS="${PROJECT_ROOT}/workflows/${workflow}"

  if [ ! -d "$SOURCE_ABS" ]; then
    echo "Error: source ${SOURCE_ABS} does not exist" >&2
    exit 1
  fi

  if [ -L "$TARGET" ]; then
    current=$(readlink "$TARGET")
    if [ "$current" = "$SOURCE_REL" ]; then
      echo "already linked: $TARGET -> $current"
      continue
    fi
    echo "removing stale symlink: $TARGET -> $current"
    rm "$TARGET"
  elif [ -d "$TARGET" ]; then
    if [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then
      echo "removing empty directory: $TARGET"
      rmdir "$TARGET"
    else
      echo "Error: $TARGET is a non-empty directory; expected symlink target. Aborting." >&2
      ls "$TARGET" >&2
      exit 1
    fi
  elif [ -e "$TARGET" ]; then
    echo "Error: $TARGET exists and is not a symlink or directory. Aborting." >&2
    exit 1
  fi

  ln -s "$SOURCE_REL" "$TARGET"
  echo "linked: $TARGET -> $SOURCE_REL"
done

echo "workflow symlinks installed."
