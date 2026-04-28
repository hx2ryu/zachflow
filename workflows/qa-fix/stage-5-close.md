# Stage 5: Close (per ticket, local-first)

Sprint Lead self-task. Close each PASSed ticket with a local-first comment SSOT, then post to Jira and transition. See [`SKILL.md`](SKILL.md) for invocation context.

For each PASSed ticket, execute the following sub-steps **in this order**. The order is load-bearing: regression evidence must be in place before authoring the comment, and the local SSOT must be authored before posting to Jira so a posting failure does not destroy the comment body.

## 1. Add Regression Evidence

Where feasible, the FE/BE Engineer adds a Maestro flow alongside the fix commit (driven by Stage 4's E2E Smoke regression flows). If infrastructure is unavailable or impractical, note an N/A reason — `N/A — <reason>` — in the Evidence section of the comment in the next step.

## 2. Author Comment Body Locally (SSOT)

- File: `runs/qa-fix/<run-id>/jira-comments/<TICKET-ID>.md`
- Template: `templates/qa-fix-comment.template.md`

**Field rules**:

| Field | Rule |
|-------|------|
| Root Cause | 1 paragraph. **No "Unknown"** — if root cause was indeterminate, the ticket should not have PASSed. |
| Fix Summary | 1 paragraph. **No raw diffs** pasted in. |
| Verification Steps | At least 1 step, **1:1 mapped** to the original repro from `triage.md` / `jira-snapshot.yaml`. |
| Evidence | PR link **always required**. If regression/screenshots are missing, write `N/A — <reason>`. |

If any Evidence is partial, add a `⚠️` marker in the header.

## 3. Extract KB Candidate (P0/P1 only)

For tickets with priority ∈ {P0, P1}:

- File: `runs/qa-fix/<run-id>/kb-candidates/<TICKET-ID>.yaml`
- Template: `templates/qa-fix-kb-candidate.template.yaml`

**`candidate_type` classification**:

| Type | Meaning |
|------|---------|
| `pattern_gap` | An area not covered by the existing KB |
| `pattern_violation` | Existing KB pattern violated by the original bug |
| `new_pattern` | Subset of `pattern_gap` but a clear new reusable pattern |

**Skip KB candidates for P2/P3** — these are included only in the Pattern Digest stats at Retro.

## 4. Post Jira Comment (when not `--dry-run`)

```
mcp__wrtn-mcp__jira_add_comment:
  issue_key: <TICKET-ID>
  body: <full content of jira-comments/<TICKET-ID>.md, after HTML comment stripping>
```

**Retry policy**: 2 retries on failure. If still failing, report to the user and **block transition**. Preserve the local comment SSOT.

### HTML Comment Stripping (mandatory)

The local SSOT `<TICKET-ID>.md` template contains HTML comment blocks (e.g., `<!-- PARTIAL EVIDENCE: ... -->`) that are for the Sprint Lead's reference only — they **MUST NOT** be posted to Jira. Before calling `mcp__wrtn-mcp__jira_add_comment`, strip all `<!-- ... -->` blocks (including multi-line ones) from the body. Sprint Lead is responsible for this transformation.

## 5. Jira Transition (only on successful comment post)

```
target_name = run-config.qa_fix.ready_for_qa_transition  # default "Ready for QA"
transitions = mcp__wrtn-mcp__jira_get_transitions(issue_key)
target = transitions.find(name=target_name)
if target is None:
    # transition name mismatch — apply failure mode
    fail_with("transition_name_not_found", available=transitions.map(t => t.name))
mcp__wrtn-mcp__jira_transition_issue(issue_key, transition_id=target.id)
```

### Transition Failure Modes

| Situation | Handling |
|-----------|----------|
| `transition_name_not_found` | No marker. Present available transition names to user → instruct to update `run-config.qa_fix.ready_for_qa_transition` and rerun. |
| Transition API failure (after successful comment post) | Preserve `<TICKET-ID>.md`. No marker. Report to user; auto-retry on next run. |

## 6. Posted Marker (idempotency)

```bash
touch runs/qa-fix/<run-id>/jira-comments/<TICKET-ID>.posted
```

The marker's existence is the signal for **idempotency**: subsequent qa-fix runs skip any ticket whose `.posted` marker exists in any prior run dir for the same ticket key (see Stage 1 § 2 Idempotency Check).

## FAIL Tickets

Tickets in `unresolved.md` (FAIL after 2 fix-loop iterations) **skip Stage 5 entirely**:

- Do **not** author a local comment SSOT.
- Do **not** post to Jira.
- Do **not** transition.
- Do **not** create a posted marker.

The unresolved tickets are surfaced at Retro for the next round.

## Retro (after all groups close)

Once every PASS ticket has a `.posted` marker (and FAIL tickets are recorded in `unresolved.md`), write `runs/qa-fix/<run-id>/retro.md` (template: `templates/qa-fix-retro.template.md`). Retro covers:

1. **Pattern Digest auto-derivation** — category distribution across all processed fixes (including P2/P3). If the same pattern is violated 3+ times, automatically add a "Reinforcement needed" notice.
2. **KB Candidate Review — user approval gate**:
   - Present each candidate as a row → `approve` / `reject` / `merge-into:<existing-id>`.
   - If approvals exceed 5, add a "merge top-N only" gate.
   - Status transitions from Retro decisions:
     - `approve` → `status: approved`. Sprint Lead invokes `zachflow-kb:write-pattern` (flattening `proposed_pattern.*`).
     - `reject` → `status: rejected`. `review_notes:` records why.
     - `merge-into:<existing-id>` → `status: duplicate`, `related_existing_pattern:` updated to the merge target. No `zachflow-kb:write-pattern` call.
   - All decisions persist the candidate file (rejected/duplicate are kept as audit trail).
3. **Deferred Index** — list of deferred + needs-info + unresolved tickets from this run.
4. **Next Round Suggestion** — auto-generate a JQL for deferred + new P0/P1 tickets.

## Gate → Done

- [ ] For every PASS ticket: `<TICKET-ID>.md` and `<TICKET-ID>.posted` both exist (or only `<TICKET-ID>.md` under `--dry-run`).
- [ ] FAIL tickets are recorded in `unresolved.md` with no Jira side-effects.
- [ ] `retro.md` exists with KB-candidate user decisions recorded.

---
← Prev: [`stage-4-implement-eval.md`](stage-4-implement-eval.md)
