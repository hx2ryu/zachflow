---
name: okf:import
description: Validate and import a local OKF-compatible product bundle into .zachflow/kb/products/<product>. No cloud services are used.
---

# okf:import

Import a local OKF-compatible product bundle into zachflow's embedded product KB.

## Inputs

- `source` — local directory containing `index.md` and product doc subdirectories
- `product` — target product slug
- `kb_path` — optional KB path; defaults to `${KB_PATH:-./.zachflow/kb}`
- `force` — optional boolean; when true, replace an existing target bundle

## Steps

1. Confirm `source` is a local directory. Do not fetch remote URLs.
2. Run:

   ```bash
   python3 plugins/okf/scripts/okf_bundle.py import \
     --source <source> \
     --product <product> \
     --kb-path "${KB_PATH:-./.zachflow/kb}"
   ```

   Add `--force` only after the user confirms replacing the existing target bundle.

3. Run validation:

   ```bash
   bash tests/kb-smoke.sh
   ```

## Failure Handling

- Invalid frontmatter → fix the source bundle and retry.
- Target exists → rerun with `--force` only after explicit user confirmation.
- Missing `index.md` → reject; product bundles must include a root index.
