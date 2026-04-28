---
name: sprint
description: Harness-driven sprint orchestration with Planner-Generator-Evaluator pattern. Use when the user wants to run a sprint pipeline, or says /sprint.
---

# Sprint — Harness-Driven Orchestration

## Design Principles

> Ref: "Harness Design for Long-Running Agentic Applications" (Anthropic Engineering)

1. **Planner-Generator-Evaluator Separation**: Decouple generation from evaluation. Self-evaluation is unreliable.
2. **Sprint Contract**: Generator and Evaluator agree on "done" criteria before implementation.
3. **Feature-by-Feature Iteration**: Iterate in feature-group units.
4. **Active Evaluation**: Trace code logic and probe edge cases — not static checks.
5. **Deliverable-Focused Spec**: Specify outcomes, not implementation details. Pre-specifying implementation invites cascading errors.
6. **File-Based Handoff**: Pass state between agents through structured file artifacts.
7. **Minimal Harness**: Remove scaffolding for anything the model can handle on its own.
8. **Context Checkpoint**: At Phase/Group transitions, persist a structured summary to a file. Do not rely on automatic compaction.
9. **Objective Verification via E2E**: Reinforce the Evaluator's subjective active evaluation with objective AC proofs from end-to-end runs. Phase 2 maps AC↔flow, Phase 4 has a per-group smoke gate, and Phase 5 has a full-suite regression gate.

## Goal

As Sprint Lead, orchestrate the sprint with a Planner-Generator-Evaluator pattern.
- **Planner**: Sprint Lead generates the deliverable-focused spec in Phase 2.
- **Generator**: BE/FE Engineers implement the features.
- **Evaluator**: An independent Evaluator runs active evaluation.

## Invocation

```
/sprint <sprint-id>                              # Full pipeline (Phase 1~6)
/sprint <sprint-id> --phase=init                 # Phase 1
/sprint <sprint-id> --phase=spec                 # Phase 2
/sprint <sprint-id> --phase=prototype            # Phase 3
/sprint <sprint-id> --phase=build                # Phase 4
/sprint <sprint-id> --phase=build --resume       # Resume Phase 4 mid-run
/sprint <sprint-id> --phase=pr                   # Phase 5
/sprint <sprint-id> --phase=pr --allow-partial   # PR excluding FAILED groups
/sprint <sprint-id> --phase=retro                # Phase 6 (Retrospective)
/sprint <sprint-id> --phase=qa-fix --jql="..."   # Phase QA-Fix on existing sprint (per-sprint path)
/sprint <sprint-id> --phase=qa-fix --dry-run     # QA-Fix dry-run (no Jira writes)
/sprint <new-id> --type=qa-fix --jql="..."       # New integration QA-Fix sprint (Path B)
/sprint <sprint-id> --continue                   # Continue unfulfilled items inside the same sprint
/sprint <sprint-id> --follow-up=<prev-sprint-id> # New follow-up sprint based on a previous one
/sprint <sprint-id> --status                     # Status dashboard
/sprint                                          # Auto-detect the most recent sprint
```

## Legacy `/sprint --type=qa-fix` (deprecated)

Calling `/sprint <id> --type=qa-fix --jql=...` is supported as a transitional alias but emits a deprecation warning:

```
⚠ /sprint --type=qa-fix is deprecated; use /qa-fix <id> directly. Will be removed in v2.0.
```

The Sprint Lead detects `--type=qa-fix` in the invocation args, prints the warning, then delegates to the `qa-fix` workflow (see `workflows/qa-fix/SKILL.md`). All other `--type=qa-fix` semantics are preserved during the deprecation window.

## Prerequisites

- Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Teammate definitions under `.claude/teammates/` (be-engineer, fe-engineer, design-engineer, evaluator)
- HTML prototype template (for the Design Engineer)
- For `--follow-up`: the previous sprint's `retrospective/` directory must exist

---

## Context Window Management

> Required protocol for preserving context quality across long-running sprints.

### Checkpoint System

At every Phase/Group completion, save a structured summary under `checkpoints/`. Subsequent phases reference the **checkpoint instead of the original artifacts**.

```
runs/sprint/{sprint-id}/checkpoints/
├── phase-2-summary.md      # Spec result: task list, endpoint list, key decisions
├── phase-3-summary.md      # Prototype result: approval status, revision summary, amendments
├── group-001-summary.md    # Build result: verdict, issues, lessons
├── group-002-summary.md
└── group-003-summary.md
```

**Rules**:
1. **At a Phase transition**: create that phase's checkpoint, then proceed to the next phase.
2. **At a Group transition**: create that group's checkpoint, then proceed to the next group.
3. **Reference priority**: checkpoint → task file → original (only when needed).
4. **Exception**: When the fix loop must reproduce a prior issue exactly, reading the original evaluation report is allowed.

### Progressive File Reading

Read only the parts of files you need:
- **api-contract.yaml**: only endpoints relevant to the current group (use `offset`/`limit`).
- **Task files**: focus on the AC section.
- **Evaluation reports**: only the verdict + issue list sections.
- **Prior group info**: refer only to `checkpoints/group-{N}-summary.md`.

