# Product Knowledge Base

Optional OKF-compatible product/domain memory lives under this directory.

Default bootstrap keeps this directory empty except for this marker. Product
bundles use this shape when a project opts in:

```text
products/<product-slug>/
├── index.md
├── features/
├── apis/
├── decisions/
├── policies/
└── glossary/
```

Run `bash tests/kb-smoke.sh` after adding product docs; Markdown frontmatter is
validated against `schemas/products/*.schema.json`.
