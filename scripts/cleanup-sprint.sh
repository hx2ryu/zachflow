#!/bin/bash
# cleanup-sprint.sh — Remove sprint worktrees and optionally delete merged branches.
#
# Usage:
#   ./scripts/cleanup-sprint.sh --config <path> [--force] [--delete-branch]
#
# Flags:
#   --force          Pass --force to `git worktree remove` (allow dirty trees).
#   --delete-branch  Also delete <branch_prefix>/<sprint_id> from each source repo
#                    (only if safely mergable; uses `git branch -d`, not -D).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCHESTRATOR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/parse-config.sh
source "$SCRIPT_DIR/lib/parse-config.sh"

CONFIG_PATH=""
FORCE=""
DELETE_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG_PATH="$2"; shift 2 ;;
    --force) FORCE="--force"; shift ;;
    --delete-branch) DELETE_BRANCH="1"; shift ;;
    -h|--help)
      echo "Usage: $0 --config <path-to-sprint-config.yaml> [--force] [--delete-branch]"
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[ -z "$CONFIG_PATH" ] && { echo "Error: --config required"; exit 1; }
[ ! -f "$CONFIG_PATH" ] && { echo "Error: config not found: $CONFIG_PATH"; exit 1; }

META=$(parse_meta "$CONFIG_PATH")
SPRINT_ID=$(echo "$META" | sed -n '1p')
BRANCH_PREFIX=$(echo "$META" | sed -n '2p')

if [ -z "$SPRINT_ID" ]; then
  echo "Error: sprint_id missing in $CONFIG_PATH"
  exit 1
fi

BRANCH="$BRANCH_PREFIX/$SPRINT_ID"

echo "Cleaning up sprint: $SPRINT_ID (branch: $BRANCH)"
echo ""

while IFS=$'\t' read -r role source base mode; do
  [ -z "$role" ] && continue
  target="$ORCHESTRATOR_DIR/$role"

  if [ "$mode" = "symlink" ]; then
    if [ -L "$target" ]; then
      rm "$target"
      echo "✓ $role symlink removed"
    else
      echo "  $role: no symlink to remove"
    fi
    continue
  fi

  if [ -d "$target" ]; then
    if [ -z "$source" ] || [ ! -d "$source" ]; then
      echo "✗ $role: source not found ($source) — cannot remove worktree cleanly"
      continue
    fi
    # shellcheck disable=SC2086
    if git -C "$source" worktree remove "$target" $FORCE 2>&1; then
      echo "✓ $role worktree removed"
    else
      echo "✗ $role worktree remove failed (try --force)"
      continue
    fi
  else
    echo "  $role: no worktree at $target"
  fi

  if [ -n "$DELETE_BRANCH" ] && [ -n "$source" ] && [ -d "$source" ]; then
    if git -C "$source" branch -d "$BRANCH" 2>/dev/null; then
      echo "✓ $role branch $BRANCH deleted (merged)"
    else
      echo "⚠ $role branch $BRANCH not deleted (unmerged or missing; use 'git branch -D' manually)"
    fi
  fi
done < <(parse_repos "$CONFIG_PATH")

echo ""
echo "Cleanup complete."
