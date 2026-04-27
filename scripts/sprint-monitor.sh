#!/bin/bash
# sprint-monitor.sh — Real-time terminal dashboard for sprint status
# Usage: ./scripts/sprint-monitor.sh <sprint-id>

ORCHESTRATOR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SPRINTS_DIR="$ORCHESTRATOR_DIR/sprint-orchestrator/sprints"

SPRINT_ID="${1:-}"
if [ -z "$SPRINT_ID" ]; then
  echo "Usage: $0 <sprint-id>" >&2
  exit 1
fi

SPRINT_DIR="$SPRINTS_DIR/$SPRINT_ID"
if [ ! -d "$SPRINT_DIR" ]; then
  echo "Error: Sprint directory not found: $SPRINT_DIR" >&2
  exit 1
fi

LOGS_DIR="$SPRINT_DIR/logs"
CONTRACTS_DIR="$SPRINT_DIR/contracts"
EVALUATIONS_DIR="$SPRINT_DIR/evaluations"
CHECKPOINTS_DIR="$SPRINT_DIR/checkpoints"
EVENTS_FILE="$LOGS_DIR/events.jsonl"

AGENTS=("be-engineer" "fe-engineer" "design-engineer" "evaluator")

trap 'printf "\n"; echo "Monitor stopped."; exit 0' INT

# ── Helpers ─────────────────────────────────────────────────────────────────

# Parse ISO8601 timestamp → epoch seconds (macOS compatible)
ts_to_epoch() {
  local ts="$1"
  # Strip timezone offset for date -j -f
  local clean="${ts%+*}"
  clean="${clean%Z}"
  # Replace T with space
  clean="${clean/T/ }"
  # -u flag: treat input as UTC so elapsed calculations are correct
  date -j -u -f "%Y-%m-%d %H:%M:%S" "$clean" "+%s" 2>/dev/null || echo "0"
}

# Human-readable elapsed from epoch
elapsed_since() {
  local epoch="$1"
  [ "$epoch" = "0" ] && echo "—" && return
  local now
  now=$(date "+%s")
  local diff=$(( now - epoch ))
  if   [ $diff -lt 60 ];    then echo "${diff}s ago"
  elif [ $diff -lt 3600 ];  then echo "$(( diff / 60 ))m ago"
  elif [ $diff -lt 86400 ]; then echo "$(( diff / 3600 ))h ago"
  else                           echo "$(( diff / 86400 ))d ago"
  fi
}

# Pad / truncate a string to exact width
pad() {
  local str="$1"
  local width="$2"
  printf "%-${width}s" "${str:0:$width}"
}

# ── Agent status ─────────────────────────────────────────────────────────────

get_agent_status() {
  local agent="$1"
  local status="NOT STARTED"
  local task="—"
  local phase="—"
  local elapsed="—"
  local detail="—"
  local last_ts_epoch=0

  if [ ! -f "$EVENTS_FILE" ]; then
    echo "$status|$task|$phase|$elapsed|$detail"
    return
  fi

  # Find last subagent_start and subagent_stop for this agent_type
  local last_start_ts last_stop_ts
  last_start_ts=$(jq -r --arg a "$agent" \
    'select(.event=="subagent_start" and .agent_type==$a) | .ts' \
    "$EVENTS_FILE" 2>/dev/null | tail -1)
  last_stop_ts=$(jq -r --arg a "$agent" \
    'select(.event=="subagent_stop" and .agent_type==$a) | .ts' \
    "$EVENTS_FILE" 2>/dev/null | tail -1)

  if [ -z "$last_start_ts" ] && [ -z "$last_stop_ts" ]; then
    echo "$status|$task|$phase|$elapsed|$detail"
    return
  fi

  local start_epoch=0
  local stop_epoch=0
  [ -n "$last_start_ts" ] && start_epoch=$(ts_to_epoch "$last_start_ts")
  [ -n "$last_stop_ts"  ] && stop_epoch=$(ts_to_epoch "$last_stop_ts")

  if [ "$start_epoch" -gt "$stop_epoch" ]; then
    status="ACTIVE"
    last_ts_epoch=$start_epoch
  else
    status="IDLE"
    last_ts_epoch=$stop_epoch
  fi

  elapsed=$(elapsed_since "$last_ts_epoch")

  # If ACTIVE, check agent JSONL for phase detail
  if [ "$status" = "ACTIVE" ]; then
    local agent_log="$LOGS_DIR/${agent}.jsonl"
    if [ -f "$agent_log" ]; then
      local last_line
      last_line=$(tail -1 "$agent_log" 2>/dev/null)
      if [ -n "$last_line" ]; then
        local log_phase log_task log_msg
        log_phase=$(echo "$last_line" | jq -r '.phase // ""')
        log_task=$(echo "$last_line"  | jq -r '.task  // ""')
        log_msg=$(echo "$last_line"   | jq -r '.message // .detail // ""')

        [ -n "$log_task" ] && task="$log_task"
        [ -n "$log_msg"  ] && detail="$log_msg"

        case "$log_phase" in
          implementing) phase="ACTIVE"    ;;
          build_check)  phase="BUILDING"  ;;
          build_failed) phase="BUILD FAIL"; status="BUILD FAIL" ;;
          completed)    phase="IDLE";       status="IDLE"       ;;
          error)        phase="ERROR";      status="ERROR"      ;;
          *)            phase="${log_phase:-ACTIVE}" ;;
        esac
      fi
    fi
  fi

  echo "$status|$task|$phase|$elapsed|$detail"
}

