---
name: zachflow-kb:read
description: Query the KB by content type and filters. Returns file paths (caller reads content via Read tool). Use at Phase 2 Spec to load prior patterns/reflections, Phase 4 Evaluator to load the latest rubric.
---

# zachflow-kb:read

## Inputs
- `type` — one of `pattern`, `rubric`, `reflection` (required). The `prd` and `events` types are post-v1.0 (products axis); requesting them returns an explicit error.
- Filters (optional, AND semantics):
  - For `pattern`: `category` (enum: correctness, completeness, integration, edge_case, code_quality, design_proto, design_spec), `severity` (enum: critical, major, minor), `min_frequency` (integer).
  - For `rubric`: `status` (default `active`).
  - For `reflection`: `domain` (free string matching `^[a-z][a-z0-9-]*$`), `limit` (integer, default 3, most-recent first by `completed_at`).

## Preconditions
- `bash scripts/kb-bootstrap.sh` was run at least once for this project (creates `.zachflow/kb/`).

## Steps

1. **Resolve KB_PATH**

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     echo "Run 'bash scripts/kb-bootstrap.sh' first, or set KB_PATH env var." >&2
     exit 1
   fi
   ```

2. **Reject products-axis types**

   If `type` is `prd` or `events`, abort with: `Error: type=prd/events requires the products-axis plugin (post-v1.0). See docs/kb-system.md.`

3. **Resolve directory/glob**
   - `pattern` → `${KB_PATH}/learning/patterns/*.yaml`
   - `rubric`  → `${KB_PATH}/learning/rubrics/*.md`
   - `reflection` → `${KB_PATH}/learning/reflections/*.md`

4. **List candidates** — glob the resolved pattern.

5. **Filter client-side**
   Read each candidate, parse YAML (`.yaml`) or frontmatter (`.md`). Apply filter predicate:
   - `pattern`: keep if `category`, `severity`, `frequency >= min_frequency` match.
   - `rubric`: keep if frontmatter `status` matches; sort descending by `version`; return top 1.
   - `reflection`: keep if `domain` matches; sort by `completed_at` desc; slice `limit`.

6. **Return paths**
   Output a list of absolute file paths. The caller uses Read on each.

## Failure handling
- No matches → return empty list. Do not treat as error.
- Parse error on one file → log the specific file and skip it; continue.

## Verification (smoke)
- `type=pattern` (no filters) → returns all pattern paths under `${KB_PATH}/learning/patterns/`.
- `type=rubric` → returns the single active rubric path (or empty if KB freshly bootstrapped).
- `type=prd` → returns explicit "products-axis plugin required" error.
