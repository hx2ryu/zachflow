# Changelog

## [Unreleased]

### Added
- Initial bootstrap from `zzem-orchestrator` (Sprint 0).
- Sprint workflow skills (`/sprint`).
- QA-Fix workflow skill (`/qa-fix` — currently invoked as `/sprint --type=qa-fix`; first-class entry point lands in Sprint 2).
- Embedded Knowledge Base scaffolding (`.zachflow/kb/`).
- Placeholder teammate templates.
- Sanitized templates and bash scripts.

### Notes
- v1.0 ships after Sprints 1–4.

## [0.3.0-sprint-2] — 2026-04-27

### Added
- `workflows/{sprint,qa-fix,_shared}/` directory split — workflows are now first-class, separated from `.claude/skills/` (which becomes a platform-compatibility shim via symlinks).
- `workflows/_shared/build-loop.md` — Build Loop primitive (Contract → Implement → Eval → Fix), referenced by `workflows/sprint/phase-build.md` and `workflows/qa-fix/{stage-3,stage-4}.md` instead of inline duplication.
- `workflows/_shared/agent-team.md` — agent role definitions + TaskCreate dispatch protocol.
- `workflows/_shared/worktree.md` — worktree isolation + branch naming.
- `workflows/_shared/kb-integration.md` — phase-by-phase KB invocation patterns (relocated from `.claude/skills/sprint/knowledge-base.md`).
- `workflows/qa-fix/` as 5 stage files + SKILL.md dispatcher (was 254-line monolith).
- `/qa-fix <run-id>` first-class slash command.
- `scripts/install-workflows.sh` — idempotent symlink installer for `.claude/skills/{sprint,qa-fix}`.
- `runs/{sprint,qa-fix}/` workflow-type subdirectories.
- `docs/workflow-authoring.md` — v1.0 guide for adding new workflows.

### Changed
- `runs/<id>/` paths in all phase/stage files updated to `runs/{sprint,qa-fix}/<id>/`.
- `phase-build.md` (was ~427 lines) shrunk to ~203 lines as Build Loop primitive moved to `_shared/`.
- `phase-qa-fix.md` (was 254 lines) split into 5 stage files + dispatcher SKILL.md.
- `.github/workflows/ci.yml` — added `install-workflows.sh` step before other smoke steps.
- `.claude/skills/sprint` and `.claude/skills/qa-fix` are now symlinks (mode 120000 in git) to `workflows/<name>/`.

### Deprecated
- `/sprint <id> --type=qa-fix` — emits deprecation warning, delegates to `/qa-fix <id>`. Will be removed in v2.0.

### Deferred to v1.x+
- Workflow yaml DSL (declarative workflow definitions) — v2.0 candidate.
- Plugin lifecycle hook system — v2.0 candidate.
- 3rd workflow (e.g., document-release, security-audit) — depends on N=3 abstraction validation.
- Windows native symlink compatibility (v1.0 = macOS/Linux + WSL).

## [0.2.0-sprint-1] — 2026-04-27

### Added
- KB embedded mode: 6 skills under `.claude/skills/zachflow-kb/` (read, write-pattern, update-pattern, write-reflection, promote-rubric, sync).
- Learning schemas (`schemas/learning/{pattern,rubric,reflection}.schema.json`) — draft 2020-12.
- `kb-bootstrap.sh` expanded to seed initial active rubric (`learning/rubrics/v1.md`).
- `tests/kb-smoke.sh` — CI smoke check for KB schemas + SKILL.md frontmatter.
- KB smoke step in `.github/workflows/ci.yml`.
- `docs/kb-system.md` expanded to v1.0 reference (modes, KB_PATH resolution, skills, schemas, validation, lifecycle).

### Changed
- `domain` enum in reflection schema relaxed from ZZEM-specific 4-value enum to free string matching `^[a-z][a-z0-9-]*$`. Per-project domain identifiers now allowed.

### Deferred to v1.1+
- KB remote mode wizard (`zachflow kb migrate --remote=<url>`).
- `products` axis (prd, events, active-prds).
- External integration plugins (Notion sync, etc.).
- Full Node validator port (filename-id matching, unique IDs, backwards-compat checks).
