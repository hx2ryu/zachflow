# okf

Local OKF-compatible product KB import/export for zachflow.

This plugin moves Markdown/YAML product bundles between external directories and `.zachflow/kb/products/`. It does not use Google Cloud Knowledge Catalog, BigQuery, Vertex AI, or network services.

## Install

```bash
bash scripts/install-plugins.sh okf
```

This symlinks `~/.claude/skills/okf` to `plugins/okf`. Restart Claude Code after installing.

## Skills

- `/okf:import` — validate a local OKF product bundle and copy it into `.zachflow/kb/products/<product>/`
- `/okf:export` — validate a product bundle from `.zachflow/kb/products/<product>/` and copy it to an external directory

## CLI Helpers

Import:

```bash
python3 plugins/okf/scripts/okf_bundle.py import \
  --source ./external-okf/billing \
  --product billing \
  --kb-path ./.zachflow/kb
```

Export:

```bash
python3 plugins/okf/scripts/okf_bundle.py export \
  --product billing \
  --destination ./out-okf \
  --kb-path ./.zachflow/kb
```

Both commands validate product Markdown frontmatter against `schemas/products/*.schema.json` before copying. Export validates both before and after copy.

## Tests

```bash
bash plugins/okf/tests/test_import_export.sh
```
