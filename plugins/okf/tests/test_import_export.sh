#!/usr/bin/env bash
# test_import_export.sh — OKF plugin local bundle import/export tests.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
echo "okf import/export test at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-okf-test-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

SOURCE="$TMPDIR/source-billing"
KB="$TMPDIR/kb"
EXPORT="$TMPDIR/export"
mkdir -p "$SOURCE/features" "$KB/products"

cat > "$SOURCE/index.md" <<'MD'
---
schema_version: 1
type: product_index
title: Billing
resource: products/billing
status: active
tags: [billing]
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
---

# Billing
MD

cat > "$SOURCE/features/csv-export.md" <<'MD'
---
schema_version: 1
type: feature
title: CSV export
resource: products/billing/features/csv-export
status: active
tags: [billing, export]
source_sprint: sprint-042
source_files:
  - runs/sprint/sprint-042/PRD.md
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
---

# CSV export
MD

echo "  [1/4] Import validates and copies local OKF bundle"
python3 "$PLUGIN_ROOT/scripts/okf_bundle.py" import \
  --source "$SOURCE" \
  --product billing \
  --kb-path "$KB" \
  >/tmp/okf-import.out
[ -f "$KB/products/billing/index.md" ] || { echo "FAIL: imported index missing"; exit 1; }
[ -f "$KB/products/billing/features/csv-export.md" ] || { echo "FAIL: imported feature missing"; exit 1; }
echo "    OK"

echo "  [2/4] Export validates and copies product bundle"
python3 "$PLUGIN_ROOT/scripts/okf_bundle.py" export \
  --product billing \
  --destination "$EXPORT" \
  --kb-path "$KB" \
  >/tmp/okf-export.out
[ -f "$EXPORT/billing/index.md" ] || { echo "FAIL: exported index missing"; exit 1; }
grep -q "products/billing/features/csv-export" "$EXPORT/billing/features/csv-export.md" || {
  echo "FAIL: exported feature resource missing"
  exit 1
}
echo "    OK"

echo "  [3/4] Invalid bundle is rejected before import"
INVALID="$TMPDIR/invalid"
mkdir -p "$INVALID/features"
cat > "$INVALID/index.md" <<'MD'
---
schema_version: 1
type: product_index
title: Invalid
resource: products/invalid
status: active
updated_at: "2026-06-24T00:00:00Z"
---

# Invalid
MD
cat > "$INVALID/features/bad.md" <<'MD'
---
schema_version: 1
type: feature
title: Bad feature
status: active
updated_at: "2026-06-24T00:00:00Z"
---

# Bad feature
MD
set +e
python3 "$PLUGIN_ROOT/scripts/okf_bundle.py" import \
  --source "$INVALID" \
  --product invalid \
  --kb-path "$KB" \
  >/tmp/okf-invalid.out 2>/tmp/okf-invalid.err
rc=$?
set -e
[ $rc -ne 0 ] || { echo "FAIL: invalid import should fail"; exit 1; }
[ ! -d "$KB/products/invalid" ] || { echo "FAIL: invalid bundle should not be copied"; exit 1; }
grep -q "resource" /tmp/okf-invalid.err || {
  echo "FAIL: invalid error should mention resource"
  cat /tmp/okf-invalid.err
  exit 1
}
echo "    OK"

echo "  [4/4] Plugin is discoverable"
plugin_list=$(bash "$PROJECT_ROOT/scripts/install-plugins.sh" --list)
echo "$plugin_list" | grep -q "okf" || {
  echo "FAIL: okf plugin missing from install-plugins --list"
  exit 1
}
echo "    OK"

echo
echo "PASS: OKF import/export tests"
