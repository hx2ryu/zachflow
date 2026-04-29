# zachflow Architecture

## Design Principles

(Extracted into [`docs/design-principles.md`](docs/design-principles.md) for reference. Summary below.)

1. **Planner–Generator–Evaluator separation.** Generation and evaluation are different agents. Self-evaluation is unreliable.
2. **Sprint Contract first.** Generator and Evaluator agree on done criteria before any code is written.
3. **Feature-by-feature iteration.** Build groups are sized so the loop completes in 1–2 hours.
4. **Active Evaluation.** The Evaluator traces logic flow and probes edge cases — not static existence checks.
5. **Deliverable-focused spec.** Specs define *what*, not *how*. Implementation details are the Generator's choice.
6. **File-based handoff.** Agents communicate via structured artifacts on disk, not chat.
7. **Minimal harness.** Scaffolding is removed wherever the model can self-manage.
8. **Context checkpoint.** Every phase/group transition produces a structured summary file.
9. **Cross-session knowledge.** Patterns discovered in retrospect feed forward into future Sprint Contracts.

## Sprint Pipeline

```
Phase 1: Init       Sprint Lead initializes the run directory
Phase 2: Spec       Sprint Lead (Planner) decomposes PRD → tasks + API Contract
Phase 3: Prototype  Design Engineer generates HTML prototypes per screen
Phase 4: Build      Iterative Build Loop per feature group
Phase 5: PR         Sprint branch → base branch PR
Phase 6: Retro      Gap Analysis + Pattern Digest → KB writeback
```

## Build Loop (Phase 4)

```
For each group:
  4.1 Contract       Sprint Lead drafts → Evaluator reviews → consensus on done criteria
  4.2 Implement      BE/FE Engineers in parallel worktrees
  4.3 Merge          Sprint branch with --no-ff
  4.4 Evaluate       Evaluator: Active Evaluation
  4.5 Fix Loop       PASS → next group | ISSUES/FAIL → up to 2 fix iterations
```

## QA-Fix Workflow

A first-class workflow for processing Jira tickets in bulk after a sprint or in a standalone integration round. Five stages: Fetch+Triage → Grouping → Contract → Implement+Evaluate → Close. Reuses the Build Loop primitive for stages 3–4.

(Workflow directory split — `workflows/{sprint,qa-fix,_shared}/` — lands in Sprint 2. Sprint 0 keeps the current flat structure.)

## Knowledge Base

zachflow ships **embedded KB by default** — `.zachflow/kb/` is created in the project root, no external repo required. Patterns/rubrics/reflections are written here and read by skills (`zachflow-kb:read`, `zachflow-kb:write-pattern`, etc).

For team sharing, KB can be migrated to an external git repo via `zachflow kb migrate --remote=<url>` (v1.1+).

## Plugin System (Sprint 4a)

Plugins live under `plugins/<name>/` and provide optional, user-installable extensions to zachflow. Distinct from workflows:

- **Workflows** (sprint, qa-fix) are core — auto-installed via `scripts/install-workflows.sh`, project-bundled
- **Plugins** (recall, future: notion-sync, slack-notify) are optional — user-installed via `bash scripts/install-plugins.sh <name>`, system-wide via `~/.claude/skills/`

v1.0 ships `plugins/recall/` as the reference plugin (`recall:ask` skill — interactive sprint/KB recall). See [`docs/plugin-authoring.md`](docs/plugin-authoring.md) for the 10-step checklist to author a new plugin.

The plugin-core boundary is one-way: plugins MAY depend on core (workflows/_shared/, schemas/, KB), core MUST NOT depend on plugins.

## Gallery Package (Sprint 4b)

`packages/zachflow-gallery/` is an Astro-based shell that auto-indexes `runs/sprint/<run-id>/prototypes/**/*.html` from a zachflow project. Build-time discovery via Astro's `getStaticPaths` — no runtime indexing.

Live at `packages/*` monorepo workspace. Run via:

```bash
cd packages/zachflow-gallery
npm install
npm run dev      # Astro dev server
npm run build    # static site to dist/
```

Gallery is **shell only** — design system content (foundations, components, exemplars) stays in user projects. v1.0 ships an empty content layer; users layer their own design.

Optional GitHub Pages deployment via `.github/workflows/gallery.yml.example` (rename to enable). Other hosts (Vercel, Netlify, Cloudflare Pages) work via native Astro integrations.

## LLM Platform

v1.0 runs on Claude Code's Agent Teams. The bulk of zachflow (workflow markdown, templates, scripts) is platform-agnostic — porting to other agentic LLM CLIs is welcome. See [`docs/llm-platform-coupling.md`](docs/llm-platform-coupling.md).
