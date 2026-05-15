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
TOTAL_STEPS=4
step=0
next_step() { step=$((step + 1)); echo "  [$step/$TOTAL_STEPS] $1"; }

TMPDIR=$(mktemp -d -t zachflow-cz-smoke-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

BARE_REPO="$TMPDIR/zachflow.git"
SMOKE_REF="ci-smoke-head"

# 1. Make a local bare clone so --repo= and --branch= can target it offline.
# Detached-HEAD-safe: in PR builds, actions/checkout leaves HEAD detached, so
# `git symbolic-ref HEAD` would fail. Instead we materialize a local branch
# in the bare clone pointing at the current HEAD SHA — works for both detached
# and attached checkouts.
HEAD_SHA=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
next_step "Build local bare clone (ref=$SMOKE_REF @ ${HEAD_SHA:0:8})"
git clone --bare --quiet "$PROJECT_ROOT" "$BARE_REPO"
git -C "$BARE_REPO" update-ref "refs/heads/$SMOKE_REF" "$HEAD_SHA"

run_wrapper() {
  # run_wrapper TARGET [extra args...]
  local tgt="$1"; shift
  node "$PROJECT_ROOT/packages/create-zachflow/index.js" \
    "$tgt" \
    --repo="$BARE_REPO" \
    --branch="$SMOKE_REF" \
    "$@"
}

# 2. --no-init: wrapper should clone-and-strip but NOT run wizard.
next_step "--no-init skips the wizard"
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
next_step "Non-TTY stdin also skips the wizard (CI path)"
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

# 4. Fresh machine simulation: no git user.name / user.email anywhere.
#    HOME is empty so global config is absent; GIT_CONFIG_NOSYSTEM=1 hides
#    the system config; unsetting GIT_AUTHOR_* / GIT_COMMITTER_* removes the
#    env override path. The wrapper must inject its own author identity
#    fallback so the initial commit succeeds.
next_step "Fresh machine fallback (no global git identity)"
TARGET3="$TMPDIR/project-no-identity"
HOME_OVERRIDE="$TMPDIR/empty-home"
mkdir -p "$HOME_OVERRIDE"
env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL \
  HOME="$HOME_OVERRIDE" \
  XDG_CONFIG_HOME="$HOME_OVERRIDE/.config" \
  GIT_CONFIG_NOSYSTEM=1 \
  node "$PROJECT_ROOT/packages/create-zachflow/index.js" \
    "$TARGET3" \
    --repo="$BARE_REPO" \
    --branch="$SMOKE_REF" \
    --no-init </dev/null > "$TMPDIR/out3.log" 2>&1 || {
  echo "FAIL: wrapper exited non-zero with no git identity available"
  cat "$TMPDIR/out3.log"
  exit 1
}
[ -d "$TARGET3/.git" ] || { echo "FAIL: fresh git init missing"; exit 1; }
# Verify the initial commit actually exists (it would not, if commit had failed).
LAST_AUTHOR=$(git -C "$TARGET3" log -n1 --pretty=format:'%an <%ae>' 2>/dev/null || echo "")
[ -n "$LAST_AUTHOR" ] || { echo "FAIL: no commit landed in fresh-machine simulation"; exit 1; }
echo "    fresh-machine OK (initial commit by: $LAST_AUTHOR)"

echo
echo "PASS: create-zachflow smoke check"
