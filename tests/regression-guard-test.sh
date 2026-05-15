#!/usr/bin/env bash
# tests/regression-guard-test.sh — unit test for scripts/lib/guards/regression_guard.py
#
# Asserts:
#   1. Active rubric with clauses + Contract refs clauses + has snapshot → pass.
#   2. Active rubric has clauses but Contract refs none → warn.
#   3. Contract missing snapshot markers → warn.
#   4. Contract file missing → warn.
#   5. hash chain.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRAW="$(mktemp -d -t zachflow-regression-XXXXXX)"
trap "rm -rf '$TMPRAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPDIR="$(cygpath -m "$TMPRAW")"
else
  TMPDIR="$TMPRAW"
fi

SPRINT="$TMPDIR/proj/runs/sprint/test-sprint"
KB="$TMPDIR/proj/.zachflow/kb"
mkdir -p "$SPRINT/contracts" "$KB/learning/rubrics" "$KB/learning/patterns"

# Active rubric with two clauses.
cat > "$KB/learning/rubrics/v1.md" <<'MD'
---
version: 1
status: active
superseded_by: null
schema_version: 1
changelog: v1 — baseline.
---
# Evaluator Rubric v1

## Clauses

### C1. Retry idempotency
Mutating endpoints MUST be idempotent under retry.

### C2. Null-safe access
Optional-typed values MUST be unwrapped explicitly before use.

## Promotion Log
| Date | Sprint | Clause Added | Source Pattern |
|------|--------|--------------|----------------|
| —    | —      | (baseline)   | —              |
MD

run_guard() {
  python3 "$PROJECT_ROOT/scripts/lib/guards/regression_guard.py" \
    --sprint-dir "$SPRINT" --group 1 --kb-path "$KB" "$@"
}

# --- 1. Healthy contract referencing C1 + has snapshot → pass -------------
cat > "$SPRINT/contracts/group-1.md" <<'MD'
# Sprint Contract: Group 1

--- FROZEN SNAPSHOT ---
KB patterns: correctness-001 (Retry idempotency, C1).
--- END SNAPSHOT ---

## Done Criteria
- DC1 — POST /comments is idempotent on retry (rubric C1 enforced).
- DC2 — Author lookup handles null user (rubric C2).
MD
run_guard
echo "healthy contract → pass: OK"

# --- 2. Contract refs none of rubric clauses → warn -----------------------
cat > "$SPRINT/contracts/group-1.md" <<'MD'
# Sprint Contract: Group 1

--- FROZEN SNAPSHOT ---
KB patterns: none referenced.
--- END SNAPSHOT ---

## Done Criteria
- DC1 — submit a comment.
- DC2 — show success toast.
MD
OUTPUT=$(run_guard)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for no rubric refs"; exit 1; }
echo "$OUTPUT" | grep -q 'rubric-not-injected' || { echo "FAIL: missing finding label"; exit 1; }
echo "rubric not injected → warn: OK"

# --- 3. Contract missing snapshot markers → warn --------------------------
cat > "$SPRINT/contracts/group-1.md" <<'MD'
# Sprint Contract: Group 1

## Done Criteria
- DC1 — implement C1 retry idempotency.
- DC2 — handle null per C2.
MD
OUTPUT=$(run_guard)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for missing snapshot"; exit 1; }
echo "$OUTPUT" | grep -q 'missing-snapshot' || { echo "FAIL: missing-snapshot finding"; exit 1; }
echo "no snapshot → warn: OK"

# --- 4. Missing contract → warn -------------------------------------------
rm -f "$SPRINT/contracts/group-1.md"
OUTPUT=$(run_guard)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for missing contract"; exit 1; }
echo "missing contract → warn: OK"

# --- 5. hash chain --------------------------------------------------------
python3 "$PROJECT_ROOT/scripts/lib/jsonl-verify.py" "$TMPDIR/proj/logs/guards.jsonl"
EVENTS=$(wc -l < "$TMPDIR/proj/logs/guards.jsonl" | tr -d ' ')
if [ "$EVENTS" -lt "4" ]; then
  echo "FAIL: expected ≥4 events, got $EVENTS" >&2; exit 1
fi
echo "hash chain ($EVENTS events): OK"

echo ""
echo "All regression_guard tests passed."
