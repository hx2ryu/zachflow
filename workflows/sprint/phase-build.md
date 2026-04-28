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

The Build Loop primitive (Contract → Implement → Merge → Evaluate → Fix) lives in `workflows/_shared/build-loop.md`. This phase file describes only the **sprint-specific framing** around that loop — group ordering, KB sync timing, sprint-branch confirmation, the Phase 4 → Phase 5 gate, and the per-group output format.

For agent role definitions and TaskCreate dispatch patterns, see `workflows/_shared/agent-team.md`.
For worktree setup, branch naming, and cleanup, see `workflows/_shared/worktree.md`.

## Context Window Guard

> Required protocol for preserving context window quality across long build loops.

### Group Transition Protocol

**After Group N is confirmed PASS, before Group N+1 begins**, do the following:

1. **Create checkpoint**: write `runs/sprint/{sprint-id}/checkpoints/group-{N}-summary.md`.
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
- **Prior group info**: refer only to `runs/sprint/{sprint-id}/checkpoints/group-{N}-summary.md`.

### Budget Pressure Protocol

See `workflows/_shared/build-loop.md` § Budget Pressure Protocol.

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

See `workflows/_shared/kb-integration.md` for full KB search/write protocol.

## 4.0 Confirm sprint branches (at first group)

Phase 1's `setup-sprint.sh` already checked out branch `{branch_prefix}/{sprint-id}` in each role directory. No separate branch-creation step is needed.

```bash
# Verify only:
git -C backend branch --show-current   # → {branch_prefix}/{sprint-id}
git -C app branch --show-current       # → {branch_prefix}/{sprint-id}
```

Base branch priority: `sprint-config.yaml` `repositories.<role>.base` → `defaults.base` → `"main"`.

If a role has no tasks, leave that worktree untouched and exclude it from merge/PR steps.

See `workflows/_shared/worktree.md` for full worktree protocol.

## 4.1 Sprint Contract (per group)

See `workflows/_shared/build-loop.md` § Contract Phase Detail. Sprint-specific notes:

- The Sprint Lead is the contract drafter; the Evaluator is the reviewer (see `workflows/_shared/agent-team.md` § Sprint Lead, Evaluator).
- Save path: `runs/sprint/{sprint-id}/contracts/group-{N}.md`.
- KB injection criteria for sprint contracts: `severity: critical` patterns auto-add their `contract_clause` to Done Criteria; `severity: major` + `frequency >= 2` patterns also add. Annotate source as `(KB: {pattern-id})`.
- **Reflect prior-group lessons**: When drafting the Contract for Group 2+, review `runs/sprint/{sprint-id}/checkpoints/group-{N-1}-summary.md`'s "Lessons for Next Group" and reinforce Done Criteria accordingly.

## 4.2 Implement (Engineers)

See `workflows/_shared/build-loop.md` § Implement Phase Detail + Cross-Repo Dependency Handling.

Sprint-specific dispatch: the Sprint Lead is the dispatcher; for each task in the current group, TaskCreate to the BE or FE Engineer per the task's repo. BE/FE tasks within the same group run in parallel.

See `workflows/_shared/agent-team.md` § Dispatch Protocol for the TaskCreate pattern.

## 4.3 Merge (Sprint Lead)

See `workflows/_shared/build-loop.md` § Merge Phase Detail. Sprint workflow uses `--no-ff` to merge into the sprint branch (`{branch_prefix}/{sprint-id}`).

Same repo: sequential merge in ascending number order.
Different repos: independent → parallel allowed.

## 4.3.1 QA Pattern Check (after app task merge)

See `workflows/_shared/build-loop.md` § Merge Phase Detail / QA Pattern Check.

## 4.3.2 E2E Smoke (App group smoke gate)

See `workflows/_shared/build-loop.md` § Merge Phase Detail / E2E Smoke.

## 4.4 Evaluate (Evaluator)

See `workflows/_shared/build-loop.md` § Evaluate Phase Detail.

Sprint-specific:
- Evaluation report path: `runs/sprint/{sprint-id}/evaluations/group-{N}.md`.
- The Evaluator auto-loads the cross-sprint rubric at evaluation start (`zachflow-kb:read type=rubric status=active`) and combines it with the sprint's `evaluation/criteria.md`.

## 4.5 Fix Loop

See `workflows/_shared/build-loop.md` § Fix Loop. Maximum 2 iterations; on the 3rd failure, mark FAILED and request user intervention.

## 4.6 Error Handling and Recovery Playbook

See `workflows/_shared/build-loop.md` § Error Handling.

Sprint-specific recovery case:

**P5: Phase mid-restart (`/sprint {id} --phase=build --resume`)**
```
1. Check the last agreed group number from runs/sprint/{sprint-id}/contracts/
2. Check the last PASS group number from runs/sprint/{sprint-id}/evaluations/
3. Check existing summaries in runs/sprint/{sprint-id}/checkpoints/
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
1. Create the group summary checkpoint (`runs/sprint/{sprint-id}/checkpoints/group-{N}-summary.md`).
2. **Print Sprint Status** — show group progress, agent state, bottleneck detection.
3. Enter the next Group or transition to Phase 5.

## Output

When the Gate passes:
1. Create the checkpoint file (`runs/sprint/{sprint-id}/checkpoints/phase-4-summary.md`).
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
