#!/usr/bin/env bash
# setup-sprint.sh — Create git worktrees (or symlinks) for sprint source repos.
#
# Usage:
#   ./scripts/setup-sprint.sh --config sprint-orchestrator/sprints/{sprint-id}/sprint-config.yaml
#
# For each `repositories.<role>` entry:
#   - mode=worktree → `git worktree add <orchestrator>/<role> <branch_prefix>/<sprint_id>`
#     (creates branch from origin/<base> if missing).
#   - mode=symlink  → `ln -s <source> <orchestrator>/<role>`.
#
# Main checkout of each source repo is never mutated (HEAD/working tree unchanged).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCHESTRATOR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/parse-config.sh
source "$SCRIPT_DIR/lib/parse-config.sh"

CONFIG_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG_PATH="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --config <path-to-sprint-config.yaml>"
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

echo "Setting up sprint: $SPRINT_ID (branch: $BRANCH)"
echo ""

while IFS=$'\t' read -r role source base mode; do
  [ -z "$role" ] && continue
  target="$ORCHESTRATOR_DIR/$role"

  if [ -z "$source" ]; then
    echo "✗ $role: source not specified in config"
    exit 1
  fi

  if [ ! -d "$source" ]; then
    echo "✗ $role: source repo not found at $source"
    echo "  Clone it first, then re-run."
    exit 1
  fi

  if [ "$mode" = "symlink" ]; then
    if [ -L "$target" ]; then
      echo "✓ $role (symlink already exists → $(readlink "$target"))"
    elif [ -e "$target" ]; then
      echo "✗ $role: $target exists but is not a symlink — remove manually"
      exit 1
    else
      ln -s "$source" "$target"
      echo "✓ $role → symlink to $source"
    fi
    continue
  fi

  # mode = worktree (default)
  if [ -d "$target/.git" ] || [ -f "$target/.git" ]; then
    current=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    echo "✓ $role (worktree exists at $target, branch=$current)"
    continue
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "✗ $role: $target exists but is not a worktree — remove manually"
    exit 1
  fi

  if ! git -C "$source" rev-parse --git-dir >/dev/null 2>&1; then
    echo "✗ $role: $source is not a git repository"
    exit 1
  fi

  if git -C "$source" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$source" worktree add "$target" "$BRANCH"
    echo "✓ $role → worktree at $target (existing branch $BRANCH)"
  else
    git -C "$source" fetch origin "$base" --quiet || {
      echo "✗ $role: failed to fetch origin/$base"
      exit 1
    }
    git -C "$source" worktree add "$target" -b "$BRANCH" "origin/$base"
    echo "✓ $role → worktree at $target (new branch $BRANCH from origin/$base)"
  fi
done < <(parse_repos "$CONFIG_PATH")

echo ""
echo "Sprint setup complete."
