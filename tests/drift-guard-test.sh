#!/usr/bin/env bash
# tests/drift-guard-test.sh — unit test for scripts/lib/guards/drift_guard.py
#
# Asserts:
#   1. Clean commits → pass (exit 0).
#   2. Commit message with "while I'm here" → block (exit 1).
#   3. Commit message with "also fix" → block.
#   4. --check-scope with no contract paths declared → pass.
#   5. --check-scope with contract paths declared + out-of-scope changes → warn.
#   6. --strict + scope violation → block.
#   7. Every event lands hash-chained in logs/guards.jsonl.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRAW="$(mktemp -d -t zachflow-drift-XXXXXX)"
trap "rm -rf '$TMPRAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPDIR="$(cygpath -m "$TMPRAW")"
else
  TMPDIR="$TMPRAW"
fi

# Build a fake project with a git repo and a fake sprint dir.
PROJECT="$TMPDIR/proj"
mkdir -p "$PROJECT/runs/sprint/test-sprint/contracts"
cd "$PROJECT"

git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# `.gitignore` keeps the guard's own audit log (and the sprint run dir) out
# of git history — otherwise `git add -A` below would commit them and a
# later `git reset --hard` would silently revert appended events.
cat > .gitignore <<'GI'
logs/
runs/
GI

# Baseline commit on main.
mkdir -p src
echo "x = 1" > src/a.py
git add -A && git commit -q -m "initial"
BASE=$(git rev-parse HEAD)

# Group branch with clean commits.
git checkout -q -b feat/group-1
echo "y = 2" > src/b.py
git add -A && git commit -q -m "feat: add b"
echo "z = 3" > src/c.py
git add -A && git commit -q -m "feat: add c"

run_guard() {
  python3 "$PROJECT_ROOT/scripts/lib/guards/drift_guard.py" \
    --sprint-dir "$PROJECT/runs/sprint/test-sprint" \
    --group 1 --base "$BASE" --repo "$PROJECT" "$@"
}

# --- 1. Clean commits → pass ----------------------------------------------
run_guard
echo "clean commits → pass: OK"

# --- 2. Admission phrase "while I'm here" → block -------------------------
echo "y = 22" > src/b.py
git add -A && git commit -q -m "fix: improve b. while I'm here, also cleaned d"
if run_guard 2>/dev/null; then
  echo "FAIL: admission phrase should have blocked" >&2; exit 1
fi
echo "admission phrase → block: OK"

# --- 3. "also fix" phrase → block -----------------------------------------
echo "x = 11" > src/a.py
git add -A && git commit -q -m "fix: bug A. also fix unrelated thing"
if run_guard 2>/dev/null; then
  echo "FAIL: 'also fix' should have blocked" >&2; exit 1
fi
echo "'also fix' → block: OK"

# Rewind to clean branch for scope tests.
git reset -q --hard HEAD~2

# --- 4. --check-scope with no contract → pass (warn skipped) --------------
run_guard --check-scope
echo "--check-scope without contract → pass: OK"

# --- 5. --check-scope with contract scope + out-of-scope change → warn ----
cat > "$PROJECT/runs/sprint/test-sprint/contracts/group-1.md" <<'MD'
# Sprint Contract: Group 1
Done Criteria touch `src/a.py` and `src/b.py` only.
MD
mkdir -p other
echo "outside" > other/oops.py
git add -A && git commit -q -m "feat: out of scope"
OUTPUT=$(run_guard --check-scope)
echo "$OUTPUT" | grep -q '^⚠' || { echo "FAIL: expected warn line"; exit 1; }
echo "scope violation → warn: OK"

# --- 6. --strict + scope violation → block --------------------------------
if run_guard --check-scope --strict 2>/dev/null; then
  echo "FAIL: --strict + scope violation should have blocked" >&2; exit 1
fi
echo "--strict + scope → block: OK"

# --- 7. hash chain integrity ----------------------------------------------
python3 "$PROJECT_ROOT/scripts/lib/jsonl-verify.py" "$PROJECT/logs/guards.jsonl"
EVENTS=$(wc -l < "$PROJECT/logs/guards.jsonl" | tr -d ' ')
if [ "$EVENTS" -lt "5" ]; then
  echo "FAIL: expected ≥5 events, got $EVENTS" >&2
  cat "$PROJECT/logs/guards.jsonl"; exit 1
fi
echo "hash chain ($EVENTS events): OK"

echo ""
echo "All drift_guard tests passed."
