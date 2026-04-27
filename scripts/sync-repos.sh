#!/bin/bash
# sync-repos.sh — Fetch base branches in source repos referenced by a sprint config.
#
# Usage:
#   ./scripts/sync-repos.sh --config sprint-orchestrator/sprints/{sprint-id}/sprint-config.yaml
#
# Behavior:
#   For each `repositories.<role>` entry, runs `git fetch origin <base>` inside
#   the source repo. Does NOT modify the sprint worktree or its branch.
#   Does NOT pull or merge — users update the sprint branch explicitly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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

echo "Fetching base branches in source repos..."
echo ""

HAS_WARNING=0

while IFS=$'\t' read -r role source base mode; do
  [ -z "$role" ] && continue

  if [ -z "$source" ] || [ ! -d "$source" ]; then
    printf "  ✗ %-12s source not found (%s)\n" "$role" "$source"
    HAS_WARNING=1
    continue
  fi

  if ! git -C "$source" rev-parse --git-dir >/dev/null 2>&1; then
    printf "  ✗ %-12s %s is not a git repository\n" "$role" "$source"
    HAS_WARNING=1
    continue
  fi

  if git -C "$source" fetch origin "$base" --quiet 2>/dev/null; then
    behind=$(git -C "$source" rev-list --count "refs/heads/${base}..origin/${base}" 2>/dev/null || echo "?")
    printf "  ✓ %-12s origin/%s fetched (main checkout %s commits behind)\n" "$role" "$base" "$behind"
  else
    printf "  ✗ %-12s fetch origin/%s failed\n" "$role" "$base"
    HAS_WARNING=1
  fi
done < <(parse_repos "$CONFIG_PATH")

echo ""
if [ "$HAS_WARNING" = "1" ]; then
  echo "⚠ Some repos skipped. Sprint worktree branches are untouched."
  exit 0
fi
echo "All source repos fetched. Sprint worktree branches untouched."
