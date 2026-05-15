---
name: zachflow-kb:list-stale
description: Read-only. Print the curator's pending decisions (promote/archive candidates) without changing anything. Use at Retro to see what the curator would do on its next `--apply` run. Wraps `scripts/lib/curator.py` in dry-run mode.
---

# zachflow-kb:list-stale

Surface patterns that the curator would transition on a real run — drafts with sufficient use_count, and stable patterns past the TTL with zero references. Nothing is written.

## Inputs

- `ttl_days` — optional integer, default `90`. Override the staleness window for this report.
- `archive_threshold` — optional integer, default `0`. Override the use_count ceiling for archive eligibility.

## Preconditions

- `bash scripts/kb-bootstrap.sh` has run at least once.

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Run curator dry-run**

   ```bash
   PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
   cd "$PROJECT_ROOT"
   python3 scripts/lib/curator.py \
     --kb-path "$KB_PATH" \
     --ttl-days "${ttl_days:-90}" \
     --archive-threshold "${archive_threshold:-0}"
   ```

   Each line printed is either `{id}: would {state} -> {state} (use_count=N)` for a planned transition, or `{id}: state=... use_count=N (no change)`.

3. **Summarize for the caller**
   Count `would draft -> stable` and `would stable -> archived` lines. Report them as two numbers, plus the actionable next step:

   ```
   Pending transitions (curator dry-run, ttl_days={ttl_days}):
     promote candidates : {promote_count}
     archive candidates : {archive_count}

   Apply with: python3 scripts/lib/curator.py --kb-path "$KB_PATH" --apply
   ```

## Failure handling

- `Error: $KB_PATH/learning/patterns not found` → run `bash scripts/kb-bootstrap.sh` to seed the KB.
- Any pattern with `schema_version: 1` will print `skip (not schema v2)`. Run `python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path "$KB_PATH"` to migrate.

## Verification (smoke)

- Re-running the skill twice in a row produces identical output (idempotent — dry-run never writes).
- After `--apply`, re-running this skill should report zero promote/archive candidates for the same patterns.
