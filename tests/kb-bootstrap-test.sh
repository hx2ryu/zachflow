#!/usr/bin/env bash
# kb-bootstrap-test.sh — verifies product KB bootstrap defaults and demo seed.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "kb-bootstrap test at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-kb-bootstrap-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

STAGE="$TMPDIR/stage"
mkdir -p "$STAGE"
(cd "$PROJECT_ROOT" && tar \
  --exclude='./.git' \
  --exclude='./.zachflow' \
  --exclude='./node_modules' \
  --exclude='./.claude/skills/sprint' \
  --exclude='./.claude/skills/qa-fix' \
  -cf - .) | (cd "$STAGE" && tar -xf -)

cd "$STAGE"

echo "  [1/3] Default bootstrap creates product root marker only"
bash scripts/kb-bootstrap.sh >/tmp/kb-bootstrap-default.out
[ -f .zachflow/kb/products/README.md ] || { echo "FAIL: product README marker missing"; exit 1; }
if find .zachflow/kb/products -mindepth 2 -name 'index.md' | grep -q .; then
  echo "FAIL: default bootstrap should not create a product bundle"
  exit 1
fi
echo "    OK (README marker present, no product bundle)"

echo "  [2/3] Default bootstrap is idempotent"
before=$(python3 -c "import hashlib; print(hashlib.sha256(open('.zachflow/kb/products/README.md','rb').read()).hexdigest())")
bash scripts/kb-bootstrap.sh >/tmp/kb-bootstrap-default-2.out
after=$(python3 -c "import hashlib; print(hashlib.sha256(open('.zachflow/kb/products/README.md','rb').read()).hexdigest())")
[ "$before" = "$after" ] || { echo "FAIL: README marker changed on second bootstrap"; exit 1; }
echo "    OK (second run leaves product marker unchanged)"

echo "  [3/3] Demo bootstrap creates schema-valid demo product docs"
bash scripts/kb-bootstrap.sh --demo >/tmp/kb-bootstrap-demo.out
[ -f .zachflow/kb/products/zachflow-demo/index.md ] || { echo "FAIL: demo product index missing"; exit 1; }
[ -f .zachflow/kb/products/zachflow-demo/features/greeting-function.md ] || { echo "FAIL: demo feature doc missing"; exit 1; }
bash tests/kb-smoke.sh >/tmp/kb-bootstrap-smoke.out
echo "    OK (demo bundle present and kb-smoke passes)"

echo
echo "PASS: kb-bootstrap tests"
