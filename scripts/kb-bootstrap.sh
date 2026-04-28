#!/usr/bin/env bash
set -euo pipefail

# zachflow KB bootstrap — Sprint 1 embedded mode
# v1.x will add remote-mode support (pull from external git repo when KB_PATH points to a remote-mode clone).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB_DIR="${PROJECT_ROOT}/.zachflow/kb"

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

if [ ! -f "${KB_DIR}/.initialized" ]; then
  touch "${KB_DIR}/.initialized"
  echo "zachflow KB initialized at ${KB_DIR} (embedded mode)"
else
  echo "zachflow KB already initialized at ${KB_DIR}"
fi
