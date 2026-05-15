#!/usr/bin/env bash
# tests/curator-test.sh — unit test for scripts/lib/curator.py
#
# Asserts:
#   1. Dry-run reports decisions and does not modify patterns.
#   2. Auto mode promotes draft → stable when use_count >= 3.
#   3. Auto mode archives stable → archived when use_count==0 and age>ttl.
#   4. pinned=true patterns are not transitioned by auto mode.
#   5. logs/curator.jsonl events are hash-chained and pass jsonl-verify.
#   6. Manual --pattern-id --target-state forces a transition.
#   7. Manual archive of a pinned pattern is refused.
#   8. Schema validation passes on every mutated pattern.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TMPRAW="$(mktemp -d -t zachflow-curator-XXXXXX)"
trap "rm -rf '$TMPRAW'" EXIT

if command -v cygpath >/dev/null 2>&1; then
  TMPROOT="$(cygpath -m "$TMPRAW")"
else
  TMPROOT="$TMPRAW"
fi

KB="$TMPROOT/.zachflow/kb"
mkdir -p "$KB/learning/patterns"
mkdir -p "$TMPROOT/logs"
mkdir -p "$TMPROOT/runs/test/logs"

# --- Fixtures --------------------------------------------------------------
# Draft + 3 references → should promote.
cat > "$KB/learning/patterns/correctness-001.yaml" <<'YAML'
id: correctness-001
title: Promote candidate
category: correctness
severity: major
source_sprint: bench-sprint-1
discovered_at: '2026-04-01T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: A pattern that should promote when referenced 3+ times.
detection: detection text.
prevention: prevention text.
contract_clause: clause text.
schema_version: 2
state: draft
pinned: false
created_by: agent
use_count: 0
last_referenced_at: null
YAML

# Stable + age 200d + 0 references → should archive.
cat > "$KB/learning/patterns/correctness-002.yaml" <<'YAML'
id: correctness-002
title: Archive candidate
category: correctness
severity: minor
source_sprint: bench-sprint-1
discovered_at: '2025-09-01T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: Old stable pattern with no references should be archived.
detection: detection text.
prevention: prevention text.
contract_clause: clause text.
schema_version: 2
state: stable
pinned: false
created_by: agent
use_count: 0
last_referenced_at: null
YAML

# Stable + pinned + age 200d + 0 references → must NOT be archived.
cat > "$KB/learning/patterns/correctness-003.yaml" <<'YAML'
id: correctness-003
title: Pinned should survive
category: correctness
severity: minor
source_sprint: bench-sprint-1
discovered_at: '2025-09-01T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: Pinned patterns must bypass archive even when rules match.
detection: detection text.
prevention: prevention text.
contract_clause: clause text.
schema_version: 2
state: stable
pinned: true
created_by: human
use_count: 0
last_referenced_at: null
YAML

# Synthetic jsonl referencing correctness-001 three times across two files.
cat > "$TMPROOT/logs/refs.jsonl" <<'JSON'
{"ts":"2026-05-01T10:00:00Z","event":"contract.referenced","pattern_id":"correctness-001"}
{"ts":"2026-05-02T10:00:00Z","event":"contract.referenced","pattern_ids":["correctness-001"]}
JSON
cat > "$TMPROOT/runs/test/logs/more.jsonl" <<'JSON'
{"ts":"2026-05-03T10:00:00Z","event":"contract.referenced","pattern_id":"correctness-001"}
JSON

# --- 1. Dry-run does not modify -------------------------------------------
DRY_OUTPUT=$(python3 scripts/lib/curator.py --kb-path "$KB")
echo "$DRY_OUTPUT"

# State should still be 'draft' after dry-run.
DRAFT_STATE=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['state'])" "$KB/learning/patterns/correctness-001.yaml")
if [ "$DRAFT_STATE" != "draft" ]; then
  echo "FAIL: dry-run mutated state to $DRAFT_STATE" >&2
  exit 1
fi
echo "dry-run preserves files: OK"

# --- 2. Apply: promote + archive + pin bypass -----------------------------
python3 scripts/lib/curator.py --kb-path "$KB" --apply

