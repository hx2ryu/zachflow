#!/usr/bin/env bash
# product-workflow-docs-test.sh — guards product KB workflow integration docs.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "product workflow docs test at: $PROJECT_ROOT"

grep -q "Product Context Used" workflows/sprint/phase-spec.md || { echo "FAIL: phase-spec missing Product Context Used"; exit 1; }
grep -q "zachflow-kb:read type=feature" workflows/sprint/phase-spec.md || { echo "FAIL: phase-spec missing feature read"; exit 1; }
grep -q "zachflow-kb:read type=api" workflows/sprint/phase-spec.md || { echo "FAIL: phase-spec missing api read"; exit 1; }
grep -q "zachflow-kb:read type=policy" workflows/sprint/phase-spec.md || { echo "FAIL: phase-spec missing policy read"; exit 1; }
grep -q "zachflow-kb:read type=glossary" workflows/sprint/phase-spec.md || { echo "FAIL: phase-spec missing glossary read"; exit 1; }

grep -q "product-kb-candidates.yaml" workflows/sprint/phase-retro.md || { echo "FAIL: phase-retro missing product candidate artifact"; exit 1; }
grep -q "zachflow-kb:upsert-product-doc" workflows/sprint/phase-retro.md || { echo "FAIL: phase-retro missing product upsert skill"; exit 1; }
grep -q "source_sprint" workflows/sprint/phase-retro.md || { echo "FAIL: phase-retro missing source_sprint"; exit 1; }
grep -q "source_files" workflows/sprint/phase-retro.md || { echo "FAIL: phase-retro missing source_files"; exit 1; }

[ -f templates/product-kb-candidate.template.yaml ] || { echo "FAIL: product candidate template missing"; exit 1; }
grep -q "items:" templates/product-kb-candidate.template.yaml || { echo "FAIL: product candidate template missing items"; exit 1; }
grep -q "Product KB Resource Constraints" templates/sprint-contract.template.md || { echo "FAIL: sprint contract missing product KB resource section"; exit 1; }

echo "PASS: product workflow docs"
