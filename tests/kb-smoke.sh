#!/usr/bin/env bash
# tests/kb-smoke.sh — minimal CI smoke check for zachflow KB
#
# Validates:
#   1. All schemas/learning/*.json are valid JSON.
#   2. All schemas declare $schema as draft 2020-12.
#   3. All .claude/skills/zachflow-kb/*/SKILL.md have valid YAML frontmatter
#      with name: zachflow-kb:<op>.
#
# Does NOT validate user KB content (.zachflow/kb/) — that's user-space per
# embedded-mode philosophy. Extend if your project wants stricter checks.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running KB smoke check at: $PROJECT_ROOT"

# Use relative paths so Python's native cwd resolution works on Windows
# git-bash too (where bash sees /d/a/... but Python wants D:\a\...).
cd "$PROJECT_ROOT"

# 1. Schema files are valid JSON
for f in schemas/learning/*.json; do
  python3 -c "import json; json.load(open('$f'))" || {
    echo "FAIL: $f is not valid JSON"
    exit 1
  }
done
echo "  [1/3] schemas/learning/*.json — valid JSON"

# 2. Schemas declare draft 2020-12
for f in schemas/learning/*.json; do
  python3 -c "
import json
data = json.load(open('$f'))
assert '\$schema' in data, '\$schema missing in $f'
assert data['\$schema'].endswith('draft/2020-12/schema'), 'wrong dialect: ' + data['\$schema']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [2/3] schemas/learning/*.json — draft 2020-12"

# 3. KB skill SKILL.md frontmatter (requires PyYAML; CI installs it
# explicitly on macos/windows where it isn't preinstalled).
for f in .claude/skills/zachflow-kb/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f').read()
assert content.startswith('---'), '$f no frontmatter'
end = content.find('---', 3)
assert end > 0, '$f unterminated frontmatter'
fm = yaml.safe_load(content[3:end])
assert 'name' in fm, '$f missing name'
assert fm['name'].startswith('zachflow-kb:'), '$f wrong name prefix: ' + fm['name']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [3/3] zachflow-kb/*/SKILL.md — frontmatter OK"

echo "PASS: KB smoke check"
