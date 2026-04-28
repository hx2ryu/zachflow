# Build Loop Primitive

> Shared by `workflows/sprint/phase-build.md` (Sprint Phase 4) and `workflows/qa-fix/{stage-3-contract,stage-4-implement-eval}.md` (QA-Fix Stages 3~4). Phase/stage files reference this — never inline-duplicate.

This file is the workflow-agnostic primitive that defines the iterative
Contract → Implement → Merge → Evaluate → Verdict loop. Workflow-specific
behaviors (e.g., group ordering, sprint branch naming) live in the consuming
phase/stage files.

## The Loop

```
For each group:
  1. Contract     — Sprint Lead drafts → Evaluator reviews → consensus on done criteria
  2. Implement    — BE/FE Engineers in parallel worktrees
  3. Merge        — Sprint branch (--no-ff) or fix branch (consumer-defined)
  4. Evaluate     — Evaluator: Active Evaluation
  5. Verdict      — PASS → next group | ISSUES/FAIL → up to 2 fix iterations
```

**Hard constraint**: do not start the next group's implementation before the
previous group's verdict is PASS. The previous group's fixes may invalidate
the next group's spec.

## Severity Classification

| Severity | Definition | Typical examples |
|----------|------------|------------------|
| **Critical** | Done Criterion is unmet, or the implementation is broken (crash, data loss, regression of an existing AC) | API returns 500, FE renders blank screen, payment flow unrecoverable |
| **Major** | A Done Criterion is partially met, or an explicit business rule is violated | Wrong field name in response, edge case not handled, validation missing |
| **Minor** | Polish or non-blocking quality issue | Copy text, small visual misalignment, log noise |

The Evaluator assigns severity per issue. The verdict is a function of how many issues fall in each bucket (see Verdict Rules).

## Verdict Rules

| Verdict | Condition | Next Step |
|---------|-----------|-----------|
| **PASS** | 0 Critical and 0 Major issues | Create checkpoint → proceed to next group |
| **ISSUES** | 0 Critical, 1+ Major | Enter Fix Loop |
| **FAIL** | 1+ Critical, or 3+ Major | Enter Fix Loop (or reimplement) |

## Contract Phase Detail

The workflow caller (Sprint Lead) drafts the contract for the group:

```markdown
# Sprint Contract: Group {N}

## Scope
- Tasks: {task-ids}
- Endpoints: {related API endpoints}

## Done Criteria
- [ ] {testable criterion 1}
- [ ] {testable criterion 2}
- ...

## Verification Method
- {How the Evaluator will verify each criterion}
- {Edge cases to test}
- {Business rules to verify}
```

Save: `runs/{run-id}/contracts/group-{N}.md`

### KB Pattern Auto-Injection

Before drafting the contract, run KB Search (see `_shared/kb-integration.md`) to look up patterns relevant to this group's tasks.

**Injection rules**:
1. Look up patterns whose category matches this group's tasks via the `patterns/README.md` index.
2. For `severity: critical` patterns, automatically add their `contract_clause` to Done Criteria.
3. For `severity: major` + `frequency >= 2` patterns, also add.
4. Annotate the source: `(KB: {pattern-id})`.

### Contract Review

Request the Evaluator to review the contract:

```
TaskCreate:
  Subject: contract-review/group-{N}
  Description: <contract path + reference to original task files>
  Owner: Evaluator
```

**Contract agreement protocol**:

1. Classify Evaluator review feedback:
   | Objection type | Handling |
   |----------------|----------|
   | **Ambiguity** (vague criteria) | Workflow caller concretizes (numbers, conditions) |
   | **Missing Edge Case** | Add to Done Criteria |
   | **Untestable Criterion** | Redesign verification or rewrite the criterion |
   | **Scope Dispute** | Cross-check against original task AC → keep if consistent, fix if not |

2. Agreement loop:
   - Round 1: Evaluator review → workflow caller edits.
   - Round 2: Evaluator re-review → agreement or remaining objections.
   - Round 3 (final): If agreement fails, present remaining objections to the user → user decides.

3. On agreement: Add a `## Sign-off` section to the contract (date + "Evaluator approved").

**Reflect prior-group lessons**: When drafting the Contract for Group 2+, review the previous group's checkpoint summary "Lessons for Next Group" and reinforce Done Criteria accordingly.

## Implement Phase Detail

Dispatch only this group's tasks:

```
For each task in current group:
  TaskCreate:
    Subject: impl/{project}/{task-id}
    Description: <task file + API contract + Sprint Contract reference>
    Owner: {BE/FE} Engineer
```

BE/FE Engineers implement in their assigned worktree and report completion. **BE/FE tasks within the same group run in parallel.**

### Cross-Repo Dependency Handling

When same-group BE/FE run in parallel and FE depends on a BE API that doesn't exist yet:

