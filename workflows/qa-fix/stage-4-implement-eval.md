# Stage 4: Implement + Evaluate (per group)

qa-fix Stage 4 reuses the Build Loop primitive — see [`../_shared/build-loop.md`](../_shared/build-loop.md) § Implement Phase, § Merge Phase, § Evaluate Phase, and § Fix Loop. Differences specific to qa-fix below.

BE/FE Engineers implement in parallel worktrees, the Sprint Lead merges, the Evaluator runs Active Evaluation, and the verdict drives the fix loop — exactly per the primitive. The qa-fix-specific framing only changes the task subject naming, the task description payload, the smoke flows, and the evaluator's verification mapping.

## Inputs

- `runs/qa-fix/<run-id>/contracts/group-<N>.md` (signed off by the Evaluator).
- `runs/qa-fix/<run-id>/groups/group-<N>.yaml` (ticket list).
- `runs/qa-fix/<run-id>/jira-snapshot.yaml` (per-ticket repro).

## qa-fix Differences vs. Sprint Build Loop

| Concern | Sprint Build Loop | qa-fix |
|---------|-------------------|--------|
| **Implement task subject** | `impl/{project}/{task-id}` | `qa-fix/backend/<run-id>/group-<N>` or `qa-fix/app/<run-id>/group-<N>` |
| **Task description payload** | Task file + API contract + Sprint Contract | Ticket key list + each ticket's repro steps + Sprint Contract reference + (where relevant) API contract |
| **Merge target** | Sprint branch (`--no-ff`) | Fix branch (consumer-defined; usually a fix branch off the integration base) — see [`../_shared/build-loop.md`](../_shared/build-loop.md) § Merge Phase |
| **E2E Smoke** | Affected flows for new features | Affected flows for this group + (where feasible) **regression flows** that reproduce the original repro steps |
| **Evaluator verification** | Done Criteria from spec | **Traces each ticket's verification steps 1:1** against the original repro |
| **Evaluation report** | `evaluations/group-<N>.md` (sprint dir) | `runs/qa-fix/<run-id>/evaluations/group-<N>.md` |
| **Fix loop max** | 2 iterations → FAILED | 2 iterations → ticket detached from group, added to `unresolved.md`. The remaining tickets in the group continue to Stage 5. |

## Engineer Task Description — qa-fix Framing

When dispatching to the BE/FE Engineer, the Sprint Lead inlines the ticket key list and each ticket's repro steps into the task Description, on top of the standard sprint payload. Example skeleton:

```
TaskCreate:
  Subject: qa-fix/backend/<run-id>/group-<N>
  Owner: BE Engineer
  Description:
    Sprint Contract: runs/qa-fix/<run-id>/contracts/group-<N>.md

    Tickets in this group:
      - {TICKET-1}: {one-line summary}
        Repro:
          1. ...
          2. ...
          Expected: ...
          Actual: ...
      - {TICKET-2}: ...

    API Contract (relevant endpoints): ...

    --- FROZEN SNAPSHOT ---
    {Code KB results, design refs, etc. per agent-team.md}
```

Same-group BE/FE tasks run in parallel per the primitive.

## E2E Smoke — qa-fix Framing

Per [`../_shared/build-loop.md`](../_shared/build-loop.md) § E2E Smoke (App group smoke gate, optional). For qa-fix, additionally:

- Include a **regression flow** for each ticket that has a feasible Maestro/E2E step (use the original repro as the flow script).
- If the original repro is not automatable, note "regression: manual" in the smoke report and have the Evaluator manually walk it during Active Evaluation.

## Evaluator — qa-fix Framing

Per [`../_shared/build-loop.md`](../_shared/build-loop.md) § Evaluate Phase. For qa-fix, the Evaluator:

1. **Traces each ticket's verification steps 1:1** against the contract's Verification Method block (which embeds the original repro).
2. Verdict semantics inherit the primitive's Verdict Rules table — but each ticket is treated as its own atomic verification target. Per-ticket result is `PASS | FAIL`.
3. Group-level verdict aggregates per-ticket results: PASS only if every ticket in the group is PASS.

Evaluation report: `runs/qa-fix/<run-id>/evaluations/group-<N>.md`. Include a per-ticket result table at the top.

## Fix Loop — qa-fix Framing

Per [`../_shared/build-loop.md`](../_shared/build-loop.md) § Fix Loop. The standard 2-iteration max applies. qa-fix-specific addition:

> **Tickets that remain FAIL after the fix loop is exhausted (2 iterations)**: detach the ticket from the group → add to `runs/qa-fix/<run-id>/unresolved.md` with the accumulated Evaluator findings. Block Stage 5 progress **for that ticket only**. The remaining PASS tickets in the group proceed to Stage 5.

## Gate → Stage 5

- [ ] `evaluations/group-<N>.md` exists with a per-ticket result table.
- [ ] Group-level verdict is PASS for all PASS tickets (FAIL tickets diverted to `unresolved.md`).
- [ ] Regression evidence (Maestro flow or manual-walk note) recorded for each PASS ticket.

---
← Prev: [`stage-3-contract.md`](stage-3-contract.md)  ·  → Next: [`stage-5-close.md`](stage-5-close.md)
