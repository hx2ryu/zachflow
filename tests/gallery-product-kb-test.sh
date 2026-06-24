#!/usr/bin/env bash
# gallery-product-kb-test.sh — verifies gallery renders product KB docs.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "gallery product KB test at: $PROJECT_ROOT"

if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
  echo "SKIP: node_modules missing; run npm install before gallery build verification"
  exit 0
fi

TMPDIR=$(mktemp -d -t zachflow-gallery-kb-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

STAGE="$TMPDIR/stage"
mkdir -p "$STAGE"
(cd "$PROJECT_ROOT" && tar \
  --exclude='./.git' \
  --exclude='./.zachflow' \
  --exclude='./node_modules' \
  --exclude='./packages/zachflow-gallery/dist' \
  --exclude='./packages/zachflow-gallery/public/prototypes' \
  -cf - .) | (cd "$STAGE" && tar -xf -)

ln -s "$PROJECT_ROOT/node_modules" "$STAGE/node_modules"

cd "$STAGE"
bash scripts/kb-bootstrap.sh --demo >/tmp/gallery-product-kb-bootstrap.out
npm run gallery:build >/tmp/gallery-product-kb-build.out

[ -f packages/zachflow-gallery/dist/index.html ] || { echo "FAIL: gallery index not built"; exit 1; }
[ -f packages/zachflow-gallery/dist/kb/zachflow-demo/index.html ] || { echo "FAIL: product index route not built"; exit 1; }
[ -f packages/zachflow-gallery/dist/kb/zachflow-demo/features/greeting-function/index.html ] || { echo "FAIL: feature doc route not built"; exit 1; }
grep -q "products/zachflow-demo/features/greeting-function" packages/zachflow-gallery/dist/kb/zachflow-demo/features/greeting-function/index.html || {
  echo "FAIL: feature resource id missing from rendered page"
  exit 1
}

echo "PASS: gallery product KB render"
