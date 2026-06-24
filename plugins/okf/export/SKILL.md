---
name: okf:export
description: Validate and export a zachflow product KB bundle to a local OKF-compatible directory. No cloud services are used.
---

# okf:export

Export a product bundle from `.zachflow/kb/products/<product>/` into a local OKF-compatible directory.

## Inputs

- `product` — product slug to export
- `destination` — local directory that will receive `<destination>/<product>/`
- `kb_path` — optional KB path; defaults to `${KB_PATH:-./.zachflow/kb}`
- `force` — optional boolean; when true, replace an existing destination bundle

## Steps

1. Confirm `destination` is a local path. Do not push to remote services.
2. Run:

   ```bash
   python3 plugins/okf/scripts/okf_bundle.py export \
     --product <product> \
     --destination <destination> \
     --kb-path "${KB_PATH:-./.zachflow/kb}"
   ```

   Add `--force` only after the user confirms replacing the destination bundle.

3. The helper validates the source before copy and the exported bundle after copy.

## Failure Handling

- Product bundle missing → run `zachflow-kb:read type=product product=<slug>` to verify the slug.
- Invalid product KB frontmatter → fix the KB docs and rerun `bash tests/kb-smoke.sh`.
- Destination exists → rerun with `--force` only after explicit user confirmation.
