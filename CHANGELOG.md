# Changelog

## [Unreleased]

### Changed
- **Release pipeline now publishes `create-zachflow` to npm on tag push.** `packages/create-zachflow/package.json` drops `private: true` and gains `publishConfig.access: public` plus standard registry metadata (`repository`, `homepage`, `bugs`). `.github/workflows/release.yml` adds `actions/setup-node@v4` (registry auth via `NODE_AUTH_TOKEN` / `NPM_TOKEN` secret) and an `npm publish --access public` step that runs after the GitHub Release is created. From the next tag forward, external users can run `npx create-zachflow my-project` directly — no tarball URL indirection. Tarball asset upload is preserved as a backup.
- **`create-zachflow` now defaults its `--tag` to the package's own version.** Previously omitting `--tag` defaulted to `main`, which silently put first-time users on unreleased code. Now `create-zachflow@X.Y.Z` clones zachflow at `vX.Y.Z` by default — versions stay in lockstep. `--branch=main` still tracks main explicitly; `--tag=<other>` still pins to any tag; `ZACHFLOW_REF` env still overrides everything. This is what makes the `npx create-zachflow my-project` one-liner safe to publish without forcing users to know the latest tag.

### Added (pre-v1.0)
- Initial bootstrap from `zzem-orchestrator` (Sprint 0).
- Sprint workflow skills (`/sprint`).
- QA-Fix workflow skill (`/qa-fix` — currently invoked as `/sprint --type=qa-fix`; first-class entry point lands in Sprint 2).
- Embedded Knowledge Base scaffolding (`.zachflow/kb/`).
- Placeholder teammate templates.
- Sanitized templates and bash scripts.

### Notes
- v1.0 ships after Sprints 1–4.
- **NPM_TOKEN repo secret must be registered on `hx2ryu/zachflow` before the next tag is pushed**, otherwise the publish step will fail (Release + tarball still succeed). Set up via `gh secret set NPM_TOKEN --repo hx2ryu/zachflow` with an npm automation token scoped to `create-zachflow`.

## [1.1.1] — 2026-04-29

Patch release. First first-party example, plus polish on the wizard's teammate-fill behavior.

### Added
- **`examples/nextjs-supabase/`** — first first-party stack adapter. Single-role (`app`) Next.js + Supabase reference with filled `fe-engineer` teammate guide and an `sprint-config.example.yaml` to diff wizard output against. Replaces the previously-empty `examples/` directory. Demonstrates the minimum viable wizard config.

### Changed
- **`templates/teammates/{be,fe}-engineer.template.md` post-substitution hints converted to HTML comments.** The old `(Sprint 3 init wizard fills this. Until then...)` parentheticals appeared after the wizard already filled the placeholder, leaving stale prose in every generated guide. Comments now sit above each `{{...}}` and are invisible in markdown rendering, so wizard output reads cleanly while raw-template readers still see what each section expects.

### Fixed
- **`design-engineer` teammate placeholders are now substituted by the wizard.** `{{DESIGN_TOKENS_PATH}}`, `{{PRIMARY_FONT}}`, and `{{DEVICE_FRAME}}` previously survived into the wizard output as literal markers because the substitution code only handled the four shared keys. They now read three new optional `fill.*` fields (`design_tokens_path`, `primary_font`, `device_frame`) from `init.config.yaml`; the interactive wizard prompts for them when the role's teammate is `design-engineer`. Empty values still leave the marker in place (matches existing skip behavior). `templates/init.config.template.yaml` documents the new fields with a commented-out design role.

### Notes
- README quick-start and `packages/create-zachflow/README` now reference the v1.1.1 release tarball.
- v1.1.0-bootstrapped projects' configs remain forward-compatible.

## [1.1.0] — 2026-04-29

First minor release after v1.0. Two themes: wizard output reaches template parity, and CI verifies the tool on every supported platform.

### Changed
- **`scripts/init-project.sh` now emits a full `sprint-config.yaml`** matching `templates/sprint-config.template.yaml`. Previously only `project_name`/`workflows`/`branch_prefix`/`repositories`/`kb` were written; `type:`, `qa_fix:`, `defaults:`, `team:` (with auto-derived teammates + always-on evaluator), and `display:` are now also scaffolded. No script consumed those missing blocks before, but template/output divergence was a UX trap surfaced during v1.0.1 verification.
- Smoke test (`tests/init-project-smoke.sh`) extended to assert the new blocks.
- **CI smoke job runs on a `ubuntu-latest` / `macos-latest` / `windows-latest` matrix** (was ubuntu-only). Verified: bash 3.2 (macOS), bash 5.x (Linux + Windows git-bash), `ln -s` symlink creation under `MSYS=winsymlinks:nativestrict`, tar staging without rsync, PEP 668 PyYAML install on macOS. All smoke steps pass on each platform.

### Notes
- README quick-start and `packages/create-zachflow/README` now reference the v1.1.0 release tarball.
- Wizard's existing config is forward-compatible: a v1.0.x-bootstrapped project's `sprint-config.yaml` keeps working unchanged on v1.1.

