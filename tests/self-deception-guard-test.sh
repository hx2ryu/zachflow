#!/usr/bin/env bash
# tests/self-deception-guard-test.sh — unit test for scripts/lib/guards/self_deception_guard.py
#
# Asserts:
#   1. Different authors for impl vs eval, PASS verdict w/ citations → pass.
#   2. Same author for impl + eval → warn (same-author).
#   3. Evaluator committer modified a source-dir file → warn (evaluator-touched-source).
#   4. PASS verdict report with zero `file:line` citations → warn (pass-without-evidence).
#   5. hash chain.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRAW="$(mktemp -d -t zachflow-selfdec-XXXXXX)"
trap "rm -rf '$TMPRAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPDIR="$(cygpath -m "$TMPRAW")"
else
  TMPDIR="$TMPRAW"
fi

PROJECT="$TMPDIR/proj"
SPRINT_REL="runs/sprint/test-sprint"
mkdir -p "$PROJECT/$SPRINT_REL/evaluations" "$PROJECT/backend/src"
cd "$PROJECT"

git init -q
git config user.email "alice@example.com"
git config user.name "Alice"

# Keep logs/ out of git history.
cat > .gitignore <<'GI'
logs/
GI
git add .gitignore && git commit -q -m "init"

run_guard() {
  python3 "$PROJECT_ROOT/scripts/lib/guards/self_deception_guard.py" \
    --sprint-dir "$PROJECT/$SPRINT_REL" --group 1 --repo "$PROJECT" \
    --source-dirs backend "$@"
}

# --- Setup: Alice writes impl, Bob writes eval --------------------------
echo "x = 1" > backend/src/a.py
git add -A
git -c user.email=alice@example.com -c user.name=Alice commit -q -m "impl: a.py"

mkdir -p "$SPRINT_REL/evaluations"
# Healthy eval report: cites file:line, verdict PASS.
cat > "$SPRINT_REL/evaluations/group-1.md" <<'MD'
# Evaluation Report: Group 1

## Summary
- Verdict: PASS

## Contract Verification
- [x] DC1: VERIFIED
  - Evidence: backend/src/a.py:1 - assignment trace OK.
MD
git add -A
git -c user.email=bob@example.com -c user.name=Bob commit -q -m "eval: group-1 PASS"

# --- 1. Healthy case → pass ---------------------------------------------
run_guard
echo "different authors + citations → pass: OK"

# --- 2. Same author for impl + eval → warn ------------------------------
cat > "$SPRINT_REL/evaluations/group-1.md" <<'MD'
# Evaluation Report: Group 1

## Summary
- Verdict: PASS

## Contract Verification
- [x] DC1: VERIFIED
  - Evidence: backend/src/a.py:1 — citation included.
MD
git add -A
git -c user.email=alice@example.com -c user.name=Alice commit -q -m "eval: tweak group-1"
OUTPUT=$(run_guard)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for same-author"; exit 1; }
echo "$OUTPUT" | grep -q 'same-author' || { echo "FAIL: same-author label missing"; exit 1; }
echo "same author → warn: OK"

# --- 3. Evaluator committer touches a source-dir file → warn ------------
# Charlie is an Evaluator who also (wrongly) edits backend/src/a.py.
echo "x = 2" > backend/src/a.py
git add -A
git -c user.email=charlie@example.com -c user.name=Charlie commit -q -m "fix: a.py bug"
# Make Charlie an "evaluator" by having him commit the eval file.
# Content differs from the prior eval so `git commit` has something to record.
cat > "$SPRINT_REL/evaluations/group-1.md" <<'MD'
# Evaluation Report: Group 1 (Charlie's review)

## Summary
- Verdict: PASS

## Contract Verification
- [x] DC1: VERIFIED
  - Evidence: backend/src/a.py:1 — verified by Charlie.
MD
git add -A
git -c user.email=charlie@example.com -c user.name=Charlie commit -q -m "eval: charlie's verdict"
OUTPUT=$(run_guard)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for evaluator-touched-source"; exit 1; }
echo "$OUTPUT" | grep -q 'evaluator-touched-source' || { echo "FAIL: missing label"; exit 1; }
echo "evaluator touched source → warn: OK"

# --- 4. PASS verdict with zero citations → warn -------------------------
# Use a fresh sprint dir for clean authorship state.
NEWSPRINT="runs/sprint/sprint-2"
mkdir -p "$NEWSPRINT/evaluations"
cat > "$NEWSPRINT/evaluations/group-1.md" <<'MD'
# Evaluation Report: Group 1

## Summary
- Verdict: PASS

## Contract Verification
- [x] DC1: VERIFIED

(No file:line citations on purpose — this should be flagged.)
MD
git add -A
git -c user.email=dora@example.com -c user.name=Dora commit -q -m "eval: sprint-2 group-1"
OUTPUT=$(python3 "$PROJECT_ROOT/scripts/lib/guards/self_deception_guard.py" \
  --sprint-dir "$PROJECT/$NEWSPRINT" --group 1 --repo "$PROJECT" \
  --source-dirs backend)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for pass-without-evidence"; exit 1; }
echo "$OUTPUT" | grep -q 'pass-without-evidence' || { echo "FAIL: missing label"; exit 1; }
echo "PASS without evidence → warn: OK"

# --- 5. hash chain ------------------------------------------------------
python3 "$PROJECT_ROOT/scripts/lib/jsonl-verify.py" "$PROJECT/logs/guards.jsonl"
EVENTS=$(wc -l < "$PROJECT/logs/guards.jsonl" | tr -d ' ')
if [ "$EVENTS" -lt "4" ]; then
  echo "FAIL: expected ≥4 events, got $EVENTS" >&2; exit 1
fi
echo "hash chain ($EVENTS events): OK"

echo ""
echo "All self_deception_guard tests passed."
