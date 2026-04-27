# Phase 4: Build (Sprint Lead + BE + FE + Evaluator — Iterative Loop)

**Core**: not a single bulk dispatch of all tasks, but an iterative loop in feature-group units.

```
For each feature group (001, 002, 003, ...):
  4.1 Contract  → Sprint Lead drafts, Evaluator reviews
  4.2 Implement → Engineers build in worktrees
  4.3 Merge     → Sprint Lead merges to sprint branch
  4.4 Evaluate  → Evaluator actively assesses
  4.5 Fix/Accept → Fix loop or proceed to next group
```

## Context Window Guard

> Required protocol for preserving context window quality across long build loops.

### Group Transition Protocol

**After Group N is confirmed PASS, before Group N+1 begins**, do the following:

1. **Create checkpoint**: write `checkpoints/group-{N}-summary.md`.
2. **Reference rule going forward**: From Group N+1 onward, do not re-read Group N's original evaluation report — refer only to the summary.
3. **Exception**: Reading the original is allowed when the fix loop must reproduce a prior issue exactly.

**Checkpoint template**:
```markdown
# Group {N} Summary: {sprint-id}

## Scope
- Tasks: {task-ids}
- Endpoints: {related API endpoints}

## Result: {PASS | FAILED}
- Fix loops: {N}
- Evaluator verdict: {final verdict summary}

## Issues Found & Resolved
| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 1 | {major/minor} | {one-line issue summary} | {one-line resolution} |

## Lessons for Next Group
- {Lesson to reflect into the next group's Contract/implementation}

## Files Changed
- {Key changed files}
```

### Progressive File Reading

For context efficiency the Sprint Lead reads files selectively:
- **api-contract.yaml**: only the current group's relevant endpoints (use `offset`/`limit`).
- **Task files**: focus on the AC section (rather than the whole file).
- **Evaluation reports**: only the issue list + verdict sections.
- **Prior group info**: refer only to `checkpoints/group-{N}-summary.md`.

### Budget Pressure Protocol

> Compute the pressure level automatically as the Build Loop progresses, and adjust agent behavior.

**Level computation (at every 4.x transition)**:

```
pressure = "normal"

if fix_loop_count >= 1 OR engineer_reassign_count >= 2:
    pressure = "caution"

if fix_loop_count >= 2 OR total_issues_in_group >= 5:
    pressure = "urgent"
```

**Required Sprint Lead actions on Normal → Caution transition**:

1. Create the current group's checkpoint immediately (interim checkpoint).
2. Stop referencing the previous group's evaluation original (summary only).
3. Append the caution hint to Engineer task Descriptions.
4. On Evaluator re-evaluation, instruct: "Defer minor issues to the next sprint".

**Required Sprint Lead actions on Caution → Urgent transition**:

1. Report the situation to the user:
   ```
   ⚠ Budget Pressure: Urgent
   Group {N}: {M} fix loops, {K} issues
   Options:
   a) Reduce scope — fix only Critical, defer Major
   b) Manual intervention — user reviews/edits the code directly
   c) Group FAILED — move on; carry over in Phase 6
   ```
2. Proceed based on the user's choice.
3. On Evaluator re-evaluation, instruct: verify only Critical issues.

**Pressure release**: When a group passes, the next group resets to "normal".

## Pipeline Parallelization Rules

Sequential execution is the default, but parallelism is allowed under these conditions:

| Situation | Allowed |
|-----------|---------|
| During Group N evaluation (4.4) | Drafting Group N+1 Contract (4.1) is allowed in parallel |
| Before Group N PASS is confirmed | Implementing Group N+1 (4.2) is **not** allowed |
| Same-group BE/FE | Always parallel |
| Cross-repo merges (4.3) | Independent → parallel |

**Hard constraint**: Do not start the next group's implementation before the previous group is PASS. The previous group's fixes may affect the next group's spec.

## 4.0a KB Sync

