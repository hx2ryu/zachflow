---
name: zachflow-kb:promote-pattern
description: Force a pattern's lifecycle state to `stable`. Use at Phase 6 Retro when a human reviewer wants to graduate a draft pattern into the active KB before the curator's automatic threshold (use_count ≥ 3) is met. Wraps `scripts/lib/curator.py --pattern-id <id> --target-state stable`.
---

# zachflow-kb:promote-pattern

Manually promote a single pattern to `state: stable`. Records a hash-chained event in `logs/curator.jsonl`. Use this when the curator's automated promotion would lag the human's judgement — for example, a single well-evidenced sprint group surfaces a pattern that obviously belongs in the active KB.

For data-driven promotion (use_count-based) run `python3 scripts/lib/curator.py --kb-path "$KB_PATH" --apply` without `--pattern-id`.

## Inputs

- `pattern_id` — pattern id (required, e.g. `correctness-001`).
- `pinned` — optional `"true"` or `"false"`. If supplied, the pinned flag is toggled in the same operation.

## Preconditions

- `bash scripts/kb-bootstrap.sh` has run at least once.
- The pattern file exists at `${KB_PATH}/learning/patterns/{pattern_id}.yaml` with `schema_version: 2`. (Run `scripts/lib/migrate-pattern-v1-to-v2.py` once if a project still has v1 patterns.)

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Invoke curator in manual mode**

   ```bash
   PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
   cd "$PROJECT_ROOT"
   ARGS=(--kb-path "$KB_PATH" --apply --pattern-id "{pattern_id}" --target-state stable)
   if [ -n "{pinned}" ]; then
     ARGS+=(--pinned "{pinned}")
   fi
   python3 scripts/lib/curator.py "${ARGS[@]}"
   ```

3. **Verify hash chain**

   ```bash
   python3 scripts/lib/jsonl-verify.py "$PROJECT_ROOT/logs/curator.jsonl"
   ```

4. **Commit (no push)**

   ```bash
   git add ".zachflow/kb/learning/patterns/{pattern_id}.yaml" "logs/curator.jsonl"
   git commit -m "kb: promote {pattern_id} -> stable (manual)"
   ```

## Failure handling

- `pattern {id!r} not found` → check the id and confirm the pattern was written via `zachflow-kb:write-pattern`.
- `pattern {id!r} is not schema v2` → run `python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$KB_PATH"` first.
- Already-stable patterns produce a `no change` line and exit 0 — safe to re-run.

## Verification (smoke)

After invoking:
- `python3 -c "import yaml; print(yaml.safe_load(open('.zachflow/kb/learning/patterns/{pattern_id}.yaml'))['state'])"` prints `stable`.
- `wc -l logs/curator.jsonl` grew by exactly 1 (unless the pattern was already stable).
