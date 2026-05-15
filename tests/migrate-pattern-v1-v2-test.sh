#!/usr/bin/env bash
# tests/migrate-pattern-v1-v2-test.sh — unit test for migrate-pattern-v1-to-v2.py
#
# Asserts:
#   1. v1 pattern gets schema_version=2 + lifecycle field defaults.
#   2. Migrated pattern validates against pattern.schema.json (v2).
#   3. Re-running on a v2 pattern is a no-op (file mtime unchanged).
#   4. --dry-run does not modify the file.
#   5. A malformed v1 (e.g. schema_version: 9) exits non-zero.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPKB_RAW="$(mktemp -d -t zachflow-migrate-XXXXXX)"
trap "rm -rf '$TMPKB_RAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPKB="$(cygpath -m "$TMPKB_RAW")"
else
  TMPKB="$TMPKB_RAW"
fi

mkdir -p "$TMPKB/learning/patterns"

# --- Fixture: a valid v1 pattern -------------------------------------------
cat > "$TMPKB/learning/patterns/correctness-001.yaml" <<'YAML'
id: correctness-001
title: Retry without idempotency key
category: correctness
severity: major
source_sprint: bench-sprint-1
discovered_at: '2026-04-01T12:00:00Z'
frequency: 2
last_seen: bench-sprint-1
description: Retry path issues duplicate POSTs because no idempotency key is set.
detection: grep for fetch retries that POST without an Idempotency-Key header.
prevention: All retried mutating requests MUST carry a stable idempotency key.
contract_clause: Mutating endpoints under retry MUST be idempotent or use Idempotency-Key.
schema_version: 1
YAML

# --- 1. Forward migration ---------------------------------------------------
python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$TMPKB"

python3 - "$TMPKB/learning/patterns/correctness-001.yaml" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
assert data["schema_version"] == 2, f"expected schema_version=2, got {data['schema_version']!r}"
assert data["state"] == "stable", f"expected state=stable, got {data['state']!r}"
assert data["pinned"] is False, f"expected pinned=False, got {data['pinned']!r}"
assert data["created_by"] == "agent", f"expected created_by=agent, got {data['created_by']!r}"
assert data["use_count"] == 0, f"expected use_count=0, got {data['use_count']!r}"
assert data["last_referenced_at"] is None, f"expected last_referenced_at=None"
print("forward migration: OK")
PY

# --- 2. Schema validation of migrated file ---------------------------------
python3 - "$TMPKB/learning/patterns/correctness-001.yaml" "$PROJECT_ROOT/schemas/learning/pattern.schema.json" <<'PY'
import sys, json, yaml, jsonschema
data = yaml.safe_load(open(sys.argv[1]))
schema = json.load(open(sys.argv[2]))
jsonschema.validate(data, schema)
print("schema v2 validation: OK")
PY

# --- 3. Idempotency: re-run should not modify mtime ------------------------
MTIME_BEFORE=$(python3 -c "import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))" "$TMPKB/learning/patterns/correctness-001.yaml")
sleep 1
python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$TMPKB"
MTIME_AFTER=$(python3 -c "import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))" "$TMPKB/learning/patterns/correctness-001.yaml")
if [ "$MTIME_BEFORE" != "$MTIME_AFTER" ]; then
  echo "FAIL: idempotent re-run modified the file (mtime $MTIME_BEFORE -> $MTIME_AFTER)" >&2
  exit 1
fi
echo "idempotent re-run: OK"

# --- 4. --dry-run does not modify ------------------------------------------
cat > "$TMPKB/learning/patterns/correctness-002.yaml" <<'YAML'
id: correctness-002
title: Missing null check on optional user
category: correctness
severity: minor
source_sprint: bench-sprint-1
discovered_at: '2026-04-02T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: Code path assumes user object always present after auth middleware.
detection: trace user.foo accesses without prior null guard.
prevention: Treat user as Option<User> at the type level until verified.
contract_clause: Optional-typed values MUST be unwrapped explicitly before use.
schema_version: 1
YAML
MTIME_BEFORE=$(python3 -c "import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))" "$TMPKB/learning/patterns/correctness-002.yaml")
sleep 1
python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$TMPKB" --dry-run
MTIME_AFTER=$(python3 -c "import os,sys; print(int(os.stat(sys.argv[1]).st_mtime))" "$TMPKB/learning/patterns/correctness-002.yaml")
if [ "$MTIME_BEFORE" != "$MTIME_AFTER" ]; then
  echo "FAIL: --dry-run modified the file" >&2
  exit 1
fi
echo "dry-run preserves file: OK"

# --- 5. Unknown schema_version errors --------------------------------------
cat > "$TMPKB/learning/patterns/correctness-002.yaml" <<'YAML'
id: correctness-002
title: From the future
category: correctness
severity: minor
source_sprint: bench-sprint-1
discovered_at: '2026-04-02T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: This pattern claims a schema version we do not understand.
detection: detection text.
prevention: prevention text.
contract_clause: clause text.
schema_version: 9
YAML
if python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$TMPKB" 2>/dev/null; then
  echo "FAIL: expected non-zero exit on schema_version=9, got 0" >&2
  exit 1
fi
echo "unknown schema_version rejected: OK"

echo ""
echo "All migrate-pattern-v1-v2 tests passed."