On entering the first group, call `zachflow-kb:sync` once (fast-forward pull). This guarantees fresh `zachflow-kb:read` results for §4.1 Contract drafting and §4.4 Evaluation. Recommended on `--resume` as well.

## 4.0 Confirm sprint branches (at first group)

Phase 1's `setup-sprint.sh` already checked out branch `{branch_prefix}/{sprint-id}` in each role directory. No separate branch-creation step is needed.

```bash
# Verify only:
git -C backend branch --show-current   # → {branch_prefix}/{sprint-id}
git -C app branch --show-current       # → {branch_prefix}/{sprint-id}
```

Base branch priority: `sprint-config.yaml` `repositories.<role>.base` → `defaults.base` → `"main"`.

If a role has no tasks, leave that worktree untouched and exclude it from merge/PR steps.

## 4.1 Sprint Contract (per group)

The Sprint Lead drafts the contract for the group:

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

Save: `runs/{sprint-id}/contracts/group-{N}.md`

### KB Pattern Auto-Injection

Before drafting the contract, run the KB Search from `knowledge-base.md` to look up patterns relevant to this group's tasks.

**Injection rules**:
1. Look up patterns whose category matches this group's tasks via the `patterns/README.md` index.
2. For `severity: critical` patterns, automatically add their `contract_clause` to Done Criteria.
3. For `severity: major` + `frequency >= 2` patterns, also add.
4. Annotate the source: `(KB: {pattern-id})`.

**Example**:
```markdown
## Done Criteria
- [ ] Profile API returns 200 (AC-2.1)
- [ ] Pagination API: nextCursor returns a real value (KB: correctness-001)
- [ ] BE response field names exactly match api-contract.yaml (KB: integration-001)
```

Request the Evaluator to review the contract:

```
TaskCreate:
  Subject: contract-review/group-{N}
  Description: <contract path + reference to original task files>
  Owner: Evaluator
```

**Contract agreement protocol:**

1. **Classify Evaluator review feedback**:
   | Objection type | Handling |
   |----------------|----------|
   | **Ambiguity** (vague criteria) | Sprint Lead concretizes (numbers, conditions) |
   | **Missing Edge Case** | Add to Done Criteria |
   | **Untestable Criterion** | Redesign verification or rewrite the criterion |
   | **Scope Dispute** | Cross-check against original task AC → keep if consistent, fix if not |

2. **Agreement loop**:
   - Round 1: Evaluator review → Sprint Lead edits.
   - Round 2: Evaluator re-review → agreement or remaining objections.
   - Round 3 (final): If agreement fails, present the remaining objections to the user → user decides.

3. **On agreement**: Add a `## Sign-off` section to the contract (date + "Evaluator approved").

**Reflect prior-group lessons**: When drafting the Contract for Group 2+, review `checkpoints/group-{N-1}-summary.md`'s "Lessons for Next Group" and reinforce Done Criteria accordingly.

## 4.2 Implement (Engineers)

Dispatch only this group's tasks:

```
For each task in current group:
  TaskCreate:
    Subject: impl/{project}/{task-id}
    Description: <task file + API contract + Sprint Contract reference>
    Owner: {BE/FE} Engineer
```

BE/FE Engineers implement in the worktree and report completion.
**BE/FE tasks within the same group run in parallel.**

### Cross-Repo Dependency Handling

When same-group BE/FE run in parallel and FE depends on a BE API that doesn't exist yet:

1. **API Contract is SSOT**: FE Engineer implements against the request/response schema in `api-contract.yaml`.
2. **Mock/Stub strategy**: include the following in the FE task spec:
   ```
   ## API Dependency
   - Endpoint: POST /api/v1/follows
   - Contract: api-contract.yaml#/paths/~1api~1v1~1follows/post
   - FE implements against the contract. Real BE wiring is verified by the Evaluator post-merge.
   ```
3. **Evaluator integration verification**: After group merge, the Evaluator verifies actual BE↔FE wiring.
4. **On contract mismatch**: Evaluator reports as ISSUES → Sprint Lead amends the contract → fix tasks on both sides.

