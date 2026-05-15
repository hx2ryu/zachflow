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
| `zachflow-kb:promote-rubric` | Append a Promotion Log row to the active rubric. Lightweight bookkeeping. |
| `zachflow-kb:bump-rubric` | Bump v(N) → v(N+1): consolidate Promotion Log into Clauses, supersede the prior version. |
| `zachflow-kb:promote-pattern` | Force a pattern's lifecycle state to `stable` (manual override of the curator's use_count threshold). |
| `zachflow-kb:archive-pattern` | Move a pattern to `state: archived` and relocate the file to `patterns/.archive/`. Refuses pinned patterns. |
| `zachflow-kb:list-stale` | Read-only dry-run of the pattern curator — print promote/archive candidates without changing anything. |
| `zachflow-kb:sync` | Embedded mode: no-op. Remote mode (v1.1+): `git pull --ff-only` from KB remote. |

Each skill's `SKILL.md` (under `.claude/skills/zachflow-kb/<op>/SKILL.md`) is the authoritative protocol; agents invoke them via the Skill tool.

## Schemas reference

### Pattern (`schemas/learning/pattern.schema.json`, schema v2)

Required fields: `id`, `title`, `category`, `severity`, `source_sprint`, `discovered_at`, `frequency`, `last_seen`, `description`, `detection`, `prevention`, `contract_clause`, `schema_version`.

Optional lifecycle fields (v2): `state` (`draft | stable | archived`), `pinned` (bool), `created_by` (`human | agent`), `use_count` (int ≥ 0), `last_referenced_at` (ISO 8601 or null). These are managed by `scripts/lib/curator.py` and exposed via the three lifecycle skills above; pattern authors do not set them by hand.

Enums:
- `category`: `correctness | completeness | integration | edge_case | code_quality | design_proto | design_spec`
- `severity`: `critical | major | minor`

ID format: `{category}-{NNN}` (zero-padded 3 digits). Example: `correctness-001`, `design_proto-014`.

Projects with pre-v2 patterns (`schema_version: 1`) should run `python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path .zachflow/kb` once; the migration is idempotent and seeds existing patterns with `state: stable`.

### Rubric (`schemas/learning/rubric.schema.json`)

Required frontmatter fields: `version` (int), `status` (`active | superseded`), `superseded_by` (int or null), `schema_version`. Body is markdown with `## Clauses` and `## Promotion Log` sections.

### Reflection (`schemas/learning/reflection.schema.json`)

Required frontmatter fields: `sprint_id`, `domain`, `completed_at`, `outcome` (`pass | fail | partial`), `schema_version`. Optional: `related_patterns` (array of pattern ids). Body is markdown narrative.

`domain` is a free string matching `^[a-z][a-z0-9-]*$` — use whatever identifier makes sense for your project (e.g., `auth`, `payments`, `mobile-app`).

## Validation

zachflow runs **two layers** of validation:

1. **Skill-inline** — each KB skill's protocol includes a `python3` snippet that parses the file post-write and verifies required keys + basic patterns. Catches malformed output before commit.

2. **CI smoke** (`tests/kb-smoke.sh`) — runs in CI on every push. Six steps:
   - Steps 1–3 (always): schemas in `schemas/learning/` are valid JSON, declare draft 2020-12, KB SKILL.md frontmatter is correct.
   - Steps 4–6 (when `.zachflow/kb/` is present): user KB content under `learning/{patterns,rubrics,reflections}/` is validated against the corresponding schema via `jsonschema`. Empty subdirs and absent KB directories are skipped — only present files are checked.

Per zachflow's embedded-mode philosophy, user KB is local to your project — but a broken KB file silently breaks Sprint Contracts and the Evaluator's rubric injection, so the CI catch is worth the cost.

## Lifecycle integration with Sprint workflow

| Phase | KB skill | Purpose |
|-------|----------|---------|
| 2 (Spec) | `zachflow-kb:read type=pattern` | Load prior patterns to inform task decomposition. |
| 4.1 (Contract) | `zachflow-kb:read` | Auto-inject critical patterns' contract_clause into Done Criteria. |
| 4.4 (Evaluate) | `zachflow-kb:read type=rubric` | Load active rubric clauses for evaluation criteria. |
| 6 (Retro) | `zachflow-kb:write-pattern`, `update-pattern`, `write-reflection`, `promote-rubric`, `bump-rubric`, `list-stale` | Record new patterns, bump frequencies, log reflection, promote rubric clauses, and (when the Promotion Log threshold is met) bump the rubric version. End of Retro is also when `list-stale` is reviewed to plan curator runs. |

## Pattern Lifecycle (curator)

Patterns progress through three states managed by `scripts/lib/curator.py`:

```
   write-pattern         use_count ≥ 3         use_count==0 & age>TTL
    (Retro)         ─────────────────►    ─────────────────────────►
   ┌──────┐                              ┌────────┐                ┌──────────┐
   │ draft │                              │ stable │                │ archived │
   └──────┘                              └────────┘                └──────────┘
                                              ▲                          │
                                              │  pinned: true bypasses   │
                                              └──── all transitions ─────┘
                                          (manual promote/archive via skill)
```

**Source of truth.** State lives in the pattern's own yaml frontmatter (`state`, `pinned`, `use_count`, `last_referenced_at`), not a sidecar file. This preserves design-principle §6 (file-based handoff) — one `git log` traces the full lifecycle of a pattern.

**Reference counting.** `use_count` is recomputed by scanning `logs/**/*.jsonl` and `runs/**/*.jsonl` for records with a structured `pattern_id` (string) or `pattern_ids` (list) field. Free-text mentions in record bodies are deliberately ignored — they would inflate counts every time an agent named a pattern in prose. Agents that want to credit a reference must emit a structured field.

**Audit trail.** Every state transition appends a hash-chained record to `logs/curator.jsonl` (`event: pattern.state_changed`, `from_state`, `to_state`, `use_count`, `reason`). `python3 scripts/lib/jsonl-verify.py logs/curator.jsonl` validates the chain. The file is kb-scoped (not sprint-bounded) — see `docs/logs-hash-chain.md`.

**When to run.** The curator is not invoked automatically by any phase. Recommended cadence:
- **Every Retro (Phase 6)** — run `zachflow-kb:list-stale` to inspect pending transitions.
- **End of sprint** — `python3 scripts/lib/curator.py --kb-path .zachflow/kb --apply` to materialize them.
- **Ad-hoc** — `zachflow-kb:promote-pattern` / `archive-pattern` for human overrides between sprints.

**Defaults.** `--ttl-days 90`, `--archive-threshold 0`. Tune per project via the skill input or direct CLI invocation.

## External integrations (plugins)

External integrations like Notion sync, Slack notifications, etc. are NOT part of zachflow core. They will live as optional plugins under `plugins/` (post-v1.0). Reference: the `zzem-orchestrator` ancestor used `zzem-kb:sync-prds-from-notion` and `zzem-kb:sync-active-prds`; these are NOT included in zachflow v1.0.

## Migration from `zzem-orchestrator` users

If you have existing `~/.zzem/kb/learning/` content from the legacy `zzem-orchestrator` system, you can copy individual pattern/reflection files into `<your-project>/.zachflow/kb/learning/` after running `bash scripts/kb-bootstrap.sh`. There is no automated migration tool in v1.0 — the file formats are compatible since zachflow's schemas are direct ports of the source.
