# Phase 2: Spec (Sprint Lead as Planner)

Expand the PRD into a **deliverable-focused** specification.

For agent role definitions, see `workflows/_shared/agent-team.md` § Sprint Lead.
For KB sync/search/write protocol used here (`zachflow-kb:read`, etc.), see `workflows/_shared/kb-integration.md`.

## Planner Principles

- **What, not How**: Specify what each feature must achieve. The Generator decides the implementation.
- **Testable Criteria**: Every AC must be verifiable in code.
- **Avoid over-specification**: Pre-specifying implementation details cascades errors.

## Workflow

0. **KB sync**: Before the first KB access, call `zachflow-kb:sync` once (fast-forward pull). This ensures freshness for downstream `zachflow-kb:read` results. The SessionStart hook attempts ff-only at bootstrap, but to reflect mid-run upstream updates, call sync explicitly here.
0.5. **Cross-Sprint Memory load** (Reflexion-style):
   - `zachflow-kb:read type=reflection domain=<domain> limit=3` → load the 3 most recent reflections in the same domain.
   - Extract only each reflection's **Lesson** section and inject into the Spec context.
   - `zachflow-kb:read type=pattern min_frequency=2` → identify patterns relevant to the new PRD's domain (combining a category filter is recommended).
   - After analyzing the PRD, explicitly adopt or reject each lesson/pattern in the Spec (record a one-line rejection rationale).
1. **PRD analysis**: Extract User Stories + AC, capture business goals.
2. **Codebase pattern survey**:
   - Backend: `backend/apps/<example api>/src/`
   - App: `app/apps/<example app>/src/`
3. **API Contract**: produce `api-contract.yaml` (OpenAPI 3.0) — SSOT.
4. **Task decomposition**: `tasks/backend/*.md`, `tasks/app/*.md`
   - Required sections: Target, Context, Objective, Specification, Acceptance Criteria.
   - Implementation Hints should **only reference existing patterns**; no concrete implementation directives.
   - Numbering rule: same number = parallel, lower number = prerequisite.
5. **Evaluation Criteria**: produce `evaluation/criteria.md`.
   - Per-group evaluation criteria + Evaluator calibration guide.
6. **E2E Flow mapping** (when app tasks exist): produce `contracts/e2e-flow-plan.md`.
   - Existing flow inventory: check `app/apps/<example app>/e2e/flows/*.yaml`.
   - For each AC, assign one of four classifications:
     - **Covered**: an existing flow already satisfies the AC (cite the flow filename).
     - **Extend**: extend an existing flow with new steps (target flow + step summary).
     - **New**: a brand-new flow is required (proposed flow name + needed testIDs + seed-data status).
     - **Deferred**: out of e2e scope. State the reason explicitly — `BE-only` / `native-dialog` / `multi-device` / `time-warp` / `server-injection-required` / etc. State alternative verification means (BE unit/integration, manual QA).
   - A per-AC coverage table is required. `New`/`Extend` items must be reflected in the related app task's Specification as "E2E proof: write/extend `flows/{name}.yaml`".
   - Be aware of Maestro constraints: Fabric+RNGH may swallow taps → prefer **deeplink-first** navigation. New screens must declare a deeplink path (see e2e README).
   - **CTA verification compromise**: For CTAs where tap→result matters (e.g., a confirmation bottom-sheet button), e2e asserts `assertVisible` only; the tap-result behavior is delegated to Evaluator code tracing.
6.5. **E2E Seed Plan** (when seed data is needed for a new/extended flow on an app task): produce `contracts/e2e-seed-plan.md`.
   - List of needed seed fetchers: proposed `fetch-seed-{name}.mjs` filename + the BE endpoint it queries + the env variable name to inject.
   - Any required BE preparation work (test data seeding, state-mutation endpoints, etc.) must be **pre-reflected in the related backend task's Specification** so it is ready before the group starts.
7. **Self-validation**: OpenAPI validity, AC testability, no circular dependencies, (when app tasks exist) every AC mapped in e2e-flow-plan.

## File Reading Strategy

When surveying codebase patterns, read only what you need:
- Directory structure: list with `ls` or `Glob`.
- Existing patterns: read 1~2 representative files to understand the structure (do not full-scan).
- PRD: focus on AC sections (use `offset`/`limit`).

## Gate → Phase 3

Enter Phase 3 only when **all** are satisfied:
- [ ] `api-contract.yaml` exists + passes OpenAPI 3.0 validation.
- [ ] All task files contain the required sections (Target, Context, Objective, Specification, AC).
- [ ] No circular dependencies among task numbers.
- [ ] Every AC is testable (no fuzzy phrasing — "appropriate", "fast", etc.).
- [ ] Backend and App tasks reference the same endpoints in the API contract.
- [ ] (When app tasks exist) `contracts/e2e-flow-plan.md` exists, with every AC classified as Covered/Extend/New.

**Phase 3 skip condition**: If there are 0 app tasks, or no app task has a `### Screens / Components` section, skip Phase 3 and go directly to Phase 4.

## Checkpoint (at Phase 2 completion)

Create `checkpoints/phase-2-summary.md`:

```markdown
# Phase 2 Checkpoint: {sprint-id}

## Tasks
| ID | Type | Target | Group |
|----|------|--------|-------|
| {task-id} | backend/app | {one-line summary} | {group-N} |

## API Endpoints
| Method | Path | Related Tasks |
|--------|------|---------------|
| {method} | {path} | {task-ids} |

## Key Decisions
- {Major decision 1 made while interpreting the PRD}
- {Major decision 2 made while interpreting the PRD}

## Group Plan
- Group 001: {task-ids} — {feature summary}
- Group 002: {task-ids} — {feature summary}
```

> Subsequent phases reference this checkpoint + task files instead of re-reading the full PRD.

## Output

When the Gate passes:
1. Create the checkpoint file (`checkpoints/phase-2-summary.md`).
2. **Print Sprint Status** — emit the `--status` dashboard to show current progress.
3. Enter the next Phase.

```
Sprint Spec: {sprint-id}
  API Contract: {N} endpoints
  Tasks: Backend {N} + App {N}
  Evaluation Criteria: defined

[Sprint Status Dashboard]

→ Proceeding to Phase 3: Prototype
→ Proceeding to Phase 4: Build (no UI tasks — skipping prototype)
```