## 4.3 Merge (Sprint Lead)

Merge completed tasks sequentially:

```
1. git checkout {branch_prefix}/{sprint-id}
2. git merge {branch_prefix}/{sprint-id}/{task-id} --no-ff -m "merge: {task-id}"
3. On conflict: halt the sprint, request user intervention
4. On success: clean up the worktree (git worktree remove + branch delete)
```

Same repo: sequential merge in ascending number order.
Different repos: independent → parallel allowed.

## 4.3.1 QA Pattern Check (after app task merge)

After merging a group containing app tasks, **before** assigning the Evaluator, the Sprint Lead runs the project's QA pattern check:

- **Targets**: app tasks that changed files in domain/ or data/ layers.
- **Checks**: polling self-invalidation infinite loops (ESLint), Zod schema nullable (Jest fixture).
- **On FAIL**: reassign a fix task to the FE Engineer, re-merge. Do not assign the Evaluator yet.
- **PASS or N/A**: proceed to 4.3.2 E2E Smoke.

## 4.3.2 E2E Smoke (App group smoke gate)

After app task merge + QA Pattern Check PASS, **before** assigning the Evaluator, the Sprint Lead optionally runs the e2e flows for this group.

**Selecting target flows**:
- From `contracts/e2e-flow-plan.md`, extract the flow list mapped to this group's AC.
- New flows must have been merged together with the code (FE Engineer's responsibility).

**Execution**:
```bash
cd app
# Run an individual flow (use the e2e:auth wrapper if auth is required)
yarn workspace <example app> e2e:auth -- {flow-file-relative-path}
```

User pre-conditions are required — simulator/emulator running, dev build installed. If unmet, ask the user to "please prepare the simulator" and wait.

**Result handling**:
| Result | Action |
|--------|--------|
| All PASS | Proceed to 4.4 Evaluate (inform the Evaluator that e2e PASSed) |
| Some FAIL | Reassign a fix task to the FE Engineer with the failed flows + Maestro output. fix_loop_count += 1 |
| Environment issue (token expired/seed fetch failed) | Ask the user to recover. fix_loop_count not incremented |

**Budget Pressure integration**:
- 🟡 Caution: only run new flows in this group (skip pre-existing Covered flows).
- 🔴 Urgent: run smoke-test + 1 core flow only.

**Rationale**: The Evaluator's active evaluation is subjective; obtain objective AC-coverage proof via e2e first, and let the Evaluator analyze *why* afterward.

## 4.4 Evaluate (Evaluator)

After all tasks in the group are merged, assign evaluation to the Evaluator:

```
TaskCreate:
  Subject: eval/{project}/group-{N}
  Description: <Sprint Contract + merged code path + evaluation criteria>
  Owner: Evaluator
```

The Evaluator **auto-loads the cross-sprint rubric** at evaluation start:
- `zachflow-kb:read type=rubric status=active` → returns the latest rubric file path → load via Read.
- Combine the sprint's `evaluation/criteria.md` + that rubric's Clauses + Promotion Log candidate clauses for evaluation.
- On conflict, the local sprint criteria take precedence.

The Evaluator performs **Active Evaluation**:
- Prove each Done Criterion in the Sprint Contract from code.
- Trace logic to follow execution flow.
- Actively probe edge cases.
- Skepticism: "assume there is a bug, find it".

Evaluation report: `runs/{sprint-id}/evaluations/group-{N}.md`

Verdict:
| Verdict | Condition | Next Step |
|---------|-----------|-----------|
| **PASS** | 0 Critical/Major issues | Create checkpoint → proceed to next group |
| **ISSUES** | 0 Critical, 1+ Major | 4.5 Fix Loop |
| **FAIL** | 1+ Critical, or 3+ Major | 4.5 Fix Loop (or reimplement) |

## 4.5 Fix Loop (with Budget Pressure integration)

On ISSUES or FAIL:

1. **Update pressure level**: fix_loop_count += 1 → recompute pressure.
2. Forward the Evaluator report to the original Engineer.
   - 🟡 Caution: `⚠ Context Pressure: Caution — fix only Critical/Major. Defer Minor to the next sprint.`
   - 🔴 Urgent: present scope-reduction options to the user (see Budget Pressure Protocol).
3. Engineer fixes per-issue and reports completion.
4. Sprint Lead merges.
5. Evaluator re-evaluates.
   - 🟡 Caution: report Minor issues but they don't affect verdict (PASS possible).
   - 🔴 Urgent: verify only Critical issues.
6. **Maximum 2 iterations**; on the 3rd failure, mark FAILED and request user intervention.

## 4.6 Error Handling and Recovery Playbook

| Situation | Sprint Lead handling |
|-----------|----------------------|
| Engineer implementation failure | Reassign fix task (max 2) → FAILED |
| Merge conflict | Halt sprint, print conflict detail, request manual resolution |
| Evaluator ISSUES/FAIL | Forward report to original Engineer → fix loop |
| Worktree creation failure | Clean up existing worktree, retry |

### Recovery Playbook

**P1: Engineer implementation repeatedly fails (fix > 2)**
```
1. Classify failure cause: spec ambiguity vs technical limit vs dependency issue
2. spec ambiguity → Sprint Lead rewrites the task spec, reassigns
3. technical limit → Propose scope reduction or alternative approach to user
4. dependency issue → Verify prerequisite group results, re-order if needed
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
   a) Scope reduction: defer this AC to the next sprint
   b) Manual edit: user edits the code directly
   c) Group reimplementation: rewrite task spec, restart from scratch
4. Record deferred items in sprint-config.yaml per the user's choice
```

**P4: Worktree/Branch contamination**
```
1. Inspect all worktrees with git worktree list
2. Stale worktree: git worktree remove --force {path}
3. Stale branch: git branch -D {branch_prefix}/{sprint-id}/{task-id}
4. Verify sprint branch integrity: git log --oneline {branch_prefix}/{sprint-id}
5. Retry
```

**P5: Phase mid-restart (`/sprint {id} --phase=build --resume`)**
```
1. Check the last agreed group number from contracts/
2. Check the last PASS group number from evaluations/
3. Check existing summaries in checkpoints/
4. Resume from the next incomplete group
5. Skip already-merged tasks; redispatch only the unmerged ones
```

## Gate → Phase 5

Enter Phase 5 when **all** are satisfied:
- [ ] All groups ACCEPTED (Evaluator PASS).
- [ ] 0 FAILED groups (if any exist, ask the user to confirm skip).
- [ ] All worktrees cleaned up (none remain).
- [ ] All merge commits reflected on the sprint branch.
- [ ] Every group has a checkpoint summary.

**Partial PR allowed**: With `--allow-partial`, create the PR using ACCEPTED groups only. List FAILED groups in the PR body.

## On Group Completion

After each Group's Evaluator PASS/FAIL verdict:
1. Create the group summary checkpoint (`checkpoints/group-{N}-summary.md`).
2. **Print Sprint Status** — show group progress, agent state, bottleneck detection.
3. Enter the next Group or transition to Phase 5.

## Output

When the Gate passes:
1. Create the checkpoint file (`checkpoints/phase-4-summary.md`).
2. **Print Sprint Status** — emit the `--status` dashboard to show current progress.
3. Enter the next Phase.

```
Sprint Build: {sprint-id}

  [Group 001] ACCEPTED
    impl/backend/001-profile-api        merged → eval PASS
    impl/app/001-profile-screen         merged → eval PASS

  [Group 002] EVALUATING
    impl/backend/002-follow-api         merged
    impl/app/002-follow-ui              merged
    eval: pending...

  Results: 1/3 groups accepted, 1/3 evaluating

[Sprint Status Dashboard]

→ Proceeding to Phase 5: PR (all groups accepted)
```