# ── Group status ─────────────────────────────────────────────────────────────

get_groups() {
  local -a groups=()
  if [ -d "$CONTRACTS_DIR" ]; then
    for f in "$CONTRACTS_DIR"/group-*.md; do
      [ -f "$f" ] || continue
      local gid
      gid=$(basename "$f" .md | sed 's/group-//')
      groups+=("$gid")
    done
  fi
  # Also check evaluations dir
  if [ -d "$EVALUATIONS_DIR" ]; then
    for f in "$EVALUATIONS_DIR"/group-*.md; do
      [ -f "$f" ] || continue
      local gid
      gid=$(basename "$f" .md | sed 's/group-//')
      # Add only if not already present
      local found=0
      for g in "${groups[@]+"${groups[@]}"}"; do [ "$g" = "$gid" ] && found=1 && break; done
      [ $found -eq 0 ] && groups+=("$gid")
    done
  fi
  printf '%s\n' "${groups[@]+"${groups[@]}"}" | sort -u
}

get_contract_status() {
  local gid="$1"
  local f="$CONTRACTS_DIR/group-${gid}.md"
  [ -f "$f" ] || { echo "—"; return; }
  if grep -qi "agreed\|approved\|✓" "$f" 2>/dev/null; then
    echo "agreed"
  elif grep -qi "rejected\|denied" "$f" 2>/dev/null; then
    echo "rejected"
  else
    echo "pending"
  fi
}

get_backend_status() {
  local gid="$1"
  # Check checkpoints or logs for group-specific backend status
  local impl_dir="$SPRINT_DIR/impl/backend/${gid}"
  [ -d "$impl_dir" ] && echo "done" && return
  local f="$LOGS_DIR/be-engineer.jsonl"
  if [ -f "$f" ]; then
    local hit
    hit=$(jq -r --arg g "$gid" 'select(.task | test($g)) | .phase' "$f" 2>/dev/null | tail -1)
    case "$hit" in
      completed)    echo "done"    ;;
      implementing) echo "active"  ;;
      build_failed) echo "FAIL"    ;;
      "")           echo "—"       ;;
      *)            echo "$hit"    ;;
    esac
    return
  fi
  echo "—"
}

get_app_status() {
  local gid="$1"
  local f="$LOGS_DIR/fe-engineer.jsonl"
  if [ -f "$f" ]; then
    local hit
    hit=$(jq -r --arg g "$gid" 'select(.task | test($g)) | .phase' "$f" 2>/dev/null | tail -1)
    case "$hit" in
      completed)    echo "done"    ;;
      implementing) echo "active"  ;;
      build_failed) echo "FAIL"    ;;
      "")           echo "—"       ;;
      *)            echo "$hit"    ;;
    esac
    return
  fi
  echo "—"
}

get_eval_status() {
  local gid="$1"
  local f="$EVALUATIONS_DIR/group-${gid}.md"
  [ -f "$f" ] || { echo "—"; return; }
  if grep -qi "PASS" "$f" 2>/dev/null; then
    echo "PASS"
  elif grep -qi "FAIL" "$f" 2>/dev/null; then
    echo "FAIL"
  else
    echo "pending"
  fi
}

# ── Checkpoints ──────────────────────────────────────────────────────────────

