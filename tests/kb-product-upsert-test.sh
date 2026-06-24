#!/usr/bin/env bash
# kb-product-upsert-test.sh — verifies sanctioned product KB write/update path.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "kb-product upsert test at: $PROJECT_ROOT"

TMPKB=$(mktemp -d -t zachflow-kb-product-upsert-XXXXXX)
trap 'rm -rf "$TMPKB"' EXIT

mkdir -p "$TMPKB/products"

echo "  [1/4] Create a schema-valid feature doc"
KB_PATH="$TMPKB" python3 scripts/lib/kb-product-upsert.py \
  type=feature \
  product=billing \
  slug=csv-export \
  title="Billing CSV export" \
  status=active \
  confidence=confirmed \
  tags=billing,export \
  source_sprint=sprint-042 \
  source_files=runs/sprint/sprint-042/PRD.md,runs/sprint/sprint-042/api-contract.yaml \
  updated_at=2026-06-24T00:00:00Z \
  summary="Users with finance access can export billing history as CSV." \
  >/tmp/kb-product-upsert-create.out

created="$TMPKB/products/billing/features/csv-export.md"
[ -f "$created" ] || { echo "FAIL: feature doc not created at expected path"; exit 1; }
python3 - "$created" <<'PY'
import sys, yaml
content = open(sys.argv[1], encoding="utf-8").read()
fm = yaml.safe_load(content[3:content.find("---", 3)])
assert fm["resource"] == "products/billing/features/csv-export"
assert fm["source_sprint"] == "sprint-042"
assert fm["source_files"] == [
    "runs/sprint/sprint-042/PRD.md",
    "runs/sprint/sprint-042/api-contract.yaml",
]
assert fm["confidence"] == "confirmed"
PY
echo "    OK"

echo "  [2/4] Update existing resource without creating a duplicate"
KB_PATH="$TMPKB" python3 scripts/lib/kb-product-upsert.py \
  type=feature \
  product=billing \
  slug=csv-export \
  title="Billing CSV export" \
  status=active \
  confidence=confirmed \
  tags=billing,export,finance \
  source_sprint=sprint-043 \
  source_files=runs/sprint/sprint-043/PRD.md \
  updated_at=2026-06-25T00:00:00Z \
  summary="Finance users can export filtered billing history as CSV." \
  >/tmp/kb-product-upsert-update.out

count=$(find "$TMPKB/products" -type f -name 'csv-export.md' | wc -l | tr -d ' ')
[ "$count" = "1" ] || { echo "FAIL: expected one csv-export doc, got $count"; exit 1; }
python3 - "$created" <<'PY'
import sys, yaml
content = open(sys.argv[1], encoding="utf-8").read()
fm = yaml.safe_load(content[3:content.find("---", 3)])
assert fm["source_sprint"] == "sprint-043"
assert fm["updated_at"] == "2026-06-25T00:00:00Z"
assert "finance" in fm["tags"]
assert "filtered billing history" in content
PY
echo "    OK"

echo "  [3/4] Existing resource at a moved path is updated in place"
mkdir -p "$TMPKB/products/billing/features/legacy"
mv "$created" "$TMPKB/products/billing/features/legacy/csv-export.md"
KB_PATH="$TMPKB" python3 scripts/lib/kb-product-upsert.py \
  type=feature \
  product=billing \
  slug=csv-export \
  title="Billing CSV export" \
  status=active \
  confidence=confirmed \
  tags=billing,export \
  source_sprint=sprint-044 \
  source_files=runs/sprint/sprint-044/PRD.md \
  updated_at=2026-06-26T00:00:00Z \
  summary="CSV export remains available." \
  >/tmp/kb-product-upsert-moved.out

[ -f "$TMPKB/products/billing/features/legacy/csv-export.md" ] || { echo "FAIL: moved doc was not updated in place"; exit 1; }
[ ! -f "$created" ] || { echo "FAIL: duplicate created at canonical path"; exit 1; }
echo "    OK"

echo "  [4/4] Invalid frontmatter is rejected before write"
set +e
KB_PATH="$TMPKB" python3 scripts/lib/kb-product-upsert.py \
  type=feature \
  product=billing \
  slug=bad-export \
  title="Bad export" \
  status=active \
  confidence=confirmed \
  source_sprint=sprint-045 \
  source_files= \
  updated_at=2026-06-27T00:00:00Z \
  summary="This should fail." \
  >/tmp/kb-product-upsert-invalid.out 2>/tmp/kb-product-upsert-invalid.err
rc=$?
set -e
[ $rc -ne 0 ] || { echo "FAIL: empty source_files should fail"; exit 1; }
[ ! -f "$TMPKB/products/billing/features/bad-export.md" ] || { echo "FAIL: invalid doc was written"; exit 1; }
grep -q "source_files" /tmp/kb-product-upsert-invalid.err || {
  echo "FAIL: invalid error should mention source_files"
  cat /tmp/kb-product-upsert-invalid.err
  exit 1
}
echo "    OK"

echo
echo "PASS: kb-product upsert tests"
