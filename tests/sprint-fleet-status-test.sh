#!/usr/bin/env bash
# tests/sprint-fleet-status-test.sh — unit test for sprint-fleet-status.py
#
# Builds a sandbox runs/sprint/ tree with:
#   - one in-flight sprint (mid Phase 4 — contracts/ has rows, evaluations/ partial)
#   - one done sprint (retrospective/ has a real file)
#   - one bare directory (no sprint-config.yaml — should be ignored)
# Then asserts the dashboard separates in-flight from done and ignores the bare dir.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRUNS_RAW="$(mktemp -d -t zachflow-sprint-fleet-XXXXXX)"
trap "rm -rf '$TMPRUNS_RAW'" EXIT

# Windows git-bash: convert to a path Python (native Windows) understands.
if command -v cygpath >/dev/null 2>&1; then
  TMPRUNS="$(cygpath -m "$TMPRUNS_RAW")"
else
  TMPRUNS="$TMPRUNS_RAW"
fi

# In-flight sprint: contracts + partial evaluations + no retrospective.
mkdir -p "$TMPRUNS/sprint-flight/contracts"
mkdir -p "$TMPRUNS/sprint-flight/evaluations"
mkdir -p "$TMPRUNS/sprint-flight/checkpoints"
mkdir -p "$TMPRUNS/sprint-flight/retrospective"

cat > "$TMPRUNS/sprint-flight/sprint-config.yaml" <<'YAML'
type: standard
base: main
repositories:
  app:
    source: ../app
    base: main
    mode: worktree
branch_prefix: sprint
YAML

cat > "$TMPRUNS/sprint-flight/contracts/group-001.md" <<'MD'
# Sprint Contract: Group 1
- [x] AC1
MD
cat > "$TMPRUNS/sprint-flight/contracts/group-002.md" <<'MD'
# Sprint Contract: Group 2
- [ ] AC2
MD

# group-001 PASS — Verdict line present.
cat > "$TMPRUNS/sprint-flight/evaluations/group-001.md" <<'MD'
# Evaluation: Group 1
Verdict: PASS

Notes: clean run.
MD

# Done sprint: retrospective file present.
mkdir -p "$TMPRUNS/sprint-done/retrospective"
mkdir -p "$TMPRUNS/sprint-done/evaluations"
cat > "$TMPRUNS/sprint-done/sprint-config.yaml" <<'YAML'
type: standard
base: main
repositories:
  app:
    source: ../app
    base: main
    mode: worktree
branch_prefix: sprint
YAML
cat > "$TMPRUNS/sprint-done/evaluations/group-001.md" <<'MD'
# Evaluation: Group 1
Verdict: PASS
MD
cat > "$TMPRUNS/sprint-done/retrospective/retro.md" <<'MD'
# Retro: sprint-done
Pattern Digest: ...
MD

# Bare directory: no sprint-config.yaml — must be ignored.
mkdir -p "$TMPRUNS/random-junk-dir"
touch "$TMPRUNS/random-junk-dir/scratch.txt"

echo "=== Case 1: in-flight + done + ignore bare ==="
OUT="$(python3 scripts/lib/sprint-fleet-status.py --runs-dir "$TMPRUNS")"
printf '%s\n' "$OUT"
echo

grep -q "In flight (1):" <<<"$OUT" || { echo "FAIL: missing 'In flight (1):' header"; exit 1; }
grep -q "Completed — retrospective present (1):" <<<"$OUT" || { echo "FAIL: missing 'Completed' header"; exit 1; }
grep -q "sprint-flight" <<<"$OUT" || { echo "FAIL: sprint-flight not listed"; exit 1; }
grep -q "sprint-done" <<<"$OUT" || { echo "FAIL: sprint-done not listed"; exit 1; }
grep -q "random-junk-dir" <<<"$OUT" && { echo "FAIL: bare dir surfaced as a sprint"; exit 1; } || true
grep -q "1/2" <<<"$OUT" || { echo "FAIL: expected '1/2' groups column on sprint-flight"; exit 1; }
echo "  in-flight grouping, done grouping, junk-ignore, groups-pass count — OK"
echo

echo "=== Case 2: empty runs dir ==="
EMPTY_RAW="$(mktemp -d -t zachflow-sprint-fleet-empty-XXXXXX)"
trap "rm -rf '$TMPRUNS_RAW' '$EMPTY_RAW'" EXIT
if command -v cygpath >/dev/null 2>&1; then
  EMPTY="$(cygpath -m "$EMPTY_RAW")"
else
  EMPTY="$EMPTY_RAW"
fi
OUT2="$(python3 scripts/lib/sprint-fleet-status.py --runs-dir "$EMPTY")"
printf '%s\n' "$OUT2"
grep -q "No sprint runs found" <<<"$OUT2" || { echo "FAIL: empty runs dir should report 'No sprint runs found'"; exit 1; }
echo "  empty runs dir → 'No sprint runs found' — OK"
echo

echo "=== Case 3: missing runs dir ==="
OUT3="$(python3 scripts/lib/sprint-fleet-status.py --runs-dir /nonexistent/path/that/should/not/exist)"
printf '%s\n' "$OUT3"
grep -q "No sprint runs found" <<<"$OUT3" || { echo "FAIL: missing runs dir should report gracefully"; exit 1; }
echo "  missing runs dir → graceful 'No sprint runs found' — OK"
echo

echo "PASS: sprint-fleet-status tests"
