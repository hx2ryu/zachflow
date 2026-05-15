#!/usr/bin/env bash
# preflight-test.sh — unit tests for scripts/lib/preflight.sh.
#
# Covers the three behaviors that matter to the user:
#   1. happy path on a fully-equipped machine returns 0
#   2. missing pyyaml is detected and exits 1 with install hints
#   3. init-project.sh --skip-preflight bypasses the check even when
#      a prerequisite is missing

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "preflight test at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-preflight-test-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# ─── Case 1: happy path ─────────────────────────────────────────────

echo "  [1/3] happy path returns 0"
out=$(bash "$PROJECT_ROOT/scripts/lib/preflight.sh" 2>&1) || {
  echo "FAIL: preflight returned non-zero on a happy-path machine"
  echo "$out"
  exit 1
}
echo "$out" | grep -q "all prerequisites present" || {
  echo "FAIL: expected 'all prerequisites present' marker"
  echo "$out"
  exit 1
}
echo "    OK"

# ─── Case 2: missing pyyaml ─────────────────────────────────────────

echo "  [2/3] missing pyyaml is detected"
FAKE_BIN="$TMPDIR/fake-bin"
mkdir -p "$FAKE_BIN"
REAL_PY3=$(command -v python3)
cat > "$FAKE_BIN/python3" <<EOF
#!/usr/bin/env bash
# Pass everything through to the real python3, except 'import yaml' which
# we simulate as missing (the most common new-machine failure mode).
for arg in "\$@"; do
  if [[ "\$arg" == *"import yaml"* ]]; then
    echo "ModuleNotFoundError: No module named 'yaml'" >&2
    exit 1
  fi
done
exec "$REAL_PY3" "\$@"
EOF
chmod +x "$FAKE_BIN/python3"

set +e
out=$(PATH="$FAKE_BIN:$PATH" bash "$PROJECT_ROOT/scripts/lib/preflight.sh" 2>&1)
rc=$?
set -e
[ $rc -eq 0 ] && { echo "FAIL: preflight returned 0 with pyyaml missing"; echo "$out"; exit 1; }
echo "$out" | grep -q "yaml (pyyaml)" || { echo "FAIL: missing pyyaml not flagged"; echo "$out"; exit 1; }
echo "$out" | grep -q "pipx install pyyaml\|pip install" || { echo "FAIL: install hint missing"; echo "$out"; exit 1; }
echo "    OK (exit=$rc, install hints surfaced)"

# ─── Case 3: --skip-preflight bypasses the preflight check ──────────
# Note: --skip-preflight bypasses preflight only; the wizard still needs
# its actual runtime deps. So with pyyaml missing AND --skip-preflight,
# we expect (a) no preflight error output (the gate was skipped) and
# (b) the wizard to begin executing before failing for the real reason.

echo "  [3/3] init-project.sh --skip-preflight bypasses the check"
# Stage a copy of the project so we can run --non-interactive against a
# fixture without touching the working tree (same approach as
# init-project-smoke.sh).
STAGE="$TMPDIR/stage"
mkdir -p "$STAGE"
(cd "$PROJECT_ROOT" && tar \
  --exclude='./.git' \
  --exclude='./.zachflow' \
  --exclude='./node_modules' \
  --exclude='./.claude/skills/sprint' \
  --exclude='./.claude/skills/qa-fix' \
  -cf - .) | (cd "$STAGE" && tar -xf -)

cat > "$STAGE/init.config.yaml" <<'EOF'
project_name: preflight-bypass
workflows: both
branch_prefix: sprint
roles:
  - key: backend
    source: /tmp/fake-backend
    base: main
    mode: worktree
    teammate: be-engineer
kb:
  mode: embedded
init_kb: false
EOF

# Baseline: WITHOUT --skip-preflight, preflight should refuse to proceed
# (pyyaml missing). Confirm the gate fires before --skip-preflight is tested.
set +e
out_without=$(cd "$STAGE" && PATH="$FAKE_BIN:$PATH" \
  bash scripts/init-project.sh --from=init.config.yaml --non-interactive --force 2>&1)
rc_without=$?
set -e
[ $rc_without -ne 0 ] || { echo "FAIL: baseline (no --skip-preflight) unexpectedly succeeded"; exit 1; }
echo "$out_without" | grep -q "preflight: missing" || {
  echo "FAIL: baseline did not surface preflight error"
  echo "$out_without" | tail -20
  exit 1
}

# WITH --skip-preflight: preflight error message must NOT appear, and the
# wizard's own banner must appear (proving control reached the wizard body).
set +e
out_with=$(cd "$STAGE" && PATH="$FAKE_BIN:$PATH" \
  bash scripts/init-project.sh --from=init.config.yaml --non-interactive --skip-preflight --force 2>&1)
set -e
if echo "$out_with" | grep -q "preflight: missing"; then
  echo "FAIL: --skip-preflight did not actually skip the check"
  echo "$out_with" | tail -20
  exit 1
fi
echo "$out_with" | grep -q "zachflow init (non-interactive)" || {
  echo "FAIL: wizard banner missing — control never reached the wizard body"
  echo "$out_with" | tail -20
  exit 1
}
echo "    OK (gate fires by default; --skip-preflight lets the wizard start)"

echo
echo "PASS: preflight unit tests"
