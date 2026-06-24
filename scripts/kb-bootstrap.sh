#!/usr/bin/env bash
set -euo pipefail

# zachflow KB bootstrap — embedded mode
# v1.x will add remote-mode support (pull from external git repo when KB_PATH points to a remote-mode clone).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB_DIR="${PROJECT_ROOT}/.zachflow/kb"
DEMO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --demo) DEMO=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/kb-bootstrap.sh [--demo]

Initializes the embedded zachflow KB at .zachflow/kb/.

Options:
  --demo    Seed a small OKF-compatible product KB bundle for demo projects.
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "${KB_DIR}/learning/patterns"
mkdir -p "${KB_DIR}/learning/rubrics"
mkdir -p "${KB_DIR}/learning/reflections"
mkdir -p "${KB_DIR}/products"

# Sprint 1: seed initial active rubric v1 if absent
RUBRIC_V1="${KB_DIR}/learning/rubrics/v1.md"
if [ ! -f "$RUBRIC_V1" ]; then
  cat > "$RUBRIC_V1" <<'EOF'
---
version: 1
status: active
superseded_by: null
schema_version: 1
changelog: |
  v1 — baseline rubric seeded by kb-bootstrap.sh on first run.
---

# Evaluator Rubric v1

The active Evaluator rubric. New clauses are promoted from observed patterns
(see `zachflow-kb:promote-rubric`). Version bumps (v1 → v2) consolidate the
Promotion Log into the Clauses section — currently a manual operation.

## Clauses

(No clauses yet. Patterns earn promotion via the `zachflow-kb:promote-rubric`
skill at Phase 6 Retro when `frequency >= 2` and a `contract_clause` is defined.)

## Promotion Log

| Date | Sprint | Clause Added | Source Pattern |
|------|--------|--------------|----------------|
| —    | —      | (baseline)   | —              |
EOF
fi

# Product KB is optional. Seed only a root marker by default so the directory is
# visible in Git without inventing a product slug for real projects.
PRODUCTS_README="${KB_DIR}/products/README.md"
if [ ! -f "$PRODUCTS_README" ]; then
  cat > "$PRODUCTS_README" <<'EOF'
# Product Knowledge Base

Optional OKF-compatible product/domain memory lives under this directory.

Default bootstrap keeps this directory empty except for this marker. Product
bundles use this shape when a project opts in:

```text
products/<product-slug>/
├── index.md
├── features/
├── apis/
├── decisions/
├── policies/
└── glossary/
```

Run `bash tests/kb-smoke.sh` after adding product docs; Markdown frontmatter is
validated against `schemas/products/*.schema.json`.
EOF
fi

if [ "$DEMO" -eq 1 ]; then
  DEMO_PRODUCT="${KB_DIR}/products/zachflow-demo"
  mkdir -p "$DEMO_PRODUCT/features"

  DEMO_INDEX="$DEMO_PRODUCT/index.md"
  if [ ! -f "$DEMO_INDEX" ]; then
    cat > "$DEMO_INDEX" <<'EOF'
---
schema_version: 1
type: product_index
title: Zachflow Demo
resource: products/zachflow-demo
status: active
tags: [demo, zachflow]
source_sprint: demo-1
source_files:
  - templates/demo-source/README.md
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
---

# Zachflow Demo

Demo product knowledge for the throwaway source project created by
`scripts/init-project.sh --demo`.
EOF
  fi

  DEMO_FEATURE="$DEMO_PRODUCT/features/greeting-function.md"
  if [ ! -f "$DEMO_FEATURE" ]; then
    cat > "$DEMO_FEATURE" <<'EOF'
---
schema_version: 1
type: feature
title: Greeting function
resource: products/zachflow-demo/features/greeting-function
status: active
tags: [demo, greeting]
source_sprint: demo-1
source_files:
  - templates/demo-source/src/index.js
  - templates/demo-source/src/index.test.js
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
---

# Greeting function

The demo source exposes a `greet(name)` function and tests its returned greeting.
EOF
  fi
fi

if [ ! -f "${KB_DIR}/.initialized" ]; then
  touch "${KB_DIR}/.initialized"
  echo "zachflow KB initialized at ${KB_DIR} (embedded mode)"
else
  echo "zachflow KB already initialized at ${KB_DIR}"
fi
