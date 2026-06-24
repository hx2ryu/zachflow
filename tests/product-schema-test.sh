#!/usr/bin/env bash
# Focused fixtures for OKF-compatible product KB frontmatter schemas.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

python3 <<'PY'
import json
import sys

import jsonschema
import yaml


def load_schema(path):
    with open(path, encoding="utf-8") as fp:
        return json.load(fp)


doc_schema = load_schema("schemas/products/product-doc.schema.json")
index_schema = load_schema("schemas/products/product-index.schema.json")

valid_feature = yaml.safe_load(
    """
schema_version: 1
type: feature
title: Billing CSV export
resource: products/billing/features/csv-export
status: active
tags: [billing, export]
source_sprint: sprint-042
source_files:
  - runs/sprint/sprint-042/PRD.md
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
"""
)

valid_index = yaml.safe_load(
    """
schema_version: 1
type: product_index
title: Billing
resource: products/billing
status: active
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
"""
)

missing_resource = yaml.safe_load(
    """
schema_version: 1
type: feature
title: Billing CSV export
status: active
updated_at: "2026-06-24T00:00:00Z"
"""
)

jsonschema.validate(valid_feature, doc_schema)
jsonschema.validate(valid_index, index_schema)

try:
    jsonschema.validate(missing_resource, doc_schema)
except jsonschema.ValidationError as exc:
    if "resource" not in str(exc):
        sys.exit(f"FAIL: missing resource failed for unexpected reason: {exc.message}")
else:
    sys.exit("FAIL: product doc missing resource should fail schema validation")

print("PASS: product schema fixtures")
PY
