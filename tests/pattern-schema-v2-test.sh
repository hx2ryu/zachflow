#!/usr/bin/env bash
# tests/pattern-schema-v2-test.sh — boundary tests for pattern schema v2.
#
# Asserts:
#   1. A minimal valid v2 pattern (with all new fields default-shaped) validates.
#   2. schema_version: 1 is rejected (must be exactly 2 in v2 schema).
#   3. state outside the enum is rejected.
#   4. pinned with non-boolean type is rejected.
#   5. use_count negative is rejected.
#   6. last_referenced_at accepts both null and ISO-8601.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

SCHEMA="$PROJECT_ROOT/schemas/learning/pattern.schema.json"

# --- 1. Valid v2 pattern --------------------------------------------------
python3 - "$SCHEMA" <<'PY'
import json, sys, jsonschema
schema = json.load(open(sys.argv[1]))
valid = {
  "id": "correctness-001",
  "title": "Valid pattern",
  "category": "correctness",
  "severity": "major",
  "source_sprint": "bench-sprint-1",
  "discovered_at": "2026-04-01T12:00:00Z",
  "frequency": 1,
  "last_seen": "bench-sprint-1",
  "description": "Description text.",
  "detection": "Detection text.",
  "prevention": "Prevention text.",
  "contract_clause": "Clause text.",
  "schema_version": 2,
  "state": "stable",
  "pinned": False,
  "created_by": "agent",
  "use_count": 0,
  "last_referenced_at": None
}
jsonschema.validate(valid, schema)
print("valid v2 pattern: OK")
PY

# --- 2-5. Each invalid variant must raise -----------------------------------
python3 - "$SCHEMA" <<'PY'
import json, sys, copy, jsonschema
schema = json.load(open(sys.argv[1]))
base = {
  "id": "correctness-001", "title": "T", "category": "correctness",
  "severity": "major", "source_sprint": "s-1",
  "discovered_at": "2026-04-01T12:00:00Z",
  "frequency": 1, "last_seen": "s-1",
  "description": "Description text.", "detection": "Detection text.",
  "prevention": "Prevention text.", "contract_clause": "Clause text.",
  "schema_version": 2
}

def must_fail(label, mutator):
    d = copy.deepcopy(base)
    mutator(d)
    try:
        jsonschema.validate(d, schema)
    except jsonschema.ValidationError:
        print(f"{label}: rejected as expected")
        return
    raise SystemExit(f"FAIL: {label} should have failed validation")

must_fail("schema_version=1", lambda d: d.update(schema_version=1))
must_fail("state=foo",         lambda d: d.update(state="foo"))
must_fail("pinned='no'",       lambda d: d.update(pinned="no"))
must_fail("use_count=-1",      lambda d: d.update(use_count=-1))
PY

# --- 6. last_referenced_at: null and ISO accepted -------------------------
python3 - "$SCHEMA" <<'PY'
import json, sys, copy, jsonschema
schema = json.load(open(sys.argv[1]))
base = {
  "id": "correctness-001", "title": "T", "category": "correctness",
  "severity": "major", "source_sprint": "s-1",
  "discovered_at": "2026-04-01T12:00:00Z",
  "frequency": 1, "last_seen": "s-1",
  "description": "Description text.", "detection": "Detection text.",
  "prevention": "Prevention text.", "contract_clause": "Clause text.",
  "schema_version": 2
}
for v in (None, "2026-05-15T10:30:00Z"):
    d = copy.deepcopy(base); d["last_referenced_at"] = v
    jsonschema.validate(d, schema)
print("last_referenced_at null/ISO: OK")
PY

echo ""
echo "All pattern schema v2 tests passed."