## [1.0.1] — 2026-04-29

Post-release ops fixes discovered while verifying the v1.0.0 external bootstrap claim.

### Fixed
- **README quick-start no longer relies on an unpublished package.** v1.0.0 advertised `npx create-zachflow`, but the package is `private:true` and not on npm — external users could not install it. Quick-start now uses `npx <tarball-url>` against the release asset, which works without an npm publish.

### Added
- **Release workflow uploads `create-zachflow-<version>.tgz`** as a release asset (via `npm pack`). Enables the `npx <tarball-url>` bootstrap path.
- **`workflow_dispatch` on release.yml** with a `tag` input — manual re-run if a tag-push trigger is missed.

### Notes
- A direct `npx create-zachflow` (no URL) still requires npm publish (tracked in `docs/roadmap.md` as a v1.x item).
- Wizard-emitted `sprint-config.yaml` currently includes only `repositories:` and `kb:` blocks; `team:`, `qa_fix:`, `defaults:`, `display:` blocks from the template are not yet auto-scaffolded. No script consumes them today, but template/output divergence is a UX trap — slated for v1.1 review.

## [1.0.0] — 2026-04-29 🎉

**zachflow v1.0.0 — initial release.**

This is the first stable release of zachflow, a harness-driven sprint orchestration tool for AI coding agents on Claude Code Agent Teams. Built from `zzem-orchestrator` reference patterns, sanitized to be project-agnostic and OSS-portable.

### Highlights (v1.0)

- **Two first-class workflows**: `/sprint` (6-phase pipeline) and `/qa-fix` (5-stage Jira-driven pipeline)
- **Build Loop primitive** (Contract → Implement → Evaluate → Fix) shared across workflows
- **Embedded Knowledge Base** (`zachflow-kb:*` skills, 6 skills, JSON Schema validation) — no external repo required
- **Stack-agnostic teammate templates** — placeholder-based BE/FE/Design/Evaluator role guides
- **Interactive init wizard** (`scripts/init-project.sh`) — 7-step prompt-driven project setup, ~5 minutes
- **Plugin system** with `recall:ask` reference plugin (interactive sprint/KB recall, 15 unit tests)
- **Auto-indexed gallery** (`packages/zachflow-gallery/`) — Astro shell, GitHub Pages deployment template
- **`npx create-zachflow`** wrapper — clone-and-strip bootstrap, 0 deps
- **Worktree-isolated runs**, **Active Evaluation** (independent Evaluator agent), **Cross-session knowledge accumulation**
- **bash 3.2+ compatibility** verified (macOS default `/bin/bash`)
- **CI smoke tests**: KB schemas, init-project non-interactive smoke, plugin unit tests, ZZEM-leak scan

### Sprint Build History

v1.0 was built across 7 sprints (5 logical, 4 with sub-splits):

- `v0.1.0-bootstrap` — Sprint 0: directory structure + sanitized core
- `v0.2.0-sprint-1` — Sprint 1: KB embedded mode + skill rename
- `v0.3.0-sprint-2` — Sprint 2: workflow split (`workflows/{sprint,qa-fix,_shared}/`)
- `v0.4.0-sprint-3` — Sprint 3: stack adapter + init-project.sh wizard
- `v0.5.0-sprint-4a-plugins` — Sprint 4a: plugin pattern + recall plugin port
- `v0.6.0-sprint-4b-gallery` — Sprint 4b: zachflow-gallery package
- **`v1.0.0`** — Sprint 4c: create-zachflow + docs polish + release CI 🎉

### Roadmap

See [`docs/roadmap.md`](docs/roadmap.md) for v1.x and v2.0+ plans:

- v1.x: KB remote mode, multi-LLM platform support, additional plugins (Notion sync etc.), npm publish, qa-fix gallery rendering, theme toggle
- v2.0: Workflow yaml DSL, plugin lifecycle hooks, plugin sandboxing

## [0.6.0-sprint-4b-gallery] — 2026-04-27

### Added
- `packages/zachflow-gallery/` — Astro-based minimum viable gallery shell that auto-indexes `runs/sprint/<run-id>/prototypes/**/*.html`.
- Astro components: `Layout.astro` (dark theme with CSS variables), `PrototypeCard.astro` (iframe-based thumbnail).
- Astro pages: `index.astro` (auto-discovery home), `[run]/[prototype].astro` (dynamic detail route via `getStaticPaths`).
- `packages/zachflow-gallery/scripts/copy-prototypes.sh` — bash build-time HTML copier (no TypeScript dep).
- `.github/workflows/gallery.yml.example` — optional GitHub Pages deployment workflow (user opt-in via rename).
- Root `package.json` workspaces (`packages/*`) + scripts (`gallery:dev`, `gallery:build`, `gallery:preview`).

