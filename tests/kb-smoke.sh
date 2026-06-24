#!/usr/bin/env bash
# tests/kb-smoke.sh — minimal CI smoke check for zachflow KB
#
# Validates:
#   1. All schemas/{learning,products}/*.json are valid JSON.
#   2. All schemas declare $schema as draft 2020-12.
#   3. All .claude/skills/zachflow-kb/*/SKILL.md have valid YAML frontmatter
#      with name: zachflow-kb:<op>.
#   4. .zachflow/kb/learning/patterns/*.yaml match pattern.schema.json.
#   5. .zachflow/kb/learning/rubrics/v*.md frontmatter matches rubric.schema.json.
#   6. .zachflow/kb/learning/reflections/*.md frontmatter matches reflection.schema.json.
#   7. .zachflow/kb/products/**/*.md frontmatter matches product schemas when present.
#
# Requires Python 3 with pyyaml + jsonschema. CI installs both explicitly.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running KB smoke check at: $PROJECT_ROOT"

# Use relative paths so Python's native cwd resolution works on Windows
# git-bash too (where bash sees /d/a/... but Python wants D:\a\...).
cd "$PROJECT_ROOT"

schema_files=(
  schemas/learning/*.json
  schemas/products/product-doc.schema.json
  schemas/products/product-index.schema.json
)

# 1. Schema files are valid JSON
for f in "${schema_files[@]}"; do
  [ -f "$f" ] || { echo "FAIL: required schema missing: $f"; exit 1; }
  python3 -c "import json; json.load(open('$f'))" || {
    echo "FAIL: $f is not valid JSON"
    exit 1
  }
done
echo "  [1/7] schemas/{learning,products}/*.json — valid JSON"

# 2. Schemas declare draft 2020-12
for f in "${schema_files[@]}"; do
  python3 -c "
import json
data = json.load(open('$f'))
assert '\$schema' in data, '\$schema missing in $f'
assert data['\$schema'].endswith('draft/2020-12/schema'), 'wrong dialect: ' + data['\$schema']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [2/7] schemas/{learning,products}/*.json — draft 2020-12"

# 3. KB skill SKILL.md frontmatter (requires PyYAML; CI installs it
# explicitly on macos/windows where it isn't preinstalled).
for f in .claude/skills/zachflow-kb/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f', encoding='utf-8').read()
assert content.startswith('---'), '$f no frontmatter'
end = content.find('---', 3)
assert end > 0, '$f unterminated frontmatter'
fm = yaml.safe_load(content[3:end])
assert 'name' in fm, '$f missing name'
assert fm['name'].startswith('zachflow-kb:'), '$f wrong name prefix: ' + fm['name']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [3/7] zachflow-kb/*/SKILL.md — frontmatter OK"

# Steps 4–6: validate user KB content under .zachflow/kb/ against schemas.
# Skipped when the KB directory is absent (e.g. running smoke in a clean repo
# clone before bootstrap). Empty subdirs are also OK — only present files
# are validated.

KB_LEARNING=".zachflow/kb/learning"

if [ -d "$KB_LEARNING" ]; then
  # 4. patterns/*.yaml validate against pattern.schema.json
  count=0
  if [ -d "$KB_LEARNING/patterns" ]; then
    for f in "$KB_LEARNING"/patterns/*.yaml; do
      [ -f "$f" ] || continue  # no glob match → skip
      python3 - "$f" <<'PY' || exit 1
import json, sys, yaml, jsonschema
path = sys.argv[1]
with open(path, encoding='utf-8') as fp:
    data = yaml.safe_load(fp)
with open('schemas/learning/pattern.schema.json', encoding='utf-8') as fp:
    schema = json.load(fp)
try:
    jsonschema.validate(data, schema)
except jsonschema.ValidationError as e:
    sys.exit(f"FAIL: {path}: {e.message}")
PY
      count=$((count + 1))
    done
  fi
  echo "  [4/7] $KB_LEARNING/patterns/*.yaml — $count file(s) schema-valid"

  # 5. rubrics/v*.md frontmatter validate against rubric.schema.json
  count=0
  if [ -d "$KB_LEARNING/rubrics" ]; then
    for f in "$KB_LEARNING"/rubrics/v*.md; do
      [ -f "$f" ] || continue
      python3 - "$f" <<'PY' || exit 1
import json, sys, yaml, jsonschema
path = sys.argv[1]
content = open(path, encoding='utf-8').read()
if not content.startswith('---'):
    sys.exit(f"FAIL: {path}: no YAML frontmatter")
end = content.find('---', 3)
if end < 0:
    sys.exit(f"FAIL: {path}: unterminated frontmatter")
fm = yaml.safe_load(content[3:end])
with open('schemas/learning/rubric.schema.json', encoding='utf-8') as fp:
    schema = json.load(fp)
try:
    jsonschema.validate(fm, schema)
except jsonschema.ValidationError as e:
    sys.exit(f"FAIL: {path}: {e.message}")
PY
      count=$((count + 1))
    done
  fi
  echo "  [5/7] $KB_LEARNING/rubrics/v*.md — $count file(s) schema-valid"

  # 6. reflections/*.md frontmatter validate against reflection.schema.json
  count=0
  if [ -d "$KB_LEARNING/reflections" ]; then
    for f in "$KB_LEARNING"/reflections/*.md; do
      [ -f "$f" ] || continue
      python3 - "$f" <<'PY' || exit 1
import json, sys, yaml, jsonschema
path = sys.argv[1]
content = open(path, encoding='utf-8').read()
if not content.startswith('---'):
    sys.exit(f"FAIL: {path}: no YAML frontmatter")
end = content.find('---', 3)
if end < 0:
    sys.exit(f"FAIL: {path}: unterminated frontmatter")
fm = yaml.safe_load(content[3:end])
with open('schemas/learning/reflection.schema.json', encoding='utf-8') as fp:
    schema = json.load(fp)
try:
    jsonschema.validate(fm, schema)
except jsonschema.ValidationError as e:
    sys.exit(f"FAIL: {path}: {e.message}")
PY
      count=$((count + 1))
    done
  fi
  echo "  [6/7] $KB_LEARNING/reflections/*.md — $count file(s) schema-valid"
else
  echo "  [4/7] $KB_LEARNING absent — skipping user-content checks"
  echo "  [5/7] $KB_LEARNING absent — skipping user-content checks"
  echo "  [6/7] $KB_LEARNING absent — skipping user-content checks"
fi

KB_PRODUCTS=".zachflow/kb/products"

if [ -d "$KB_PRODUCTS" ]; then
  count=0
  while IFS= read -r -d '' f; do
    if [ "$f" = "$KB_PRODUCTS/README.md" ]; then
      continue
    fi
    python3 - "$f" <<'PY' || exit 1
import json
import os
import sys

import jsonschema
import yaml

path = sys.argv[1]
content = open(path, encoding='utf-8').read()
if not content.startswith('---'):
    sys.exit(f"FAIL: {path}: no YAML frontmatter")
end = content.find('---', 3)
if end < 0:
    sys.exit(f"FAIL: {path}: unterminated frontmatter")
fm = yaml.safe_load(content[3:end])
schema_path = (
    'schemas/products/product-index.schema.json'
    if os.path.basename(path) == 'index.md'
    else 'schemas/products/product-doc.schema.json'
)
with open(schema_path, encoding='utf-8') as fp:
    schema = json.load(fp)
try:
    jsonschema.validate(fm, schema)
except jsonschema.ValidationError as e:
    sys.exit(f"FAIL: {path}: {e.message}")
PY
    count=$((count + 1))
  done < <(find "$KB_PRODUCTS" -type f -name '*.md' -print0)
  echo "  [7/7] $KB_PRODUCTS/**/*.md — $count product file(s) schema-valid"
else
  echo "  [7/7] $KB_PRODUCTS absent — skipping product-content checks"
fi

echo "PASS: KB smoke check"
