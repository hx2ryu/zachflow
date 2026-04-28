# session.sh — state file lifecycle helpers for recall:ask
# Sourced by other scripts; do NOT execute directly.
#
# Public functions:
#   session_read              → echoes state YAML to stdout (empty if no file)
#   session_write <yaml>      → writes <yaml> to state file
#   session_path              → echoes resolved state file path
#   session_active            → exits 0 if active+fresh, 1 otherwise
#   session_reset             → deletes state file
#   session_backup_corrupt    → moves state file to .corrupt-<ts> backup
#
# Env:
#   RECALL_STATE_DIR  — override state dir (default: ~/.recall)
#   RECALL_IDLE_MIN   — idle timeout minutes (default: 30)
#   RECALL_STALE_DAYS — auto-reset stale session days (default: 7)

session_path() {
  local dir="${RECALL_STATE_DIR:-$HOME/.recall}"
  echo "$dir/session.yaml"
}

session_read() {
  local f
  f=$(session_path)
  [[ -f "$f" ]] || return 0
  cat "$f"
}

session_write() {
  local yaml="${1:-}"
  local f dir
  f=$(session_path)
  dir=$(dirname "$f")
  mkdir -p "$dir"
  printf '%s\n' "$yaml" > "$f"
}

# Returns 0 if state file exists AND last_turn_at is within idle window AND not stale.
session_active() {
  local f yaml last
  f=$(session_path)
  [[ -f "$f" ]] || return 1
  yaml=$(cat "$f")
  last=$(printf '%s\n' "$yaml" | sed -n 's/^last_turn_at:[[:space:]]*//p' | head -1 | tr -d '"')
  [[ -n "$last" ]] || return 1
  local idle_min="${RECALL_IDLE_MIN:-30}"
  local stale_days="${RECALL_STALE_DAYS:-7}"
  python3 - "$last" "$idle_min" "$stale_days" <<'PY' || return 1
import datetime, sys
last_str, idle_min, stale_days = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
last = datetime.datetime.strptime(last_str, "%Y-%m-%dT%H:%M:%SZ")
now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
delta = now - last
if delta > datetime.timedelta(days=stale_days): sys.exit(1)
if delta > datetime.timedelta(minutes=idle_min): sys.exit(1)
sys.exit(0)
PY
}

session_reset() {
  local f
  f=$(session_path)
  rm -f "$f"
  return 0
}

session_backup_corrupt() {
  local f ts
  f=$(session_path)
  [[ -f "$f" ]] || return 0
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  mv "$f" "${f}.corrupt-${ts}"
}
