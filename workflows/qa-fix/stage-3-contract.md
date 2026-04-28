# Stage 3: Contract (per group)

qa-fix Stage 3 reuses the Build Loop primitive — see [`../_shared/build-loop.md`](../_shared/build-loop.md) § Contract Phase. Differences specific to qa-fix below.

Sprint Lead drafts the contract for the current group → Evaluator reviews → consensus on done criteria, exactly per the primitive. The qa-fix-specific framing only changes how the contract sections are populated.

## Inputs

- `runs/qa-fix/<run-id>/groups/group-<N>.yaml` (the ticket list for this group).
- `runs/qa-fix/<run-id>/jira-snapshot.yaml` (per-ticket repro / type / priority).

## qa-fix Differences vs. Sprint Build Loop

| Section | Sprint Build Loop | qa-fix |
|---------|-------------------|--------|
| **Done Criteria** | "AC fulfillment" from the deliverable-focused spec | "Each ticket's Verification Steps pass + Root Cause confirmed" — derived from each ticket's repro, not from a sprint AC |
| **Verification Method** | How the Evaluator will verify each criterion | Must include each ticket's **original repro steps inline**, 1:1 mapped to the Done Criteria |
| **Scope** | Sprint task IDs + endpoints | Jira ticket keys for this group + suspected endpoints/screens |
| **KB Pattern Auto-Injection** | Per primitive | Applies identically — looks up patterns relevant to this group's ticket types/components |

## Done Criteria — qa-fix Framing

For each ticket in the group, add at least one Done Criterion of the form:

```markdown
- [ ] {TICKET-ID} — Repro from triage.md no longer reproduces. Root cause documented in fix commit message.
```

Add additional sub-criteria when the repro covers multiple distinct symptoms (e.g., one for the API contract, one for the UI rendering).

## Verification Method — qa-fix Framing

In the Verification Method section, embed each ticket's original repro steps inline (copied from `jira-snapshot.yaml` → ticket description). Example:

```markdown
## Verification Method

### {TICKET-ID-1}
1. Open the app, navigate to {screen}.
2. Tap {control}.
3. Expected: {expected outcome from ticket}. Actual (before fix): {bug observed}.

### {TICKET-ID-2}
...
```

This ensures the Evaluator traces each ticket's verification 1:1 against the actual user-reported repro — not a paraphrase.

## KB Pattern Auto-Injection

Run KB Search per [`../_shared/kb-integration.md`](../_shared/kb-integration.md) before drafting. Inject pattern `contract_clause`s into Done Criteria per the rules in [`../_shared/build-loop.md`](../_shared/build-loop.md) § KB Pattern Auto-Injection. For qa-fix, look up patterns whose category matches the **fix domain** (correctness, integration, code_quality, etc.) — bug fix patterns more often than feature patterns.

## Output

Save: `runs/qa-fix/<run-id>/contracts/group-<N>.md` (use the Phase 4.1 template directly — `templates/sprint-contract.template.md`).

## Contract Review Loop

Per [`../_shared/build-loop.md`](../_shared/build-loop.md) § Contract Review. The same 3-round agreement protocol applies. Sign-off section is required before Stage 4 begins.

## Gate → Stage 4

- [ ] `contracts/group-<N>.md` exists with `## Sign-off — Evaluator approved {date}`.
- [ ] Every ticket in `groups/group-<N>.yaml` has at least one matching Done Criterion.
- [ ] Verification Method embeds each ticket's repro steps.

---
← Prev: [`stage-2-grouping.md`](stage-2-grouping.md)  ·  → Next: [`stage-4-implement-eval.md`](stage-4-implement-eval.md)
