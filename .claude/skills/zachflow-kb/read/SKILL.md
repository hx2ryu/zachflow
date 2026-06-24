---
name: zachflow-kb:read
description: Query the KB by content type and filters. Returns file paths (caller reads content via Read tool). Use at Phase 2 Spec to load prior patterns/product context, Phase 4 Evaluator to load the latest rubric.
---

# zachflow-kb:read

## Inputs
- `type` — one of `pattern`, `rubric`, `reflection`, `product`, `feature`, `api`, `decision`, `policy`, `glossary`, `prd` (required).
- Filters (optional, AND semantics):
  - For `pattern`: `category` (enum: correctness, completeness, integration, edge_case, code_quality, design_proto, design_spec), `severity` (enum: critical, major, minor), `min_frequency` (integer).
  - For `rubric`: `status` (default `active`).
  - For `reflection`: `domain` (free string matching `^[a-z][a-z0-9-]*$`), `limit` (integer, default 3, most-recent first by `completed_at`).
  - For product docs (`product`, `feature`, `api`, `decision`, `policy`, `glossary`, `prd`): `product` (slug), `tag`, `status` (`active`, `draft`, `deprecated`, `superseded`), `limit` (integer).

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

2. **Run the read helper**

   Use the repository helper to apply filters and return paths only:

   ```bash
   python3 scripts/lib/kb-read.py type=<type> [filter=value ...]
   ```

   Examples:

   ```bash
   python3 scripts/lib/kb-read.py type=feature product=billing status=active limit=5
   python3 scripts/lib/kb-read.py type=api tag=invoices
   python3 scripts/lib/kb-read.py type=product product=billing
   ```

   The helper honors `KB_PATH`; if unset, it resolves `<git-root>/.zachflow/kb`.

3. **Directory/glob semantics**
   - `pattern` → `${KB_PATH}/learning/patterns/*.yaml`
   - `rubric`  → `${KB_PATH}/learning/rubrics/*.md`
   - `reflection` → `${KB_PATH}/learning/reflections/*.md`
   - `product` → `${KB_PATH}/products/<product>/index.md` (`type: product_index`)
   - `feature` → `${KB_PATH}/products/<product>/features/*.md`
   - `api` → `${KB_PATH}/products/<product>/apis/*.md`
   - `decision` → `${KB_PATH}/products/<product>/decisions/*.md`
   - `policy` → `${KB_PATH}/products/<product>/policies/*.md`
   - `glossary` → `${KB_PATH}/products/<product>/glossary/*.md`
   - `prd` → `${KB_PATH}/products/<product>/prds/*.md`

4. **List candidates** — glob the resolved pattern.

5. **Filter client-side**
   Read each candidate, parse YAML (`.yaml`) or frontmatter (`.md`). Apply filter predicate:
   - `pattern`: keep if `category`, `severity`, `frequency >= min_frequency` match.
   - `rubric`: keep if frontmatter `status` matches; sort descending by `version`; return top 1.
   - `reflection`: keep if `domain` matches; sort by `completed_at` desc; slice `limit`.
   - Product docs: keep if `type`, `product`, `tag`, and `status` match. Sort active docs first, then newest `updated_at`, then path. Slice `limit` if supplied.

6. **Return paths**
   Output a list of absolute file paths. The caller uses Read on each.

## Failure handling
- No matches → return empty list. Do not treat as error.
- Parse error on one file → log the specific file and skip it; continue.
- Unknown `type` → return an explicit `unsupported type` error.

## Verification (smoke)
- `type=pattern` (no filters) → returns all pattern paths under `${KB_PATH}/learning/patterns/`.
- `type=rubric` → returns the single active rubric path (or empty if KB freshly bootstrapped).
- `type=feature product=billing status=active` → returns active feature docs under `products/billing/features/`.
- `type=product product=billing` → returns `products/billing/index.md`.
- `bash tests/kb-read-product-test.sh`
