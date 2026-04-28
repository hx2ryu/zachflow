# Agent Team Primitive

> Shared by all workflows. Defines roles, responsibilities, and dispatch protocol. Phase/stage files reference this — never re-define agent roles inline.

This file describes **HOW the workflow caller dispatches each role**. The behavioral playbook for each role lives in `.claude/teammates/<role>.md` (what each agent does internally once dispatched).

## Roles

### Sprint Lead (Planner + Orchestrator)

The Sprint Lead is the workflow caller — the orchestrator that runs phase/stage files end-to-end.

Responsibilities:
- Phase routing and gate enforcement (block transitions when gate conditions are unmet).
- Spec drafting in Phase 2 (Planner role): deliverable-focused task list + API contract.
- Contract drafting per group in the Build Loop (`_shared/build-loop.md`).
- Task dispatch to BE/FE/Design Engineers and the Evaluator via TaskCreate.
- Merge authority: only the Sprint Lead pushes/merges branches; engineer agents never push directly.
- KB integration: sync, search, write — see `_shared/kb-integration.md`.
- Checkpoint discipline: persist phase/group summaries before transitions.

The Sprint Lead never self-evaluates code — the Evaluator is independent.

### BE Engineer (Generator)

Backend implementation Generator. Receives a task assignment from the Sprint Lead, works inside the assigned worktree on a task branch, commits, and reports completion.

Dispatched via:
```
TaskCreate:
  Subject: impl/backend/{task-id}
  Description: <FROZEN SNAPSHOT> + task file + API contract reference
  Owner: BE Engineer
```

The BE Engineer never merges or pushes — it reports completion and the Sprint Lead merges. Behavior detail: `.claude/teammates/be-engineer.md`.

### FE Engineer (Generator)

App / frontend implementation Generator. Receives a task assignment with the HTML prototype reference, works inside the app worktree on a task branch, commits, and reports completion.

Dispatched via:
```
TaskCreate:
  Subject: impl/app/{task-id}
  Description: <FROZEN SNAPSHOT> + task file + API contract + prototype path
  Owner: FE Engineer
```

The FE Engineer treats the HTML prototype as a **visual reference**, not as implementation code — it implements natively in the project's stack. Behavior detail: `.claude/teammates/fe-engineer.md`.

### Design Engineer (Generator)

Specialized Generator for prototyping (Phase 3 in the Sprint workflow, Stage 2 in QA-Fix). Three-step pipeline:

1. **Step A — Context Engine Assembly**: PRD + design system + orchestration rules → structured context.
2. **Step B — UX Decomposition**: assembled context → per-screen machine-readable Screen Spec.
3. **Step C — Prototype Generation**: Screen Spec → HTML prototype.

Dispatched via:
```
TaskCreate:
  Subject: proto/app/{task-id}/{ScreenName}
  Description: <FROZEN SNAPSHOT (DESIGN.md + foundations + components + KB)> + Screen Spec template path
  Owner: Design Engineer
```

The Design Engineer authors `tokens.css` and `context-engine.yaml` directly (these are NOT part of the snapshot). Behavior detail: `.claude/teammates/design-engineer.md`.

### Evaluator (Independent Reviewer)

Performs Active Evaluation after a feature group is merged. Read-only — never modifies code. Default skepticism: "assume the implementation has bugs, find them".

Dispatched via:
```
TaskCreate:
  Subject: eval/{project}/group-{N}
  Description: <Sprint Contract path + merged code path + evaluation criteria> + active rubric reference
  Owner: Evaluator
```

The Evaluator owns severity assignment and verdict (PASS / ISSUES / FAIL — see `_shared/build-loop.md` § Verdict Rules). Behavior detail: `.claude/teammates/evaluator.md`.

## Dispatch Protocol

### TaskCreate Pattern

The workflow caller dispatches a Teammate via the standard TaskCreate boilerplate:

```
TaskCreate(
  description: "<role>-<workflow>-<id>",
  prompt: |
    --- FROZEN SNAPSHOT ---
    {reference data inlined here — DESIGN.md excerpts, KB results,
     api-contract.yaml scope, etc. depending on role}
    --- END SNAPSHOT ---

    Task detail: see {task-id-or-path}
    {workflow-specific instructions}
)
```

The `description` field is short (used for tracking). The `prompt` field contains the full task assignment — including the Frozen Snapshot block, so the agent does not need to Read reference files separately.

### Subject Naming Convention

| Phase/Stage | Subject pattern | Owner |
|-------------|-----------------|-------|
| Prototype | `proto/app/{task-id}/{ScreenName}` | Design Engineer |
| Implementation | `impl/backend/{task-id}` | BE Engineer |
| Implementation | `impl/app/{task-id}` | FE Engineer |
| Evaluation | `eval/{project}/group-{N}` | Evaluator |
| Revision | `revise/{minor\|major}/app/{task-id}` | Design Engineer |
| Contract Review | `contract-review/group-{N}` | Evaluator |

### Frozen Snapshot Inclusion

When dispatching a Generator, the workflow caller inlines reference data into the TaskCreate Description as a `--- FROZEN SNAPSHOT ---` block, so the Generator does not need to Read the references again.

The full Frozen Snapshot Protocol — what each role's snapshot contains and the cost rationale — lives in `_shared/build-loop.md` § Frozen Snapshot Protocol. KB-specific snapshot patterns are in `_shared/kb-integration.md`.

## Read-only Constraint

The Evaluator MUST NOT modify code. If the Evaluator detects an issue requiring code change, it surfaces in the verdict report — the workflow caller (Sprint Lead) dispatches a Fix subagent (BE/FE Engineer) to apply the change. This separation enforces the Planner-Generator-Evaluator pattern: self-evaluation is unreliable.

## Cross-Task Communication

Agents communicate via files only — never via chat memory:

- `tasks/<role>/<id>.md` — task assignment.
- `contracts/group-<N>.md` — Sprint Contract output.
- `evaluations/group-<N>.md` — Evaluator verdict.
- `checkpoints/<phase>-summary.md` — phase/group transition state.
- `logs/*.jsonl` — structured activity log.

A Teammate dispatched in iteration N+1 has no memory of iteration N's chat — only the files left behind. This is intentional: it makes the loop deterministic and resumable (`--resume` mid-run).