1. **API Contract is SSOT**: FE Engineer implements against the request/response schema in `api-contract.yaml`.
2. **Mock/Stub strategy**: include in the FE task spec:
   ```
   ## API Dependency
   - Endpoint: POST /api/v1/follows
   - Contract: api-contract.yaml#/paths/~1api~1v1~1follows/post
   - FE implements against the contract. Real BE wiring is verified by the Evaluator post-merge.
   ```
3. **Evaluator integration verification**: After group merge, the Evaluator verifies actual BE↔FE wiring.
4. **On contract mismatch**: Evaluator reports as ISSUES → workflow caller amends the contract → fix tasks on both sides.

## Merge Phase Detail

Merge completed tasks sequentially:

```
1. git checkout {consumer-defined branch}
2. git merge {branch_prefix}/{run-id}/{task-id} --no-ff -m "merge: {task-id}"
3. On conflict: halt the loop, request user intervention
4. On success: clean up the worktree (git worktree remove + branch delete)
```

Same repo: sequential merge in ascending number order.
Different repos: independent → parallel allowed.

**Merge target by workflow**:
- Sprint workflow: merges into the sprint branch with `--no-ff`.
- QA-Fix workflow: may override to merge into a fix branch (consumer-defined).

The consuming phase/stage file specifies which branch the merge targets. Conflicts are NEVER auto-resolved — surface to the user.

### QA Pattern Check (after app task merge)

After merging a group containing app tasks, **before** assigning the Evaluator, the workflow caller runs the project's QA pattern check:

- **Targets**: app tasks that changed files in domain/ or data/ layers.
- **Checks**: polling self-invalidation infinite loops (ESLint), Zod schema nullable (Jest fixture).
- **On FAIL**: reassign a fix task to the FE Engineer, re-merge. Do not assign the Evaluator yet.
- **PASS or N/A**: proceed to E2E Smoke (if applicable).

### E2E Smoke (App group smoke gate, optional)

After app task merge + QA Pattern Check PASS, **before** assigning the Evaluator, the workflow caller may optionally run the e2e flows for this group.

User pre-conditions: simulator/emulator running, dev build installed.

| Result | Action |
|--------|--------|
| All PASS | Proceed to Evaluate |
| Some FAIL | Reassign a fix task to the FE Engineer with the failed flows. fix_loop_count += 1 |
| Environment issue | Ask the user to recover. fix_loop_count not incremented |

**Rationale**: The Evaluator's active evaluation is subjective; obtain objective AC-coverage proof via e2e first, and let the Evaluator analyze *why* afterward.

## Evaluate Phase Detail

After all tasks in the group are merged, assign evaluation to the Evaluator:

```
TaskCreate:
  Subject: eval/{project}/group-{N}
  Description: <Sprint Contract + merged code path + evaluation criteria>
  Owner: Evaluator
```

The Evaluator **auto-loads the cross-run rubric** at evaluation start (see `_shared/kb-integration.md` for the read pattern):
- Combine the run's `evaluation/criteria.md` + the active rubric's Clauses + Promotion Log candidate clauses for evaluation.
- On conflict, the local run criteria take precedence.

The Evaluator performs **Active Evaluation**:
- **Logic Tracing**: follow code execution flow yourself.
- **Contract Verification**: prove each Done Criterion in the Sprint Contract from code.
- **Edge Case Probing**: actively probe edge cases.
- **Cross-Task Integration**: verify type/behavior consistency between API contract and actual implementation.
- **Skepticism**: "assume there is a bug, find it".

Evaluation report: `runs/{run-id}/evaluations/group-{N}.md`

## Fix Loop

On ISSUES or FAIL:

1. **Update pressure level**: fix_loop_count += 1 → recompute pressure (see Budget Pressure Protocol).
2. Forward the Evaluator report to the original Engineer.
   - Caution: `⚠ Context Pressure: Caution — fix only Critical/Major. Defer Minor to the next run.`
   - Urgent: present scope-reduction options to the user.
3. Engineer fixes per-issue and reports completion.
4. Workflow caller merges.
5. Evaluator re-evaluates.
   - Caution: report Minor issues but they don't affect verdict (PASS possible).
   - Urgent: verify only Critical issues.
6. **Maximum 2 iterations**; on the 3rd failure, mark FAILED and request user intervention (escalation).

## Budget Pressure Protocol

Compute the pressure level automatically as the Build Loop progresses, and adjust agent behavior.

**Level computation (at every loop transition)**:

```
pressure = "normal"

if fix_loop_count >= 1 OR engineer_reassign_count >= 2:
    pressure = "caution"

if fix_loop_count >= 2 OR total_issues_in_group >= 5:
    pressure = "urgent"
```

| Level | Trigger | Workflow caller behavior |
|-------|---------|--------------------------|
| 🟢 Normal | Zero fix loops in the current group | Proceed normally |
| 🟡 Caution | Entering fix loop iteration 1, OR an Engineer task reassigned 2+ times | Create a checkpoint immediately + drop detailed context for prior groups |
| 🔴 Urgent | Fix loop iteration 2, OR 5+ total issues in the group | Propose scope reduction + prepare to request user intervention |

