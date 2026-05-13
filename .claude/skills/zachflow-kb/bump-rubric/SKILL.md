---
name: zachflow-kb:bump-rubric
description: Bump active Evaluator rubric v(N) → v(N+1) by consolidating accumulated Promotion Log entries into the new Clauses section. Auto-derives clause bodies from each source_pattern.contract_clause. Use at Phase 6 Retro when the promotion threshold is met (≥2 non-baseline rows), or with --force for explicit bumps.
---

# zachflow-kb:bump-rubric

Closes the loop that `zachflow-kb:promote-rubric` opens. Where `promote-rubric`
appends a Promotion Log row (lightweight bookkeeping), this skill consolidates
those rows into a versioned Clauses section and supersedes the prior rubric —
the operation that was previously a manual follow-up.

## Inputs (flags passed to the helper)

- `--kb-path PATH` (required) — path to `.zachflow/kb/`.
- `--force` — bump even if the Promotion Log has fewer than 2 non-baseline rows. Errors if the log is fully empty.
- `--changelog "..."` — custom changelog frontmatter for the new version. Default: `"v(N+1) — promoted K clause(s) from v(N) Promotion Log."`

## Preconditions

- Exactly one active rubric exists at `${KB_PATH}/learning/rubrics/v(N).md` with frontmatter `status: active` AND `superseded_by: null`.
- For every Promotion Log row, the corresponding pattern file exists at `${KB_PATH}/learning/patterns/{pattern-id}.yaml` and has a non-empty `contract_clause` field. Run `zachflow-kb:write-pattern` for any pattern referenced by the log but not yet captured.
- `v(N+1).md` does NOT already exist.

## Steps

1. **Resolve KB_PATH** (standard prologue):

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Invoke the helper**:

   ```bash
   PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
   python3 "$PROJECT_ROOT/scripts/lib/bump-rubric.py" --kb-path "$KB_PATH"
   ```

   The helper:
   - Locates the unique active rubric.
   - Parses non-baseline Promotion Log rows.
   - For each row, reads `source_pattern.contract_clause` from the pattern KB.
   - Writes `v(N+1).md` with: existing v(N) clauses preserved (when present) + each promoted clause as a `### {clause_id}. {title}` block carrying the verbatim `contract_clause` body plus a `> Promoted from ... in sprint ...` footer.
   - Re-writes `v(N).md` frontmatter to `status: superseded`, `superseded_by: N+1`.
   - Re-validates both files against `schemas/learning/rubric.schema.json`.

3. **Commit** (no push):

   ```bash
   if [ -d "$KB_PATH/.git" ]; then
     cd "$KB_PATH"
     git add learning/rubrics/
     git commit -m "kb: rubric bump v(N) → v(N+1)"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/rubrics/"
     git commit -m "kb: rubric bump v(N) → v(N+1)"
   fi
   ```

## Failure handling

| Situation | Cause / action |
|-----------|----------------|
| `no active rubric found` | `kb-bootstrap.sh` did not seed v1, or all rubrics are superseded. Re-bootstrap, or manually un-supersede the intended one. |
| `multiple active rubrics found` | A previous bump left both v(N) and v(N+1) active. Manually correct one frontmatter. |
| `vN+1.md already exists` | Earlier bump attempt left an artifact. Delete or rename it. |
| `pattern file missing: ...` | A Promotion Log row references a pattern not yet captured. Run `zachflow-kb:write-pattern` for it, or remove the stray row. |
| `pattern X has no contract_clause` | Source pattern is incomplete. Update the pattern with `zachflow-kb:update-pattern` (extending it to support body edits) or hand-edit. |
| `Nothing to promote (< 2 entries)` | Either accumulate more promotions, or pass `--force` if the early bump is intentional. |
| `--force given but Promotion Log is empty` | There is literally nothing to consolidate. Promote a row first via `zachflow-kb:promote-rubric`. |

## Verification (smoke)

`tests/bump-rubric-test.sh` covers four cases: happy path with 2 promoted rows, no-op on empty log, `--force` on empty log, and missing pattern reference. Runs in CI.

For ad-hoc verification: build a sandbox KB with 2 pattern files + a v(N).md whose Promotion Log references them, invoke the helper, and assert that v(N+1).md exists with both contract_clauses inlined verbatim.

## When NOT to bump

- Single-entry Promotion Log — wait for cadence. The threshold of 2 exists to avoid clause churn.
- Patterns whose `contract_clause` is still draft / placeholder — bumping freezes them into the canonical Clauses section.
- Active sprints depending on v(N) — bump *between* sprints, not during, so a sprint does not see its rubric change underneath it.

## Relationship to other KB skills

```
zachflow-kb:write-pattern   → captures detection/prevention/contract_clause
zachflow-kb:promote-rubric  → appends a Promotion Log row (lightweight)
zachflow-kb:bump-rubric     → consolidates accumulated rows into v(N+1) ← this skill
zachflow-kb:read            → consumers read the active rubric
```
