#!/usr/bin/env bash
# demo-mode-test.sh — verifies `init-project.sh --demo` produces a working
# zachflow project against a synthesized throwaway source repo.
#
# Asserts:
#   1. --demo completes without user input
#   2. The throwaway source repo is materialized and has its initial commit
#   3. sprint-config.yaml points its single role at the throwaway path
#   4. The final cleanup banner names the throwaway path so the user can
#      delete it
#   5. --demo + --from=<file> is a hard error (incompatible flags)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "demo-mode test at: $PROJECT_ROOT"

# git-bash returns MSYS paths from mktemp (/tmp/...), which Windows-native
# python3 cannot resolve. Convert to mixed-mode (C:/.../tmp/...) so both
# shell and native binaries accept the same string.
_to_native_path() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*)
      command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || echo "$1"
      ;;
    *) echo "$1" ;;
  esac
}

TMPDIR=$(mktemp -d -t zachflow-demo-test-XXXXXX)
TMPDIR=$(_to_native_path "$TMPDIR")
DEMO_SOURCE_PATHS=()
cleanup() {
  rm -rf "$TMPDIR"
  for p in "${DEMO_SOURCE_PATHS[@]}"; do
    [ -n "$p" ] && rm -rf "$p"
  done
}
trap cleanup EXIT

# Stage a project copy so we don't pollute the working tree.
STAGE="$TMPDIR/stage"
mkdir -p "$STAGE"
(cd "$PROJECT_ROOT" && tar \
  --exclude='./.git' \
  --exclude='./.zachflow' \
  --exclude='./node_modules' \
  --exclude='./.claude/skills/sprint' \
  --exclude='./.claude/skills/qa-fix' \
  -cf - .) | (cd "$STAGE" && tar -xf -)

# ─── Case 1: --demo completes and produces artifacts ────────────────

echo "  [1/3] --demo runs end-to-end without input"
out=$(cd "$STAGE" && bash scripts/init-project.sh --demo 2>&1 </dev/null) || {
  echo "FAIL: --demo exited non-zero"
  echo "$out" | tail -30
  exit 1
}

[ -f "$STAGE/sprint-config.yaml" ] || { echo "FAIL: sprint-config.yaml not produced"; exit 1; }
[ -f "$STAGE/.claude/teammates/be-engineer.md" ] || { echo "FAIL: teammate fill missing"; exit 1; }
[ -d "$STAGE/.zachflow/kb" ] || { echo "FAIL: KB not initialized"; exit 1; }
[ -L "$STAGE/.claude/skills/sprint" ] || { echo "FAIL: sprint symlink missing"; exit 1; }
echo "    OK (config + teammate + KB + symlinks all present)"

# ─── Case 2: throwaway source is a real git repo with one commit ────

echo "  [2/3] throwaway source repo is materialized correctly"
demo_path=$(echo "$out" | grep "Source repo:" | sed -E 's/.*Source repo: ([^[:space:]]+).*/\1/')
[ -n "$demo_path" ] || { echo "FAIL: could not extract demo source path from output"; echo "$out" | tail -30; exit 1; }
DEMO_SOURCE_PATHS+=("$demo_path")
[ -d "$demo_path/.git" ] || { echo "FAIL: demo source has no .git ($demo_path)"; exit 1; }
[ -f "$demo_path/package.json" ] || { echo "FAIL: demo source missing package.json"; exit 1; }
commits=$(git -C "$demo_path" rev-list --count HEAD)
[ "$commits" = "1" ] || { echo "FAIL: expected 1 commit in demo source, got $commits"; exit 1; }

# sprint-config role.source must point at the same path.
python3 -c "
import yaml, sys
data = yaml.safe_load(open('$STAGE/sprint-config.yaml'))
src = data['repositories']['backend']['source']
assert src == '$demo_path', f'role.source mismatch: got {src}, expected $demo_path'
assert data['project_name'] == 'zachflow-demo'
assert data['branch_prefix'] == 'demo'
print('    sprint-config wired to throwaway source: OK')
"

# Cleanup banner must name the demo path so the user can delete it.
echo "$out" | grep -q "rm -rf \"$demo_path\"" || {
  echo "FAIL: cleanup banner missing or doesn't name the demo path"
  echo "$out" | tail -15
  exit 1
}
echo "    OK (1 commit, cleanup banner names the path)"

# ─── Case 3: --demo + --from is rejected ────────────────────────────

echo "  [3/3] --demo + --from=<file> is rejected"
set +e
out3=$(cd "$STAGE" && bash scripts/init-project.sh --demo --from=anything.yaml --non-interactive 2>&1 </dev/null)
rc3=$?
set -e
[ $rc3 -ne 0 ] || { echo "FAIL: --demo + --from should have errored"; exit 1; }
echo "$out3" | grep -q "incompatible" || { echo "FAIL: expected 'incompatible' in error"; echo "$out3"; exit 1; }
echo "    OK (rc=$rc3, conflict reported)"

echo
echo "PASS: demo-mode tests"