### Notes
- Gallery is **shell only** — no ZZEM-specific content (exemplars, foundations, design tokens, archetype taxonomy). Users layer their own design system.
- Build-time discovery via Astro's `getStaticPaths` — no runtime indexing.
- iframe sandbox is `allow-same-origin` — blocks JS in prototypes by default. Users can relax in components if needed.
- Gallery is **not** in the main CI workflow. Heavy npm install required; deferred to v1.x dedicated CI matrix.
- Single dependency: `astro@^4.16.0`. No React, no MDX, no Playwright (those join in v1.x as needed).

### Deferred to Sprint 4c / v1.x+

- `npx zachflow-gallery init` (scaffold gallery into existing project) — Sprint 4c
- `qa-fix` run rendering (`runs/qa-fix/<id>/` browsing) — v1.x
- Token validation, exemplar management, archetype taxonomy — v1.x
- Screenshot capture / visual baseline / dogfood verification — v1.x
- Search palette, theme toggle, mobile-optimized navigation — v1.x
- Tests (vitest + playwright) — v1.x

## [0.5.0-sprint-4a-plugins] — 2026-04-27

### Added
- `plugins/<name>/` directory pattern formalized as the optional, user-installable counterpart to `workflows/<name>/` (project-bundled).
- `plugins/recall/` — first reference plugin, ported from upstream `zzem-orchestrator` PR #57 (11 files: README + ask/SKILL.md + 4 scripts + 2 config files + 3 tests).
- `scripts/install-plugins.sh` — opt-in plugin installer (`bash scripts/install-plugins.sh <name>`). Symlinks `~/.claude/skills/<name> → plugins/<name>` (user-level).
- `docs/plugin-authoring.md` — v1.0 plugin authoring guide with 10-step checklist + recall as worked example.
- CI integration: `install-plugins.sh syntax check` + `recall plugin unit tests` (15 tests) added to `.github/workflows/ci.yml`.

### Changed
- `recall.example.yaml` schema: `sources.sprints` → `sources.runs.{path, workflows: [sprint, qa-fix]}` (zachflow's Sprint 2 directory structure).
- `recall.example.yaml` KB: `~/.zzem/kb` (hardcoded) → `${KB_PATH:-./.zachflow/kb}` (env-var with embedded KB default).
- `recall.example.yaml` domain enum: removed hardcoded ZZEM enum; recall now accepts any project-specific domain matching `^[a-z][a-z0-9-]*$`.
- `recall.schema.json` `$id`: `https://zach-wrtn.github.io/...` → `https://zachflow.dev/...`.
- `ask/SKILL.md` path discovery: scans `runs/{sprint,qa-fix}/<id>/` instead of `./sprint-orchestrator/sprints/`.
- `docs/roadmap.md` Sprint 4 entry split into 4a (this sprint, complete) / 4b (gallery) / 4c (create-zachflow + v1.0 release).

### Notes
- Plugin install is **explicit** (user runs `bash scripts/install-plugins.sh recall`) — distinct from workflows which install automatically via `scripts/install-workflows.sh`.
- Plugin namespace: skills inside a plugin use `<plugin>:<skill>` frontmatter (e.g., `recall:ask`). Avoids collision with core skill names.
- Core does NOT depend on plugins. zachflow workflows + KB work without any plugin installed.

### Deferred to Sprint 4b/4c

- `zachflow-gallery` package — Sprint 4b
- `create-zachflow` npm wrapper — Sprint 4c
- README/CONTRIBUTING/v1.0 release polish — Sprint 4c
- v1.0.0 final tag — Sprint 4c

## [0.4.0-sprint-3] — 2026-04-27

### Added
- `scripts/init-project.sh` — interactive (default) and non-interactive (`--from=init.config.yaml --non-interactive`) project bootstrap wizard. 7-step flow (project name, workflows, branch prefix, roles, teammate fills, KB mode, init KB).
- `templates/teammates/{be,fe,design,evaluator}-engineer.template.md` — canonical placeholder templates the wizard reads from.
- `templates/init.config.template.yaml` — annotated example for non-interactive mode.
- `tests/init-project-smoke.sh` — CI smoke test for non-interactive wizard (fixture-based).
- CI integration: `init-project.sh syntax check` + `init-project.sh non-interactive smoke` steps in `.github/workflows/ci.yml`.

### Changed
- `examples/README.md` — added wizard quick-start + non-interactive setup instructions.
- `MANUAL.md` — Setup section expanded from Sprint 0 stub to full wizard usage docs (interactive + non-interactive + re-run + skip behavior).

### Notes
- `.claude/teammates/*.md` Sprint 0 placeholders remain as clone-and-go defaults. Wizard fills overwrite them (with confirm gate + `--force` flag for CI).
- Wizard inserts an HTML comment marker (`<!-- zachflow init-project.sh wizard fill — <ISO 8601> -->`) at the top of filled teammate files for re-run detection.
- Bash 3.2 compatible (no associative arrays — uses indexed array + dedup-by-string for teammate template iteration).
- JSON fill data is base64-encoded for safe transport through bash variables.

### Deferred to v1.x+
- KB remote mode wizard.
- Stack adapter examples catalog (external PRs).
- Multi-stack mixing in single wizard run.
- Template inheritance.

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
