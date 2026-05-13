#!/usr/bin/env bash
# tests/jsonl-hash-chain-test.sh — unit test for jsonl-append.py + jsonl-verify.py
#
# Asserts:
#   1. Three sequential appends produce a verifiable chain.
#   2. Tampering with line 2's content breaks verification at line 2.
#   3. Deleting line 2 breaks verification at line 2.
#   4. Legacy file (no hash fields) is reported "no chain (legacy)" and exits 0.
#   5. Mixed-mode file (chain partially present) fails verification.
#   6. jsonl-append refuses to append to a legacy file.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMP_RAW="$(mktemp -d -t zachflow-jsonl-chain-XXXXXX)"
trap "rm -rf '$TMP_RAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMP="$(cygpath -m "$TMP_RAW")"
else
  TMP="$TMP_RAW"
fi

APPEND="python3 scripts/lib/jsonl-append.py"
VERIFY="python3 scripts/lib/jsonl-verify.py"

echo "=== Case 1: 3 sequential appends → verify OK ==="
F="$TMP/events.jsonl"
$APPEND "$F" '{"event":"subagent_start","agent":"be-engineer","ts":"2026-05-13T00:00:00Z"}'
$APPEND "$F" '{"event":"task_created","task_id":"impl/be/001","ts":"2026-05-13T00:00:01Z"}'
$APPEND "$F" '{"event":"task_completed","task_id":"impl/be/001","ts":"2026-05-13T00:01:00Z"}'

LINE_COUNT=$(wc -l <"$F" | tr -d ' ')
test "$LINE_COUNT" = "3" || { echo "FAIL: expected 3 lines, got $LINE_COUNT"; exit 1; }
$VERIFY "$F"
echo "  3-line chain verifies — OK"
echo

echo "=== Case 2: tamper with line 2 content → verify FAIL at line 2 ==="
F2="$TMP/tamper-content.jsonl"
cp "$F" "$F2"
# Change the event name in line 2 by re-emitting the line with substituted content.
python3 - "$F2" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines()
lines[1] = lines[1].replace('"task_created"', '"task_tampered"')
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
set +e
OUT=$($VERIFY "$F2" 2>&1)
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: tampered file should fail verify"; printf '%s\n' "$OUT"; exit 1; }
grep -q "line 2" <<<"$OUT" || { echo "FAIL: error should name line 2"; printf '%s\n' "$OUT"; exit 1; }
grep -q "hash mismatch" <<<"$OUT" || { echo "FAIL: error should say 'hash mismatch'"; printf '%s\n' "$OUT"; exit 1; }
echo "  tamper detected at line 2 — OK"
echo

echo "=== Case 3: delete line 2 → verify FAIL at line 2 ==="
F3="$TMP/delete-line.jsonl"
cp "$F" "$F3"
python3 - "$F3" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines()
del lines[1]
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
set +e
OUT=$($VERIFY "$F3" 2>&1)
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: line-deletion should fail verify"; printf '%s\n' "$OUT"; exit 1; }
grep -q "line 2" <<<"$OUT" || { echo "FAIL: error should name line 2"; printf '%s\n' "$OUT"; exit 1; }
grep -q "prev_hash mismatch" <<<"$OUT" || { echo "FAIL: error should say 'prev_hash mismatch'"; printf '%s\n' "$OUT"; exit 1; }
echo "  deletion detected at line 2 — OK"
echo

echo "=== Case 4: legacy file (no hash fields) → verify 'no chain', exit 0 ==="
F4="$TMP/legacy.jsonl"
cat > "$F4" <<'JSONL'
{"event":"task_created","task_id":"legacy/001","ts":"2026-04-29T00:00:00Z"}
{"event":"task_completed","task_id":"legacy/001","ts":"2026-04-29T00:01:00Z"}
JSONL
OUT=$($VERIFY "$F4")
grep -q "no chain (legacy" <<<"$OUT" || { echo "FAIL: legacy file should report 'no chain (legacy'"; printf '%s\n' "$OUT"; exit 1; }
echo "  legacy file → no-chain reported, exit 0 — OK"
echo

echo "=== Case 5: mixed-mode (chained + unchained) → verify FAIL ==="
F5="$TMP/mixed.jsonl"
cp "$F" "$F5"
# Append an un-chained line by going around the helper.
echo '{"event":"unchained_intruder","ts":"2026-05-13T00:02:00Z"}' >> "$F5"
set +e
OUT=$($VERIFY "$F5" 2>&1)
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: mixed file should fail verify"; printf '%s\n' "$OUT"; exit 1; }
grep -q "mixed" <<<"$OUT" || { echo "FAIL: error should mention 'mixed'"; printf '%s\n' "$OUT"; exit 1; }
echo "  mixed-mode flagged — OK"
echo

echo "=== Case 6: jsonl-append refuses to append to legacy file ==="
set +e
OUT=$($APPEND "$F4" '{"event":"would_be_first_chained"}' 2>&1)
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: append to legacy file should error"; printf '%s\n' "$OUT"; exit 1; }
grep -q "legacy" <<<"$OUT" || { echo "FAIL: error should mention 'legacy'"; printf '%s\n' "$OUT"; exit 1; }
echo "  append-to-legacy refused — OK"
echo

echo "PASS: jsonl-hash-chain tests"