### Budget Pressure Injection

> Ref: Hermes Agent IterationBudget — dynamic steering before context exhaustion.

To preserve context window quality across long Build Loops, the Sprint Lead monitors each group's progress and adjusts behavior based on a pressure level.

**Pressure level rules**:

| Level | Trigger | Sprint Lead behavior |
|-------|---------|----------------------|
| 🟢 Normal | Zero fix loops in the current group | Proceed normally |
| 🟡 Caution | Entering fix loop iteration 1, OR an Engineer task has been reassigned 2+ times | Create a checkpoint immediately + drop detailed context for prior groups |
| 🔴 Urgent | Fix loop iteration 2, OR 5+ total issues in the group | Propose scope reduction + prepare to request user intervention |

**How pressure is injected**:

When the Sprint Lead assigns a task to an Engineer/Evaluator, append a context hint to the task Description based on the current pressure level:

- 🟡 Caution: `⚠ Context Pressure: Caution — focus on core AC. No incidental improvements.`
- 🔴 Urgent: `🔴 Context Pressure: Urgent — implement the minimum only. Scope reduction may be in play.`

These hints directly affect Engineer/Evaluator behavior:
- Engineer: Caution forbids unnecessary refactoring/extra features. Urgent restricts to the minimum AC-meeting implementation.
- Evaluator: Caution skips minor issue reports. Urgent reports only Critical issues.

### Frozen Snapshot Protocol

See `workflows/_shared/build-loop.md` § Frozen Snapshot Protocol and `workflows/_shared/agent-team.md` § Frozen Snapshot Inclusion.

---

## Phase Routing

**Determine the current Phase, then Read the corresponding phase file to execute the detailed workflow.**

| Phase | File | Trigger |
|-------|------|---------|
| Phase 1: Init | `phase-init.md` | `--phase=init` or sprint directory missing |
| Phase 2: Spec | `phase-spec.md` | `--phase=spec` or Phase 1 Gate passed (type=standard only) |
| Phase 3: Prototype | `phase-prototype.md` | `--phase=prototype` or Phase 2 Gate passed |
| Phase 4: Build | `phase-build.md` | `--phase=build` or Phase 3 Gate passed |
| Phase 5: PR | `phase-pr.md` | `--phase=pr` or Phase 4 Gate passed |
| Phase 6: Retro | `phase-retro.md` | `--phase=retro` or Phase 5 complete |
| Phase QA-Fix | (delegated to `workflows/qa-fix/SKILL.md`) | `--phase=qa-fix` (per-sprint), or `--type=qa-fix` (deprecated alias — see "Legacy `/sprint --type=qa-fix`" above) |
| Modes | `phase-modes.md` | `--continue`, `--follow-up`, `--status` |

**How to execute**: Determine the current phase, then **Read the corresponding file from this workflow directory** and follow the detailed workflow.

```
Phase file path: workflows/sprint/{phase-file}
```

> **Important**: Do not Read phase files unrelated to the current phase. This is an intentional design for context window efficiency.

### Phase Determination Logic

1. `--phase=X` specified → go directly to that phase
2. `--type=qa-fix` specified (new sprint) → Phase 1 Init (qa-fix branch) → Phase QA-Fix
3. `--continue` → Read `phase-modes.md`
4. `--follow-up` → Read `phase-modes.md`
5. `--status` → Read `phase-modes.md`
6. No arguments → infer from sprint directory state:
   - Directory missing → Phase 1
   - `sprint-config.yaml` has `type: qa-fix` → Phase QA-Fix
   - `api-contract.yaml` missing → Phase 2
   - `approval-status.yaml` missing AND app tasks exist → Phase 3
   - `evaluations/` empty → Phase 4
   - PR not created → Phase 5
   - `retrospective/` missing → Phase 6
   - All present → `--status` mode

**`--phase=qa-fix` (per-sprint)**: even if the existing sprint dir is type=standard, work proceeds by adding a `qa-fix/` subdirectory under that sprint dir.

---

## Team Configuration

See `workflows/_shared/agent-team.md` for full role definitions, dispatch protocol, and subject naming conventions.

## Constraints

- Merge conflicts: do not auto-resolve; immediately request user intervention.
- The `.worktrees/` directory is included in `.gitignore`.
- Always confirm with the user before creating PRs or pushing.
- Teammates must not push remote or merge branches (Sprint Lead handles these exclusively).
- **Do not accept a group without Evaluator feedback.**
- **Do not start the next group's implementation (4.2) before the previous group is PASS** (only contract-precedent work is allowed).
- Block Phase transitions when Gate conditions are unmet (override possible with `--force`).
- Fix loop max 2 iterations; on the 3rd failure, mark FAILED and request user intervention.
- For backend-only sprints, Phase 3 auto-skips and the app role's sprint branch is not created.
- **`--continue` is only available after retrospective/ is complete.**
- **`--follow-up` requires the previous sprint's retrospective/ to exist.**
- **Regression Guard**: in follow-up sprints, regression verification of previously-fulfilled AC is required.
- **Checkpoint required**: block progress at Phase/Group transitions if a checkpoint was not created.