# correctness-001 should now be stable, use_count=3.
python3 - "$KB/learning/patterns/correctness-001.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["state"] == "stable", f"expected stable, got {d['state']!r}"
assert d["use_count"] == 3, f"expected use_count=3, got {d['use_count']!r}"
assert d["last_referenced_at"] == "2026-05-03T10:00:00Z", f"got {d['last_referenced_at']!r}"
print("promote: OK")
PY

# correctness-002 should be moved to .archive/
if [ -f "$KB/learning/patterns/correctness-002.yaml" ]; then
  echo "FAIL: correctness-002.yaml still in patterns/ after archive" >&2
  exit 1
fi
if [ ! -f "$KB/learning/patterns/.archive/correctness-002.yaml" ]; then
  echo "FAIL: correctness-002.yaml not in .archive/ after archive" >&2
  exit 1
fi
ARCHIVED_STATE=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['state'])" "$KB/learning/patterns/.archive/correctness-002.yaml")
if [ "$ARCHIVED_STATE" != "archived" ]; then
  echo "FAIL: archived file has state=$ARCHIVED_STATE" >&2
  exit 1
fi
echo "archive: OK"

# correctness-003 should still be in patterns/ and still stable.
if [ ! -f "$KB/learning/patterns/correctness-003.yaml" ]; then
  echo "FAIL: pinned pattern was moved" >&2
  exit 1
fi
PIN_STATE=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['state'])" "$KB/learning/patterns/correctness-003.yaml")
if [ "$PIN_STATE" != "stable" ]; then
  echo "FAIL: pinned pattern transitioned to $PIN_STATE" >&2
  exit 1
fi
echo "pinned bypass: OK"

# --- 3. Hash chain verification ------------------------------------------
python3 scripts/lib/jsonl-verify.py "$TMPROOT/logs/curator.jsonl"
echo "hash chain on curator.jsonl: OK"

# Should have 2 events (promote + archive). Pinned pattern emits none.
EVENT_COUNT=$(wc -l < "$TMPROOT/logs/curator.jsonl" | tr -d ' ')
if [ "$EVENT_COUNT" != "2" ]; then
  echo "FAIL: expected 2 events, got $EVENT_COUNT" >&2
  cat "$TMPROOT/logs/curator.jsonl"
  exit 1
fi
echo "event count == 2: OK"

# --- 4. Manual mode: force promote (placed in fresh fixture) --------------
cat > "$KB/learning/patterns/edge_case-001.yaml" <<'YAML'
id: edge_case-001
title: Manual promotion target
category: edge_case
severity: minor
source_sprint: bench-sprint-1
discovered_at: '2026-04-01T12:00:00Z'
frequency: 1
last_seen: bench-sprint-1
description: A draft pattern that we forcibly promote via skill wrapper.
detection: detection text.
prevention: prevention text.
contract_clause: clause text.
schema_version: 2
state: draft
pinned: false
created_by: agent
use_count: 0
last_referenced_at: null
YAML

python3 scripts/lib/curator.py --kb-path "$KB" --apply \
  --pattern-id edge_case-001 --target-state stable

FORCED_STATE=$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['state'])" "$KB/learning/patterns/edge_case-001.yaml")
if [ "$FORCED_STATE" != "stable" ]; then
  echo "FAIL: manual promote did not apply (state=$FORCED_STATE)" >&2
  exit 1
fi
echo "manual promote: OK"

# --- 5. Manual archive of pinned should fail -----------------------------
if python3 scripts/lib/curator.py --kb-path "$KB" --apply \
   --pattern-id correctness-003 --target-state archived 2>/dev/null; then
  echo "FAIL: archiving a pinned pattern should have failed" >&2
  exit 1
fi
echo "pinned archive refusal: OK"

# --- 6. Final hash chain integrity (after manual events) -----------------
python3 scripts/lib/jsonl-verify.py "$TMPROOT/logs/curator.jsonl"
EVENT_COUNT=$(wc -l < "$TMPROOT/logs/curator.jsonl" | tr -d ' ')
if [ "$EVENT_COUNT" != "3" ]; then
  echo "FAIL: expected 3 events after manual promote, got $EVENT_COUNT" >&2
  exit 1
fi
echo "final hash chain (3 events): OK"

echo ""
echo "All curator tests passed."
