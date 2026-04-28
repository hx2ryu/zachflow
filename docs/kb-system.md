# Knowledge Base

zachflow's KB is the cross-session memory layer used by the Sprint workflow's evaluation and retrospective phases. It accumulates **patterns** (defect signatures), **rubrics** (Evaluator clauses), and **reflections** (per-sprint outcomes) — and feeds them forward into future Sprint Contracts.

## Modes

zachflow's KB supports two modes:

- **Embedded** (default) — `.zachflow/kb/` lives in your project repo. Zero external dependencies. Patterns/rubrics/reflections are tracked alongside your code, sharing the same git history.
- **Remote** (opt-in, v1.1+ roadmap) — KB content lives in a separate git repo, accessed via `${KB_PATH}` pointing to that clone. Useful for teams sharing learning across multiple projects.

## Layout

```
.zachflow/kb/
├── .initialized            # bootstrap marker
├── learning/
│   ├── patterns/{category}-{NNN}.yaml
│   ├── rubrics/v{N}.md     # active rubric is the latest with status: active
│   └── reflections/{sprint-id}.md
└── products/               # post-v1.0 (not used yet)
```

Schemas (zachflow core, not in user KB) live at `<git-root>/schemas/learning/`.

## KB_PATH resolution

All `zachflow-kb:*` skills resolve `KB_PATH` via this prologue:

```bash
KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
```

Rules:
- If env var `KB_PATH` is set, use it (allows remote mode + tests with custom paths).
- Otherwise, default to `<git-root>/.zachflow/kb` (embedded mode).
- If neither yields a valid directory, the skill exits with an explicit error pointing at `bash scripts/kb-bootstrap.sh`.

## Skills

| Skill | Purpose |
|-------|---------|
| `zachflow-kb:read` | Query patterns / rubrics / reflections by filters. Returns paths; caller reads content. |
| `zachflow-kb:write-pattern` | Create a new pattern YAML at `learning/patterns/{category}-{NNN}.yaml`. Auto-numbers within category. |
| `zachflow-kb:update-pattern` | Increment `frequency`, refresh `last_seen` on an existing pattern. |
| `zachflow-kb:write-reflection` | Record a sprint-end reflection (markdown + frontmatter) at `learning/reflections/{sprint_id}.md`. |
| `zachflow-kb:promote-rubric` | Append a Promotion Log row to the active rubric. Version-bump remains manual. |
| `zachflow-kb:sync` | Embedded mode: no-op. Remote mode (v1.1+): `git pull --ff-only` from KB remote. |

Each skill's `SKILL.md` (under `.claude/skills/zachflow-kb/<op>/SKILL.md`) is the authoritative protocol; agents invoke them via the Skill tool.

## Schemas reference

### Pattern (`schemas/learning/pattern.schema.json`)

Required fields: `id`, `title`, `category`, `severity`, `source_sprint`, `discovered_at`, `frequency`, `last_seen`, `description`, `detection`, `prevention`, `contract_clause`, `schema_version`.

Enums:
- `category`: `correctness | completeness | integration | edge_case | code_quality | design_proto | design_spec`
- `severity`: `critical | major | minor`

ID format: `{category}-{NNN}` (zero-padded 3 digits). Example: `correctness-001`, `design_proto-014`.

### Rubric (`schemas/learning/rubric.schema.json`)

Required frontmatter fields: `version` (int), `status` (`active | superseded`), `superseded_by` (int or null), `schema_version`. Body is markdown with `## Clauses` and `## Promotion Log` sections.

### Reflection (`schemas/learning/reflection.schema.json`)

Required frontmatter fields: `sprint_id`, `domain`, `completed_at`, `outcome` (`pass | fail | partial`), `schema_version`. Optional: `related_patterns` (array of pattern ids). Body is markdown narrative.

`domain` is a free string matching `^[a-z][a-z0-9-]*$` — use whatever identifier makes sense for your project (e.g., `auth`, `payments`, `mobile-app`).

## Validation

zachflow runs **two layers** of validation:

1. **Skill-inline** — each KB skill's protocol includes a `python3` snippet that parses the file post-write and verifies required keys + basic patterns. Catches malformed output before commit.

2. **CI smoke** (`tests/kb-smoke.sh`) — runs in CI on every push. Verifies:
   - All schema files in `schemas/learning/` are valid JSON Schema (draft 2020-12).
   - All KB SKILL.md files have correct YAML frontmatter and `name: zachflow-kb:*` prefix.

zachflow does NOT validate user KB content (`.zachflow/kb/`) in CI by default — that's user-space, embedded-mode philosophy. If you want stricter validation, you can extend `tests/kb-smoke.sh` to walk `.zachflow/kb/` (forward-compatible).

## Lifecycle integration with Sprint workflow

| Phase | KB skill | Purpose |
|-------|----------|---------|
| 2 (Spec) | `zachflow-kb:read type=pattern` | Load prior patterns to inform task decomposition. |
| 4.1 (Contract) | `zachflow-kb:read` | Auto-inject critical patterns' contract_clause into Done Criteria. |
| 4.4 (Evaluate) | `zachflow-kb:read type=rubric` | Load active rubric clauses for evaluation criteria. |
| 6 (Retro) | `zachflow-kb:write-pattern`, `update-pattern`, `write-reflection`, `promote-rubric` | Record new patterns, bump frequencies, log reflection, promote rubric clauses. |

## External integrations (plugins)

External integrations like Notion sync, Slack notifications, etc. are NOT part of zachflow core. They will live as optional plugins under `plugins/` (post-v1.0). Reference: the `zzem-orchestrator` ancestor used `zzem-kb:sync-prds-from-notion` and `zzem-kb:sync-active-prds`; these are NOT included in zachflow v1.0.

## Migration from `zzem-orchestrator` users

If you have existing `~/.zzem/kb/learning/` content from the legacy `zzem-orchestrator` system, you can copy individual pattern/reflection files into `<your-project>/.zachflow/kb/learning/` after running `bash scripts/kb-bootstrap.sh`. There is no automated migration tool in v1.0 — the file formats are compatible since zachflow's schemas are direct ports of the source.
