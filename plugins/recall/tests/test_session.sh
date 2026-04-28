#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT
export RECALL_STATE_DIR="$TEST_TMPDIR"

source scripts/session.sh

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

# Test 0: session_path returns expected path
out=$(session_path)
expected="$TEST_TMPDIR/session.yaml"
[[ "$out" == "$expected" ]] || fail "session_path expected $expected, got $out"
pass "session_path returns expected path"

# Test 1: write then read round-trip
session_write "active: true
sprint_focus: test-sprint
turn_count: 1"
out=$(session_read)
echo "$out" | grep -q "sprint_focus: test-sprint" || fail "round-trip lost sprint_focus"
echo "$out" | grep -q "turn_count: 1" || fail "round-trip lost turn_count"
pass "session_write/session_read round-trip"

# Test 2: read returns empty when no file
rm -f "$RECALL_STATE_DIR/session.yaml"
out=$(session_read)
[[ -z "$out" ]] || fail "session_read should return empty for missing file, got: $out"
pass "session_read empty when no file"

# Test 3: session_active true when fresh
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
session_write "active: true
last_turn_at: $now
turn_count: 1"
session_active && pass "session_active true when fresh" || fail "session_active should be true for fresh session"

# Test 4: session_active false when idle (>30min)
old=$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)-datetime.timedelta(minutes=45)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
session_write "active: true
last_turn_at: $old
turn_count: 1"
if session_active; then fail "session_active should be false when idle 45min"; fi
pass "session_active false when idle"

# Test 5: session_active false when stale (>7 days)
stale=$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)-datetime.timedelta(days=8)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
session_write "active: true
last_turn_at: $stale
turn_count: 1"
if session_active; then fail "session_active should be false when stale 8d"; fi
pass "session_active false when stale"

# Test 5b: RECALL_STALE_DAYS override makes shorter sessions stale
recent=$(python3 -c 'import datetime; print((datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)-datetime.timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
session_write "active: true
last_turn_at: $recent
turn_count: 1"
if RECALL_STALE_DAYS=1 session_active 2>/dev/null; then fail "session_active should be stale with RECALL_STALE_DAYS=1"; fi
pass "session_active respects RECALL_STALE_DAYS override"

# Test 6: session_active false when no file
rm -f "$RECALL_STATE_DIR/session.yaml"
if session_active; then fail "session_active should be false when no file"; fi
pass "session_active false when no file"

# Test 7: session_reset removes file
session_write "active: true"
session_reset
[[ ! -f "$RECALL_STATE_DIR/session.yaml" ]] || fail "session_reset should delete file"
pass "session_reset deletes state file"

# Test 8: session_reset on missing file is no-op (no error)
session_reset && pass "session_reset on missing file is silent" || fail "session_reset should not error when no file"

# Test 9: session_backup_corrupt moves to .corrupt-<ts>
session_write "this is not valid yaml: : :"
session_backup_corrupt
[[ ! -f "$RECALL_STATE_DIR/session.yaml" ]] || fail "session_backup_corrupt should move out of session.yaml"
backup=$(ls "$RECALL_STATE_DIR"/session.yaml.corrupt-* 2>/dev/null | head -1)
[[ -n "$backup" ]] || fail "session_backup_corrupt should create .corrupt-<ts> file"
[[ "$backup" =~ session\.yaml\.corrupt-[0-9]{8}T[0-9]{6}Z$ ]] || fail "backup filename does not match .corrupt-<YYYYmmddTHHMMSSZ> format"
pass "session_backup_corrupt moves to timestamped backup"

echo "All session tests passed"
