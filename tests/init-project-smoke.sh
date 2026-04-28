#!/usr/bin/env bash
# init-project-smoke.sh — non-interactive smoke test for scripts/init-project.sh
#
# Creates a fixture init.config.yaml, runs the wizard non-interactively in a
# temporary copy of the project, and verifies the outputs exist and parse.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "init-project smoke at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-init-smoke-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# 1. Copy project tree to temp dir (excluding .git, .zachflow, node_modules)
echo "  [1/5] Stage project copy at $TMPDIR"
rsync -a --exclude='.git/' --exclude='.zachflow/' --exclude='node_modules/' \
      "${PROJECT_ROOT}/" "${TMPDIR}/"

cd "$TMPDIR"

# 2. Write fixture init.config.yaml
cat > init.config.yaml <<'EOF'
project_name: smoke-test
workflows: both
branch_prefix: sprint
roles:
  - key: backend
    source: /tmp/fake-backend
    base: main
    mode: worktree
    teammate: be-engineer
    fill:
      stack_description: |
        Smoke test backend.
      repo_layout: |
        src/
      build_cmd: |
        echo build
      conventions: |
        - Smoke convention
kb:
  mode: embedded
init_kb: false
EOF

# 3. Run wizard non-interactively
echo "  [2/5] Run init-project.sh --non-interactive"
bash scripts/init-project.sh --from=init.config.yaml --non-interactive --force > /tmp/wizard-output.log 2>&1 || {
  echo "FAIL: wizard exited non-zero"
  cat /tmp/wizard-output.log
  exit 1
}

# 4. Verify outputs
echo "  [3/5] Verify sprint-config.yaml"
[ -f sprint-config.yaml ] || { echo "FAIL: sprint-config.yaml not created"; exit 1; }
python3 -c "
import yaml
data = yaml.safe_load(open('sprint-config.yaml'))
assert data['project_name'] == 'smoke-test', f'got {data[\"project_name\"]}'
assert data['workflows'] == 'both'
assert data['branch_prefix'] == 'sprint'
assert 'backend' in data['repositories']
assert data['repositories']['backend']['mode'] == 'worktree'
assert data['kb']['mode'] == 'embedded'
print('    sprint-config.yaml OK')
"

echo "  [4/5] Verify .claude/teammates/be-engineer.md fill"
[ -f .claude/teammates/be-engineer.md ] || { echo "FAIL: be-engineer.md not created"; exit 1; }
grep -q "wizard fill" .claude/teammates/be-engineer.md || { echo "FAIL: marker missing"; exit 1; }
grep -q "Smoke test backend" .claude/teammates/be-engineer.md || { echo "FAIL: stack_description not substituted"; exit 1; }
echo "    be-engineer.md OK (marker present, stack filled)"

echo "  [5/5] Verify symlinks were installed"
[ -L .claude/skills/sprint ] || { echo "FAIL: sprint symlink missing"; exit 1; }
[ -L .claude/skills/qa-fix ] || { echo "FAIL: qa-fix symlink missing"; exit 1; }
echo "    symlinks OK"

echo
echo "PASS: init-project smoke check"