get_checkpoints() {
  [ -d "$CHECKPOINTS_DIR" ] || return
  for f in "$CHECKPOINTS_DIR"/*.md; do
    [ -f "$f" ] && basename "$f"
  done
}

# ── Recent events ────────────────────────────────────────────────────────────

get_recent_events() {
  [ -f "$EVENTS_FILE" ] || return
  # Last 5 lines, reversed
  tail -5 "$EVENTS_FILE" | tac 2>/dev/null || tail -5 "$EVENTS_FILE" | awk '{lines[NR]=$0} END{for(i=NR;i>=1;i--) print lines[i]}'
}

# ── Render ───────────────────────────────────────────────────────────────────

render() {
  local now
  now=$(date "+%H:%M:%S")

  printf '═%.0s' {1..55}; printf '\n'
  printf '  Sprint: %s\n' "$SPRINT_ID"
  printf '  Monitor: %s (refreshing every 2s)\n' "$now"
  printf '═%.0s' {1..55}; printf '\n'

  # ── Agent Activity ──
  printf '\n  ─── Agent Activity ───────────────────────────────────\n'
  printf '  %-18s %-24s %-12s %-9s %s\n' "Agent" "Task" "Phase" "Elapsed" "Detail"
  printf '  %-18s %-24s %-12s %-9s %s\n' \
    "────────────────" "──────────────────────" "──────────" "───────" "──────────────────────"

  for agent in "${AGENTS[@]}"; do
    local info
    info=$(get_agent_status "$agent")
    IFS='|' read -r status task phase elapsed detail <<< "$info"
    printf '  %-18s %-24s %-12s %-9s %s\n' \
      "$(pad "$agent" 18)" \
      "$(pad "$task"  22)" \
      "$(pad "${phase:-$status}" 12)" \
      "$(pad "$elapsed" 9)" \
      "${detail:0:40}"
  done

  # ── Groups ──
  printf '\n  ─── Groups ───────────────────────────────────────────\n'
  printf '  %-7s %-10s %-16s %-16s %-10s\n' "Group" "Contract" "Backend" "App" "Evaluation"
  printf '  %-7s %-10s %-16s %-16s %-10s\n' "─────" "────────" "────────────" "────────────" "──────────"

  local groups_list found_groups=0
  groups_list=$(get_groups)
  if [ -z "$groups_list" ]; then
    printf '  (no groups found)\n'
  else
    while IFS= read -r gid; do
      [ -z "$gid" ] && continue
      found_groups=1
      local contract be app evl
      contract=$(get_contract_status "$gid")
      be=$(get_backend_status "$gid")
      app=$(get_app_status "$gid")
      evl=$(get_eval_status "$gid")
      printf '  %-7s %-10s %-16s %-16s %-10s\n' "$gid" "$contract" "$be" "$app" "$evl"
    done <<< "$groups_list"
    [ $found_groups -eq 0 ] && printf '  (no groups found)\n'
  fi

  # ── Checkpoints ──
  printf '\n  ─── Checkpoints ──────────────────────────────────────\n'
  local found_cp=0
  while IFS= read -r cp; do
    [ -z "$cp" ] && continue
    found_cp=1
    printf '  %-40s ✓\n' "$cp"
  done < <(get_checkpoints)
  [ $found_cp -eq 0 ] && printf '  (no checkpoints)\n'

  # ── Recent Events ──
  printf '\n  ─── Recent Events (Hook) ─────────────────────────────\n'
  local found_ev=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    found_ev=1
    local ts ev agent_type subject
    ts=$(echo "$line"          | jq -r '.ts // ""')
    ev=$(echo "$line"          | jq -r '.event // ""')
    agent_type=$(echo "$line"  | jq -r '.agent_type // .teammate // ""')
    subject=$(echo "$line"     | jq -r '.subject // .task_id // ""')
    # Format ts as HH:MM:SS
    local hms
    hms=$(echo "$ts" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)
    printf '  %-10s %-16s %-20s %s\n' \
      "${hms:-??:??:??}" \
      "$(pad "$agent_type" 14)" \
      "$(pad "$ev" 18)" \
      "$subject"
  done < <(get_recent_events)
  [ $found_ev -eq 0 ] && printf '  (no events yet)\n'

  printf '\n'
  printf '═%.0s' {1..55}; printf '\n'
  printf '  Ctrl+C to exit\n'
  printf '═%.0s' {1..55}; printf '\n'
}

# ── Main loop ────────────────────────────────────────────────────────────────

while true; do
  clear
  render
  sleep 2
done
