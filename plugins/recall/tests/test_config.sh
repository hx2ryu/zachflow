#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

source scripts/load-config.sh

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

# Test 1: $RECALL_CONFIG explicit wins
echo "sources: {sprints: {path: /env/sprints}}" > "$TEST_TMPDIR/explicit.yaml"
echo "sources: {sprints: {path: /cwd/sprints}}" > "$TEST_TMPDIR/.recall.yaml"
out=$(cd "$TEST_TMPDIR" && RECALL_CONFIG="$TEST_TMPDIR/explicit.yaml" HOME="$TEST_TMPDIR/home" load_config_path)
[[ "$out" == "$TEST_TMPDIR/explicit.yaml" ]] || fail "explicit RECALL_CONFIG should win, got: $out"
pass "explicit RECALL_CONFIG wins"

# Test 2: CWD .recall.yaml wins over home
mkdir -p "$TEST_TMPDIR/home"
echo "sources: {sprints: {path: /home/sprints}}" > "$TEST_TMPDIR/home/.recall.yaml"
unset RECALL_CONFIG
out=$(cd "$TEST_TMPDIR" && HOME="$TEST_TMPDIR/home" load_config_path)
[[ "$out" == "$TEST_TMPDIR/.recall.yaml" ]] || fail "CWD should win over home, got: $out"
pass "CWD .recall.yaml wins over home"

# Test 3: home fallback when no CWD
rm "$TEST_TMPDIR/.recall.yaml"
out=$(cd "$TEST_TMPDIR" && HOME="$TEST_TMPDIR/home" load_config_path)
[[ "$out" == "$TEST_TMPDIR/home/.recall.yaml" ]] || fail "home should be fallback, got: $out"
pass "home .recall.yaml is fallback"

# Test 4: empty when nothing found (caller falls back to defaults)
rm "$TEST_TMPDIR/home/.recall.yaml"
out=$(cd "$TEST_TMPDIR" && HOME="$TEST_TMPDIR/home" load_config_path)
[[ -z "$out" ]] || fail "should return empty when no config found, got: $out"
pass "empty when no config found"

echo "All config tests passed"
