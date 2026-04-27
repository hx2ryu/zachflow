#!/usr/bin/env bash
set -euo pipefail

# zachflow KB bootstrap — Sprint 0 minimal version (embedded only)
# Sprint 1 will add remote-mode support (clone external git repo).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB_DIR="${PROJECT_ROOT}/.zachflow/kb"

mkdir -p "${KB_DIR}/learning/patterns"
mkdir -p "${KB_DIR}/learning/rubrics"
mkdir -p "${KB_DIR}/learning/reflections"
mkdir -p "${KB_DIR}/products"

if [ ! -f "${KB_DIR}/.initialized" ]; then
  touch "${KB_DIR}/.initialized"
  echo "zachflow KB initialized at ${KB_DIR} (embedded mode)"
else
  echo "zachflow KB already initialized at ${KB_DIR}"
fi
