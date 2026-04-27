#!/usr/bin/env bash
set -euo pipefail

ORCHESTRATOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPRINTS_DIR="$ORCHESTRATOR_DIR/sprint-orchestrator/sprints"

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
    echo "{\"ts\":\"$TS\",\"event\":\"subagent_start\",\"agent_id\":\"$AGENT_ID\",\"agent_type\":\"$AGENT_TYPE\"}" >> "$EVENTS_FILE"
    ;;
  SubagentStop)
    AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
    AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
    echo "{\"ts\":\"$TS\",\"event\":\"subagent_stop\",\"agent_id\":\"$AGENT_ID\",\"agent_type\":\"$AGENT_TYPE\"}" >> "$EVENTS_FILE"
    ;;
  TaskCreated)
    TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
    SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
    TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
    echo "{\"ts\":\"$TS\",\"event\":\"task_created\",\"task_id\":\"$TASK_ID\",\"subject\":\"$SUBJECT\",\"teammate\":\"$TEAMMATE\"}" >> "$EVENTS_FILE"
    ;;
  TaskCompleted)
    TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
    SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
    TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
    echo "{\"ts\":\"$TS\",\"event\":\"task_completed\",\"task_id\":\"$TASK_ID\",\"subject\":\"$SUBJECT\",\"teammate\":\"$TEAMMATE\"}" >> "$EVENTS_FILE"
    ;;
esac

exit 0
