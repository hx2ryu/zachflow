---
name: zachflow-kb:promote-rubric
description: Append a Promotion Log row to the active Evaluator rubric. Use at Phase 6 Retro when a pattern with frequency >= 2 and a defined contract_clause should promote into next-version rubric. Adds the log row only; creating a new v(N+1) file is a separate manual follow-up.
---

# zachflow-kb:promote-rubric

Append a single row to the active rubric's **Promotion Log** table. Version-bump (v(N) → v(N+1)) is NOT handled by this skill — see Follow-up below.

## Inputs

- `source_sprint` — lowercase-hyphen sprint id (required).
- `source_pattern` — pattern id (required, e.g. `correctness-001`).
- `clause_id` — next clause identifier in sequence (required, e.g. `C10`). Caller picks the next free id by reading the active rubric's Clauses section.
- `clause_title` — short title for the log entry (required, ≤80 chars, e.g. `Retry Idempotency`).

## Preconditions

- `bash scripts/kb-bootstrap.sh` ran at least once.
- At least one active rubric exists at `${KB_PATH}/learning/rubrics/v{N}.md` with frontmatter `status: active`, `superseded_by: null`. (`kb-bootstrap.sh` seeds `v1.md` on first run.)

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Locate active rubric**
   Glob `${KB_PATH}/learning/rubrics/*.md`. Parse each frontmatter; pick the one with `status: active` AND `superseded_by: null`. Expect exactly one.
   - Zero matches: abort, `no active rubric found; bootstrap should have seeded v1.md`.
   - Multiple matches: abort, `multiple active rubrics found — KB needs cleanup`.

3. **Verify clause_id is free**
   Read the active rubric body. Confirm:
   - No existing heading in `## Clauses` section uses `clause_id` (e.g. `### C10. …`).
   - Promotion Log column "Clause Added" has no row starting with `clause_id`.
   On collision: abort with `clause_id {clause_id} already in use; pick a different id`.

4. **Append Promotion Log row**
   Edit the active rubric. Locate the Promotion Log table (matches header `| Date | Sprint | Clause Added | Source Pattern |`). Append one row immediately after the last non-placeholder row:

   ```
   | {YYYY-MM-DD} | {source_sprint} | {clause_id} {clause_title} | {source_pattern} |
   ```

   Use the current local date (`date +%Y-%m-%d`). Do NOT remove the existing baseline placeholder row (`| — | — | (baseline) | — |`); if it is the only row, keep it as the first row and append after it.

5. **Inline validate (post-edit)**
   Bash:
   ```
   python3 -c "
   content = open('${KB_PATH}/learning/rubrics/v{N}.md').read()
   assert content.startswith('---'), 'no frontmatter'
   assert '| Date | Sprint | Clause Added | Source Pattern |' in content
   print('OK')
   "
   ```

6. **Commit (no push)**
   ```
   if [ -d "${KB_PATH}/.git" ]; then
     cd "$KB_PATH"
     git add learning/rubrics/v{N}.md
     git commit -m "kb: rubric promote {clause_id} from {source_sprint}"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/rubrics/v{N}.md"
     git commit -m "kb: rubric promote {clause_id} from {source_sprint}"
   fi
   ```

7. **Nudge**
   Count Promotion Log rows (excluding the baseline placeholder). If count `>= 2`, emit a nudge to the caller:

   ```
   ⚠ Rubric v{N} Promotion Log now has {K} accumulated entries (threshold 2).
     Consider bumping to v{N+1} at the next Retro so the clauses get promoted
     into the main Clauses section. Version bump is currently a manual step —
     see follow-up below.
   ```

## Failure handling

- No active rubric → user must initialize one. `kb-bootstrap.sh` seeds `v1.md` on first run; if missing, re-run `bash scripts/kb-bootstrap.sh`.
- `clause_id` collision → caller picks a different id.
- Validate fails → edit produced malformed frontmatter or broke markdown structure; fix and re-run from step 4.

## Verification (smoke)

Invoke with a throwaway `clause_id` and a dummy sprint id. Verify:
- Promotion Log table of active rubric gains exactly one new row.
- `git log -1 --stat` shows a single-file change.

## Follow-up (not implemented by this skill)

**Version bump** (v{N} → v{N+1}): when the Promotion Log hits 2+ accumulated rows, a new rubric file should be created with:
- All existing v{N} clauses preserved,
- Full bodies of the promoted clauses added to the `## Clauses` section,
- A fresh empty Promotion Log,
- v{N} marked `status: superseded`, `superseded_by: N+1`.

This is currently a manual process because it requires the full clause body (markdown content) which is NOT stored by this skill — only the short title is logged. A future `zachflow-kb:bump-rubric` skill could accept a `clauses` array (each with body) and perform the migration; design is deferred until the promotion cadence justifies the tooling.