**Required workflow caller actions on Normal → Caution transition**:

1. Create the current group's checkpoint immediately (interim checkpoint).
2. Stop referencing the previous group's evaluation original (summary only).
3. Append the caution hint to Engineer task Descriptions.
4. On Evaluator re-evaluation, instruct: "Defer minor issues to the next run".

**Required workflow caller actions on Caution → Urgent transition**:

1. Report the situation to the user:
   ```
   ⚠ Budget Pressure: Urgent
   Group {N}: {M} fix loops, {K} issues
   Options:
   a) Reduce scope — fix only Critical, defer Major
   b) Manual intervention — user reviews/edits the code directly
   c) Group FAILED — move on; carry over later
   ```
2. Proceed based on the user's choice.
3. On Evaluator re-evaluation, instruct: verify only Critical issues.

**Pressure release**: When a group passes, the next group resets to "normal".

**How pressure is injected**: When the workflow caller assigns a task to an Engineer/Evaluator, append a context hint to the task Description based on the current pressure level:

- 🟡 Caution: `⚠ Context Pressure: Caution — focus on core AC. No incidental improvements.`
- 🔴 Urgent: `🔴 Context Pressure: Urgent — implement the minimum only. Scope reduction may be in play.`

## Frozen Snapshot Protocol

> Principle: When Teammates are spawned, design system, pattern library, and KB references are **loaded once and never reloaded within the session**.

**Snapshot targets** (loaded once when Teammate is spawned):

| Target | File | Consumer |
|--------|------|----------|
| Design System | `docs/designs/DESIGN.md` (if present) | Design Engineer |
| Foundations + Components | `docs/designs/foundations/*.mdx` + `docs/designs/components/*.mdx` (Zod frontmatter SSOT) | Design Engineer |
| Component Patterns Index | `docs/designs/README.md` | Design Engineer |
| Design KB | result of KB read for `category=design_proto` (+ `design_spec`) | Design Engineer |
| Code KB | result of KB read for relevant categories | Evaluator, Engineers |
| API Contract (group scope) | `contracts/api-contract.yaml` (current group's endpoints) | Engineers, Evaluator |

**How it's applied**: When the workflow caller calls TaskCreate for a Teammate, include the snapshot context **inline in the Description** as a `--- FROZEN SNAPSHOT ---` block. Teammates do not Read these files separately.

**Forbidden**:
- Teammates reading the snapshot source files directly (workflow caller has already provided them).
- Workflow caller rebuilding the snapshot mid-session (do it once).

**Cost effect**: removes repeated loading of system prompt + reference files in a 4-agent × multi-call structure.

KB sync timing: call `zachflow-kb:sync` once on entering the first group (and on `--resume`) to guarantee fresh KB results before the Frozen Snapshot is built. See `_shared/kb-integration.md`.

## Error Handling

| Situation | Workflow caller handling |
|-----------|--------------------------|
| Engineer implementation failure | Reassign fix task (max 2) → FAILED |
| Merge conflict | Halt run, print conflict detail, request manual resolution |
| Evaluator ISSUES/FAIL | Forward report to original Engineer → fix loop |
| Worktree creation failure | Clean up existing worktree, retry |

### Recovery Playbook

**P1: Engineer implementation repeatedly fails (fix > 2)**
```
1. Classify failure cause: spec ambiguity vs technical limit vs dependency issue
2. spec ambiguity → workflow caller rewrites the task spec, reassigns
3. technical limit → propose scope reduction or alternative approach to user
4. dependency issue → verify prerequisite group results, re-order if needed
5. Mark this task FAILED, continue with other tasks
```

**P2: Merge conflict**
```
1. Print conflict file list + diff
2. Analyze cause: BE/FE overlap within the same group vs leftover changes from prior group
3. Provide conflict context + resolution guidance to user
4. After user resolves → git merge --continue → resume remaining merges
5. If unresolvable → git merge --abort → mark only the affected task FAILED
```

**P3: Evaluator repeatedly FAILs (fix loop > 2)**
```
1. Aggregate accumulated issues (round 1 → 2 → 3)
2. Analyze recurring issue patterns
3. Present 3 options to user:
   a) Scope reduction: defer this AC to the next run
   b) Manual edit: user edits the code directly
   c) Group reimplementation: rewrite task spec, restart from scratch
4. Record deferred items in run-config per the user's choice
```

**P4: Worktree/Branch contamination**
```
1. Inspect all worktrees with git worktree list
2. Stale worktree: git worktree remove --force {path}
3. Stale branch: git branch -D {branch_prefix}/{run-id}/{task-id}
4. Verify run branch integrity: git log --oneline {branch_prefix}/{run-id}
5. Retry
```

**P5: Phase mid-restart (`--resume`)**
```
1. Check the last agreed group number from contracts/
2. Check the last PASS group number from evaluations/
3. Check existing summaries in checkpoints/
4. Resume from the next incomplete group
5. Skip already-merged tasks; redispatch only the unmerged ones
```
