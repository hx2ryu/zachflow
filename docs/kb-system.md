# Knowledge Base

> Sprint 0 skeleton. Sprint 1 fills in the embedded mode mechanics.

## Modes

zachflow's KB supports two modes:

- **Embedded** (default) — `.zachflow/kb/` lives in your project repo. Zero external dependencies.
- **Remote** (opt-in, v1.1+) — KB content lives in a separate git repo, accessed via `zachflow kb migrate --remote=<url>`.

## Layout

```
.zachflow/kb/
├── learning/
│   ├── patterns/{category}-{NNN}.yaml
│   ├── rubrics/v{N}.md
│   └── reflections/{sprint-id}.md
└── products/
    └── (project-specific specs)
```

## Skills

- `zachflow-kb:read` — query patterns / rubrics / reflections / products with filters
- `zachflow-kb:write-pattern` — add a new pattern (auto-numbered)
- `zachflow-kb:update-pattern` — bump frequency / severity
- `zachflow-kb:write-reflection` — sprint retrospective
- `zachflow-kb:promote-rubric` — pattern → rubric clause

(Detailed schema and lifecycle in Sprint 1.)
