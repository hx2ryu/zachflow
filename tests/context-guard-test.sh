#!/usr/bin/env bash
# tests/context-guard-test.sh — unit test for scripts/lib/guards/context_guard.py
#
# Asserts:
#   1. Well-formed phase-2 checkpoint → pass.
#   2. Anemic checkpoint (< min-bytes) → warn.
#   3. Checkpoint with no markdown headings → warn.
#   4. Missing checkpoint → warn.
#   5. Chain check: entering Phase 4 with phase-1/2/3 missing → warn.
#   6. Group-N variant (zero-padded form preferred).
#   7. hash chain.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRAW="$(mktemp -d -t zachflow-context-XXXXXX)"
trap "rm -rf '$TMPRAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPDIR="$(cygpath -m "$TMPRAW")"
else
  TMPDIR="$TMPRAW"
fi

SPRINT="$TMPDIR/proj/runs/sprint/test-sprint"
mkdir -p "$SPRINT/checkpoints"

run_guard() {
  python3 "$PROJECT_ROOT/scripts/lib/guards/context_guard.py" \
    --sprint-dir "$SPRINT" "$@"
}

# --- 1. Healthy phase-2 checkpoint → pass --------------------------------
cat > "$SPRINT/checkpoints/phase-2-summary.md" <<'MD'
# Spec phase summary

## Decisions
- Picked X over Y for performance reasons.

## Open questions
- None blocking.
MD
OUTPUT=$(run_guard --phase-completed 2)
echo "$OUTPUT" | grep -q '^✓' || { echo "FAIL: expected pass"; exit 1; }
echo "phase-2 healthy → pass: OK"

# --- 2. Anemic phase-3 checkpoint → warn ---------------------------------
echo "# tiny" > "$SPRINT/checkpoints/phase-3-summary.md"
OUTPUT=$(run_guard --phase-completed 3)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for anemic"; exit 1; }
echo "anemic checkpoint → warn: OK"

# --- 3. Headings-less checkpoint → warn ----------------------------------
python3 -c "open('$SPRINT/checkpoints/phase-4-summary.md','w').write('flat text without markdown headings ' * 10)"
OUTPUT=$(run_guard --phase-completed 4)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for missing headings"; exit 1; }
echo "no-headings → warn: OK"

# --- 4. Missing phase-6 checkpoint → warn --------------------------------
OUTPUT=$(run_guard --phase-completed 6)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn for missing"; exit 1; }
echo "missing checkpoint → warn: OK"

# --- 5. Chain check: entering phase 4 with phase-1/2/3 missing ----------
rm -f "$SPRINT/checkpoints/phase-2-summary.md" \
      "$SPRINT/checkpoints/phase-3-summary.md"
# Make a well-formed phase-3 summary so the primary check passes —
# the chain check fails on phase-1 + phase-2 being absent.
cat > "$SPRINT/checkpoints/phase-3-summary.md" <<'MD'
# Prototype phase summary

## Designed screens
- LandingScreen, DetailScreen.

This block exists to clear the 100-byte and heading checks.
MD
OUTPUT=$(run_guard --phase-completed 3 --next-phase 4)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn from chain check"; exit 1; }
echo "$OUTPUT" | grep -q 'chain-broken' || { echo "FAIL: chain-broken finding missing"; exit 1; }
echo "$OUTPUT" | grep -q 'phase-1' || { echo "FAIL: phase-1 not named in chain-missing"; exit 1; }
echo "chain-broken → warn: OK"

# --- 6. Group-N variant: zero-padded form preferred -----------------------
cat > "$SPRINT/checkpoints/group-001-summary.md" <<'MD'
# Group 1 summary

## What was built
- Endpoint POST /comments, with validation and persistence.
- Frontend CommentForm with optimistic update.

## Open follow-ups
- None — promoted insights to KB patterns.
MD
OUTPUT=$(run_guard --group 1)
echo "$OUTPUT" | grep -q '^✓' || { echo "FAIL: expected pass for group-001"; exit 1; }
echo "group-001 padded → pass: OK"

# Bare `group-1-summary.md` should also be accepted.
rm "$SPRINT/checkpoints/group-001-summary.md"
mv /dev/null "$SPRINT/checkpoints/group-1-summary.md" 2>/dev/null || true
cat > "$SPRINT/checkpoints/group-1-summary.md" <<'MD'
# Group 1 summary (bare form)

## What was built
- Endpoint POST /comments, with validation and persistence.
- Frontend CommentForm with optimistic update.
MD
OUTPUT=$(run_guard --group 1)
echo "$OUTPUT" | grep -q '^✓' || { echo "FAIL: expected pass for bare group-1"; exit 1; }
echo "group-1 bare fallback → pass: OK"

# --- 7. hash chain --------------------------------------------------------
python3 "$PROJECT_ROOT/scripts/lib/jsonl-verify.py" "$TMPDIR/proj/logs/guards.jsonl"
EVENTS=$(wc -l < "$TMPDIR/proj/logs/guards.jsonl" | tr -d ' ')
if [ "$EVENTS" -lt "7" ]; then
  echo "FAIL: expected ≥7 events, got $EVENTS" >&2; exit 1
fi
echo "hash chain ($EVENTS events): OK"

echo ""
echo "All context_guard tests passed."
