#!/usr/bin/env bash
# Claude Code hook → append a SHA-256-chained record to the active
# sprint's logs/events.jsonl. Each line carries prev_hash + hash; see
# scripts/lib/jsonl-append.py for the chain protocol.

set -euo pipefail

ORCHESTRATOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPRINTS_DIR="$ORCHESTRATOR_DIR/sprint-orchestrator/sprints"
APPEND="$ORCHESTRATOR_DIR/scripts/lib/jsonl-append.py"

INPUT=$(cat)

EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
[ -z "$EVENT_NAME" ] && exit 0

ACTIVE_SPRINT=""
if [ -d "$SPRINTS_DIR" ]; then
  while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    if [ -f "$dir/sprint-config.yaml" ] && [ ! -f "$dir/retrospective/REPORT.md" ]; then
      ACTIVE_SPRINT="$dir"
      break
    fi
  done < <(find "$SPRINTS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 | xargs -0 ls -td 2>/dev/null)
fi

[ -z "$ACTIVE_SPRINT" ] && exit 0

LOGS_DIR="$ACTIVE_SPRINT/logs"
mkdir -p "$LOGS_DIR"
EVENTS_FILE="$LOGS_DIR/events.jsonl"

TS=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

case "$EVENT_NAME" in
  SubagentStart)
    AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
    PAYLOAD=$(jq -nc --arg ts "$TS" --arg id "$AGENT_ID" --arg type "$AGENT_TYPE" \
      '{ts:$ts, event:"subagent_start", agent_id:$id, agent_type:$type}')
    ;;
  SubagentStop)
    AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
    PAYLOAD=$(jq -nc --arg ts "$TS" --arg id "$AGENT_ID" --arg type "$AGENT_TYPE" \
      '{ts:$ts, event:"subagent_stop", agent_id:$id, agent_type:$type}')
    ;;
  TaskCreated)
    TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
    SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
    TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
    PAYLOAD=$(jq -nc --arg ts "$TS" --arg id "$TASK_ID" --arg subj "$SUBJECT" --arg tm "$TEAMMATE" \
      '{ts:$ts, event:"task_created", task_id:$id, subject:$subj, teammate:$tm}')
    ;;
  TaskCompleted)
    TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
    SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
    TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
    PAYLOAD=$(jq -nc --arg ts "$TS" --arg id "$TASK_ID" --arg subj "$SUBJECT" --arg tm "$TEAMMATE" \
      '{ts:$ts, event:"task_completed", task_id:$id, subject:$subj, teammate:$tm}')
    ;;
  *)
    exit 0
    ;;
esac

# Best-effort append. If the chain refuses (e.g. legacy un-chained
# events.jsonl present from a pre-hash-chain sprint), surface to stderr
# but never block the originating Claude Code hook — the hook handler
# must remain idempotent and non-fatal to the agent flow.
python3 "$APPEND" "$EVENTS_FILE" "$PAYLOAD" 2>&1 | sed 's/^/[hook-handler] /' >&2 || true

exit 0
