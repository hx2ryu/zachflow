#!/usr/bin/env bash
# kb-read-product-test.sh — verifies zachflow-kb:read product query behavior.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "kb-read product test at: $PROJECT_ROOT"

TMPKB=$(mktemp -d -t zachflow-kb-read-XXXXXX)
trap 'rm -rf "$TMPKB"' EXIT

mkdir -p "$TMPKB/learning/rubrics"
mkdir -p "$TMPKB/products/billing/features"
mkdir -p "$TMPKB/products/billing/apis"
mkdir -p "$TMPKB/products/support/features"

cat > "$TMPKB/learning/rubrics/v1.md" <<'MD'
---
version: 1
status: superseded
superseded_by: 2
schema_version: 1
---

# Rubric v1
MD

cat > "$TMPKB/learning/rubrics/v2.md" <<'MD'
---
version: 2
status: active
superseded_by: null
schema_version: 1
---

# Rubric v2
MD

cat > "$TMPKB/products/billing/index.md" <<'MD'
---
schema_version: 1
type: product_index
title: Billing
resource: products/billing
status: active
tags: [billing]
updated_at: "2026-06-01T00:00:00Z"
confidence: confirmed
---

# Billing
MD

cat > "$TMPKB/products/billing/features/old-export.md" <<'MD'
---
schema_version: 1
type: feature
title: Old export
resource: products/billing/features/old-export
status: active
tags: [billing, export]
updated_at: "2026-06-01T00:00:00Z"
confidence: confirmed
---

# Old export
MD

cat > "$TMPKB/products/billing/features/csv-export.md" <<'MD'
---
schema_version: 1
type: feature
title: CSV export
resource: products/billing/features/csv-export
status: active
tags: [billing, export]
updated_at: "2026-06-10T00:00:00Z"
confidence: confirmed
---

# CSV export
MD

cat > "$TMPKB/products/billing/features/draft-export.md" <<'MD'
---
schema_version: 1
type: feature
title: Draft export
resource: products/billing/features/draft-export
status: draft
tags: [billing, export]
updated_at: "2026-06-20T00:00:00Z"
confidence: draft
---

# Draft export
MD

cat > "$TMPKB/products/billing/apis/invoices.md" <<'MD'
---
schema_version: 1
type: api
title: Invoices API
resource: products/billing/apis/invoices
status: active
tags: [billing, invoices]
updated_at: "2026-06-11T00:00:00Z"
confidence: confirmed
---

# Invoices API
MD

cat > "$TMPKB/products/support/features/canned-replies.md" <<'MD'
---
schema_version: 1
type: feature
title: Canned replies
resource: products/support/features/canned-replies
status: active
tags: [support]
updated_at: "2026-06-12T00:00:00Z"
confidence: confirmed
---

# Canned replies
MD

echo "  [1/4] Product feature queries filter by product/tag/status"
out=$(KB_PATH="$TMPKB" python3 scripts/lib/kb-read.py type=feature product=billing tag=export status=active)
echo "$out" | grep -q '/billing/features/csv-export.md$' || { echo "FAIL: csv export missing"; echo "$out"; exit 1; }
echo "$out" | grep -q '/billing/features/old-export.md$' || { echo "FAIL: old export missing"; echo "$out"; exit 1; }
echo "$out" | grep -q 'draft-export' && { echo "FAIL: draft export should be excluded by status"; echo "$out"; exit 1; }
echo "$out" | grep -q '/support/' && { echo "FAIL: support product should be excluded"; echo "$out"; exit 1; }
echo "    OK"

echo "  [2/4] Product feature queries sort active docs before newer drafts"
out=$(KB_PATH="$TMPKB" python3 scripts/lib/kb-read.py type=feature product=billing tag=export limit=2)
first=$(echo "$out" | sed -n '1p')
second=$(echo "$out" | sed -n '2p')
case "$first" in
  */billing/features/csv-export.md) ;;
  *) echo "FAIL: expected csv-export first, got $first"; exit 1 ;;
esac
case "$second" in
  */billing/features/old-export.md) ;;
  *) echo "FAIL: expected old-export second, got $second"; exit 1 ;;
esac
echo "    OK"

echo "  [3/4] Product index query returns index paths"
out=$(KB_PATH="$TMPKB" python3 scripts/lib/kb-read.py type=product product=billing)
case "$out" in
  */products/billing/index.md) echo "    OK" ;;
  *) echo "FAIL: expected billing index, got $out"; exit 1 ;;
esac

echo "  [4/4] Learning rubric query remains supported and unknown types fail"
out=$(KB_PATH="$TMPKB" python3 scripts/lib/kb-read.py type=rubric status=active)
case "$out" in
  */learning/rubrics/v2.md) ;;
  *) echo "FAIL: expected active rubric v2, got $out"; exit 1 ;;
esac
set +e
err=$(KB_PATH="$TMPKB" python3 scripts/lib/kb-read.py type=widget 2>&1 >/tmp/kb-read-widget.out)
rc=$?
set -e
[ $rc -ne 0 ] || { echo "FAIL: unknown type should exit non-zero"; exit 1; }
echo "$err" | grep -q "unsupported type" || { echo "FAIL: unknown type error should mention unsupported type"; echo "$err"; exit 1; }
echo "    OK"

echo
echo "PASS: kb-read product tests"
