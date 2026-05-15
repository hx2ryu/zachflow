#!/usr/bin/env bash
# create-zachflow-smoke.sh — smoke test for the npx bootstrap wrapper.
#
# Verifies:
#   1. --no-init skips the wizard (no sprint-config.yaml emitted).
#   2. Non-TTY invocation (CI default) also skips the wizard.
#   3. The clone-and-strip pipeline still produces a usable project tree.
#
# Uses a local bare clone of the host repo as the --repo= source, so the
# test runs offline and against the working tree's current state.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "create-zachflow smoke at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-cz-smoke-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

BARE_REPO="$TMPDIR/zachflow.git"
HEAD_REF=$(git -C "$PROJECT_ROOT" symbolic-ref --short HEAD)

# 1. Make a local bare clone so --repo= and --branch= can target it offline.
echo "  [1/3] Build local bare clone (branch=$HEAD_REF)"
git clone --bare --quiet "$PROJECT_ROOT" "$BARE_REPO"

run_wrapper() {
  # run_wrapper TARGET [extra args...]
  local tgt="$1"; shift
  node "$PROJECT_ROOT/packages/create-zachflow/index.js" \
    "$tgt" \
    --repo="$BARE_REPO" \
    --branch="$HEAD_REF" \
    "$@"
}

# 2. --no-init: wrapper should clone-and-strip but NOT run wizard.
echo "  [2/3] --no-init skips the wizard"
TARGET1="$TMPDIR/project-no-init"
# Redirect stdin from /dev/null to also assert non-TTY path works alongside --no-init.
run_wrapper "$TARGET1" --no-init </dev/null > "$TMPDIR/out1.log" 2>&1 || {
  echo "FAIL: wrapper exited non-zero with --no-init"
  cat "$TMPDIR/out1.log"
  exit 1
}
[ -d "$TARGET1" ] || { echo "FAIL: target directory not created"; exit 1; }
[ -f "$TARGET1/scripts/init-project.sh" ] || { echo "FAIL: project tree incomplete (init-project.sh missing)"; exit 1; }
[ -d "$TARGET1/.git" ] || { echo "FAIL: fresh git init missing"; exit 1; }
if [ -f "$TARGET1/sprint-config.yaml" ]; then
  echo "FAIL: sprint-config.yaml exists but --no-init was set (wizard ran anyway)"
  exit 1
fi
grep -q "Next steps:" "$TMPDIR/out1.log" || {
  echo "FAIL: expected 'Next steps:' guidance in output"
  cat "$TMPDIR/out1.log"
  exit 1
}
echo "    --no-init OK (project created, wizard skipped, guidance printed)"

# 3. Non-TTY default (no --no-init): wizard should also skip because stdin
#    is not a TTY. This is the CI path.
echo "  [3/3] Non-TTY stdin also skips the wizard (CI path)"
TARGET2="$TMPDIR/project-non-tty"
run_wrapper "$TARGET2" </dev/null > "$TMPDIR/out2.log" 2>&1 || {
  echo "FAIL: wrapper exited non-zero on non-TTY default"
  cat "$TMPDIR/out2.log"
  exit 1
}
[ -d "$TARGET2" ] || { echo "FAIL: target directory not created"; exit 1; }
if [ -f "$TARGET2/sprint-config.yaml" ]; then
  echo "FAIL: wizard ran in non-TTY context (sprint-config.yaml created)"
  exit 1
fi
grep -q "Next steps:" "$TMPDIR/out2.log" || {
  echo "FAIL: expected 'Next steps:' guidance on non-TTY default"
  exit 1
}
echo "    non-TTY OK (wizard correctly skipped)"

echo
echo "PASS: create-zachflow smoke check"
