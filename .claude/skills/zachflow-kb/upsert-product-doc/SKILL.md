---
name: zachflow-kb:upsert-product-doc
description: Create or update an OKF-compatible product KB Markdown doc by stable resource id. Use from Retro/product knowledge capture after facts are backed by sprint artifacts.
---

# zachflow-kb:upsert-product-doc

Create or update a product KB document under `.zachflow/kb/products/` using the sanctioned write path. This skill updates an existing document when another file already claims the same `resource`; it must not create duplicates.

## Inputs

Required:

- `type` — one of `feature`, `api`, `decision`, `policy`, `glossary`, `prd`
- `product` — product slug, for example `billing`
- `slug` — document slug, for example `csv-export`
- `title` — human-readable title
- `source_sprint` — sprint ID that produced or confirmed the fact
- `source_files` — comma-separated sprint artifact paths supporting the fact
- `summary` — Markdown-safe summary body

Optional:

- `status` — `draft | active | deprecated | superseded` (default `active`)
- `confidence` — `draft | inferred | confirmed` (default `inferred`)
- `tags` — comma-separated slug tags
- `related_resources` — comma-separated product resource IDs
- `superseded_by` — replacement product resource ID; required when `status=superseded`
- `updated_at` — ISO 8601 timestamp; defaults to current UTC
- `resource` — override stable resource ID. Prefer deriving it from `product`, `type`, and `slug`.

## Preconditions

- `bash scripts/kb-bootstrap.sh` was run at least once.
- Facts written from Retro must cite sprint artifacts in `source_files`.
- Use `zachflow-kb:read` first when matching candidates; if a matching `resource` exists, update it instead of creating another doc.

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

2. **Run the upsert helper**

   ```bash
   python3 scripts/lib/kb-product-upsert.py \
     type=feature \
     product=billing \
     slug=csv-export \
     title="Billing CSV export" \
     status=active \
     confidence=confirmed \
     tags=billing,export \
     source_sprint=sprint-042 \
     source_files=runs/sprint/sprint-042/PRD.md,runs/sprint/sprint-042/api-contract.yaml \
     summary="Users with finance access can export billing history as CSV."
   ```

   The helper validates frontmatter against `schemas/products/product-doc.schema.json` before writing. It prints the absolute path written.

3. **Review the diff**

   Confirm the write:

   - Kept `resource` stable and path-like.
   - Preserved or updated one document for the resource; no duplicate resource exists.
   - Included `source_sprint` and at least one `source_files` entry.
   - Used `confidence=inferred` unless the fact was human-confirmed or otherwise explicitly confirmed.

4. **Run validation**

   ```bash
   bash tests/kb-smoke.sh
   ```

## Failure Handling

- Schema validation failure → fix input metadata and retry.
- Duplicate resource found elsewhere → helper updates the existing file in place.
- `status=superseded` without `superseded_by` → helper rejects the write.
- Empty `source_files` → helper rejects the write.

## Verification

- `bash tests/kb-product-upsert-test.sh`
- `bash tests/kb-smoke.sh`
