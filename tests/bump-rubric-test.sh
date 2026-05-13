#!/usr/bin/env bash
# tests/bump-rubric-test.sh — unit test for scripts/lib/bump-rubric.py
#
# Builds a sandbox KB, seeds rubric + patterns, and asserts the helper:
#   1. Triggers a bump when Promotion Log has >= 2 non-baseline rows.
#   2. Marks the prior version superseded.
#   3. Inlines source_pattern.contract_clause verbatim into the new Clauses.
#   4. Is a no-op when the log is empty.
#   5. Errors out with --force on an empty log.
#   6. Errors when a Promotion Log row references a missing pattern.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPKB="$(mktemp -d)"
trap "rm -rf '$TMPKB'" EXIT

mkdir -p "$TMPKB/learning/rubrics"
mkdir -p "$TMPKB/learning/patterns"

cat > "$TMPKB/learning/rubrics/v1.md" <<'MD'
---
version: 1
status: active
superseded_by: null
schema_version: 1
changelog: |
  v1 — baseline.
---

# Evaluator Rubric v1

## Clauses

(No clauses yet.)

## Promotion Log

| Date | Sprint | Clause Added | Source Pattern |
|------|--------|--------------|----------------|
| —          | —              | (baseline)            | —               |
| 2026-05-01 | sprint-foo     | C10 Retry Idempotency | correctness-001 |
| 2026-05-02 | sprint-bar     | C11 Cursor Pagination | integration-002 |
MD

cat > "$TMPKB/learning/patterns/correctness-001.yaml" <<'YAML'
id: correctness-001
title: Retry Idempotency
category: correctness
severity: major
source_sprint: sprint-foo
discovered_at: 2026-05-01T00:00:00Z
frequency: 2
last_seen: sprint-foo
description: When a transient API failure triggers a retry, the second call must be idempotent.
detection: Search for POST handlers without idempotency keys.
prevention: Require an idempotency key for non-GET handlers, validate server-side.
contract_clause: |
  All POST/PUT/PATCH handlers MUST accept an Idempotency-Key header and
  deduplicate based on it for 24h.
schema_version: 1
YAML

cat > "$TMPKB/learning/patterns/integration-002.yaml" <<'YAML'
id: integration-002
title: Cursor Pagination
category: integration
severity: major
source_sprint: sprint-bar
discovered_at: 2026-05-02T00:00:00Z
frequency: 2
last_seen: sprint-bar
description: Cursor-based pagination drifts under concurrent insert/delete.
detection: Look for offset+limit pagination on append-only lists.
prevention: Use opaque cursor that encodes a stable sort key.
contract_clause: |
  List endpoints MUST use opaque cursor pagination; offset/limit on mutable
  collections is forbidden.
schema_version: 1
YAML

echo "=== Case 1: 2 non-baseline entries → bump triggered ==="
python3 scripts/lib/bump-rubric.py --kb-path "$TMPKB"
test -f "$TMPKB/learning/rubrics/v2.md" || { echo "FAIL: v2.md not created"; exit 1; }
test -f "$TMPKB/learning/rubrics/v1.md" || { echo "FAIL: v1.md lost"; exit 1; }

python3 - <<PY
import yaml
c = open('$TMPKB/learning/rubrics/v1.md', encoding='utf-8').read()
fm = yaml.safe_load(c[3:c.find('---', 3)])
assert fm['status'] == 'superseded', fm
assert fm['superseded_by'] == 2, fm
print('  v1 status:', fm['status'], 'superseded_by:', fm['superseded_by'])
PY

python3 - <<PY
import yaml
c = open('$TMPKB/learning/rubrics/v2.md', encoding='utf-8').read()
fm = yaml.safe_load(c[3:c.find('---', 3)])
assert fm['version'] == 2, fm
assert fm['status'] == 'active', fm
assert fm['superseded_by'] is None, fm
body = c[c.find('---', 3) + 3:]
assert '### C10. Retry Idempotency' in body, 'C10 missing'
assert '### C11. Cursor Pagination' in body, 'C11 missing'
assert 'Idempotency-Key' in body, 'C10 contract_clause body missing'
assert 'opaque cursor' in body, 'C11 contract_clause body missing'
assert '## Promotion Log' in body, 'Promotion Log section missing'
assert '(baseline)' in body, 'baseline row missing from new log'
print('  v2 OK — 2 clauses inlined, fresh log seeded')
PY
echo

echo "=== Case 2: re-run after bump → no-op (empty log on v2) ==="
python3 scripts/lib/bump-rubric.py --kb-path "$TMPKB"
test ! -f "$TMPKB/learning/rubrics/v3.md" || { echo "FAIL: v3.md created on no-op"; exit 1; }
echo "  v3 not created — correct"
echo

echo "=== Case 3: --force on empty log → error ==="
set +e
python3 scripts/lib/bump-rubric.py --kb-path "$TMPKB" --force >/tmp/bump-c3.out 2>&1
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: --force on empty log should error"; cat /tmp/bump-c3.out; exit 1; }
grep -q "Promotion Log is empty" /tmp/bump-c3.out || { echo "FAIL: expected 'Promotion Log is empty' in output"; cat /tmp/bump-c3.out; exit 1; }
echo "  exit $RC — correct"
echo

echo "=== Case 4: missing source_pattern → error ==="
# Make v2 superseded by hand and seed a v3 with a dangling pattern ref.
python3 - <<PY
import yaml
p = '$TMPKB/learning/rubrics/v2.md'
c = open(p, encoding='utf-8').read()
end = c.find('---', 3)
fm = yaml.safe_load(c[3:end])
fm['status'] = 'superseded'
fm['superseded_by'] = 3
out = '---\n' + yaml.safe_dump(fm, sort_keys=False).strip() + '\n---\n' + c[end+3:].lstrip()
open(p, 'w', encoding='utf-8').write(out)
PY

cat > "$TMPKB/learning/rubrics/v3.md" <<'MD'
---
version: 3
status: active
superseded_by: null
schema_version: 1
changelog: |
  v3 — case 4 sandbox.
---

# Rubric v3

## Clauses

## Promotion Log

| Date | Sprint | Clause Added | Source Pattern |
|------|--------|--------------|----------------|
| —          | —          | (baseline) | —                  |
| 2026-05-03 | sprint-x   | C99 Nope   | correctness-999    |
| 2026-05-04 | sprint-y   | C100 Yep   | integration-002    |
MD

set +e
python3 scripts/lib/bump-rubric.py --kb-path "$TMPKB" >/tmp/bump-c4.out 2>&1
RC=$?
set -e
test $RC -ne 0 || { echo "FAIL: missing pattern should error"; cat /tmp/bump-c4.out; exit 1; }
grep -q "correctness-999" /tmp/bump-c4.out || { echo "FAIL: error msg should name missing pattern"; cat /tmp/bump-c4.out; exit 1; }
echo "  exit $RC — correct (names missing pattern)"
echo

echo "PASS: bump-rubric unit tests"
