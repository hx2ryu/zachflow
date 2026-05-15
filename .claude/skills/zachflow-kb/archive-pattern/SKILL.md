---
name: zachflow-kb:archive-pattern
description: Move a pattern to archived state and relocate the file to `${KB_PATH}/learning/patterns/.archive/`. Use when a human reviewer judges a pattern obsolete before the curator's TTL fires. Refuses if the pattern is pinned. Wraps `scripts/lib/curator.py --target-state archived`.
---

# zachflow-kb:archive-pattern

Manually archive a single pattern. The yaml file is rewritten with `state: archived` and moved into `.archive/`, keeping it out of curator's auto-scan while preserving the audit trail. A hash-chained event is appended to `logs/curator.jsonl`.

For data-driven archival (use_count==0 + age > TTL) run `python3 scripts/lib/curator.py --kb-path "$KB_PATH" --apply` without `--pattern-id`.

## Inputs

- `pattern_id` — pattern id (required, e.g. `correctness-001`).

## Preconditions

- `bash scripts/kb-bootstrap.sh` has run at least once.
- The pattern file exists at `${KB_PATH}/learning/patterns/{pattern_id}.yaml` with `schema_version: 2`.
- `pinned` is **not** `true` on the pattern. Pinned patterns are refused — un-pin first via `zachflow-kb:promote-pattern --pinned false` if you really want to archive one.

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
   python3 scripts/lib/curator.py \
     --kb-path "$KB_PATH" --apply \
     --pattern-id "{pattern_id}" --target-state archived
   ```

3. **Verify hash chain**

   ```bash
   python3 scripts/lib/jsonl-verify.py "$PROJECT_ROOT/logs/curator.jsonl"
   ```

4. **Commit (no push)**

   ```bash
   git add ".zachflow/kb/learning/patterns/" "logs/curator.jsonl"
   git commit -m "kb: archive {pattern_id} (manual)"
   ```

   The `git add` covers both the deletion in `patterns/` and the addition in `patterns/.archive/`.

## Failure handling

- `pattern {id!r} is pinned; archive refused` → run `zachflow-kb:promote-pattern --pinned false` first if archival is intentional.
- `pattern {id!r} not found` → already archived (look in `.archive/`) or never existed.

## Verification (smoke)

- `[ ! -f .zachflow/kb/learning/patterns/{pattern_id}.yaml ]` (file gone from patterns/).
- `[ -f .zachflow/kb/learning/patterns/.archive/{pattern_id}.yaml ]` (file present in .archive/).
- Archived file's `state` field reads `archived`.
- `wc -l logs/curator.jsonl` grew by exactly 1.
