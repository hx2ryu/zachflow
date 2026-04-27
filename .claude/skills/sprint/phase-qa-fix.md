# Phase QA-Fix (Sprint Lead + BE + FE + Evaluator — Iterative Loop)

After a sprint ends, process Jira issue tickets discovered during functional QA in group units.
The 4.1~4.5 stages of the existing Phase 4 Build Loop are reused — this file defines only the entry/exit stages.

## Entry Paths

This phase has two entry paths. Routing is handled in SKILL.md.

| Path | Trigger | Sprint Dir |
|------|---------|------------|
| **per-sprint** | `/sprint <sprint-id> --phase=qa-fix --jql="..."` | Add `qa-fix/` inside the existing sprint dir |
| **integration** | `/sprint <new-id> --type=qa-fix --jql="..." --base-branches=...` | Phase 1 init creates a new sprint dir; Phase 2~3 auto-skipped, jumps straight to this phase |

When `--dry-run` is provided, all Jira write calls (comment posting, transition, update) are blocked and only artifacts are produced.

## Directory Layout

```
runs/<sprint-id>/qa-fix/
├── jira-snapshot.yaml          # Stage 1
├── triage.md                   # Stage 1 (user approval gate)
├── groups/
│   └── group-<N>.yaml          # Stage 2
├── contracts/group-<N>.md      # Stage 3 (Build Loop 4.1 output)
├── evaluations/group-<N>.md    # Stage 4 (Build Loop 4.4 output)
├── jira-comments/
│   ├── <TICKET-ID>.md          # Stage 5 (local SSOT)
│   └── <TICKET-ID>.posted      # Stage 5 (post+transition success marker)
├── kb-candidates/<TICKET-ID>.yaml # Stage 5 (P0/P1 only)
├── unresolved.md               # FAILED tickets
└── retro.md                    # Retro
```

## Task Subject Naming

Consistent with existing `phase-build.md` conventions. The Sprint Lead uses these when dispatching subagent tasks per Stage:

| Stage | Subject pattern | Owner |
|-------|----------------|-------|
| Stage 1 Triage | `qa-triage/<sprint-id>` | Sprint Lead (self) |
| Stage 3 Contract | `qa-contract/<sprint-id>/group-<N>` | Sprint Lead → Evaluator review |
| Stage 4 Implement | `qa-fix/backend/<sprint-id>/group-<N>` | BE Engineer |
| Stage 4 Implement | `qa-fix/app/<sprint-id>/group-<N>` | FE Engineer |
| Stage 4 Evaluate | `qa-eval/<sprint-id>/group-<N>` | Evaluator |
| Stage 5 Close | `qa-close/<sprint-id>/<TICKET-ID>` | Sprint Lead (self) |

## 5-Stage Core Loop

### Stage 1: Fetch & Triage

1. Sprint Lead fetches from Jira:
   ```
   mcp__wrtn-mcp__jira_search_issues:
     jql: <CLI argument or sprint-config.qa_fix.jql>
     fields: [summary, priority, issuetype, status, reporter, assignee, labels, components, fixVersions, created, description]
   ```

2. **Idempotency check**: If a result ticket already has `qa-fix/jira-comments/<key>.posted` marker = already closed. Auto-exclude.

3. Write `qa-fix/jira-snapshot.yaml` (template: `templates/qa-fix-jira-snapshot.template.yaml`).

   **Ticket `type` enum mapping:** The snapshot's `type` field uses a normalized enum (`Bug | UX | Perf | Copy | Other`) — not the raw Jira `issuetype.name`. Map as follows: Bug → `Bug`; Story/Task containing UI/visual concerns → `UX`; performance/load issues → `Perf`; copy/text/typo → `Copy`; everything else → `Other`. The triage and group templates use this same normalized enum.

   **Ticket `priority` enum mapping:** The snapshot's `priority` field uses a normalized enum (`P0 | P1 | P2 | P3`) — not Jira's raw `priority.name`. Map as follows: Highest → `P0`; High → `P1`; Medium → `P2`; Low/Lowest → `P3`. If the project's Jira workflow uses different priority names, document the mapping as a comment in `sprint-config.yaml` (no separate config field). All triage/KB-candidate logic downstream uses these P-values.

4. **Auto-classification** — classify each ticket into 4 buckets:
   - **in-scope**: priority ∈ {P0, P1, P2}, status open-like, summary clear, related to the same sprint scope.
   - **deferred**: priority = P3 OR scope outside this round.
   - **needs-info**: no repro steps in the description, or missing key info (build number/device/user ID).
   - **duplicate**: another open ticket appears to share the same root cause.

   **Classification heuristics** are not deterministic — explicitly note the Sprint Lead's judgment. The user can promote/demote items in triage.md.

5. Write `qa-fix/triage.md` (template: `templates/qa-fix-triage.template.md`).

6. **User approval gate** (before any destructive Jira write): present triage.md to the user. Wait until the marker `[x] **Approved by user** — proceed to Stage 2 (Grouping)` + timestamp is filled in. The user can edit the in-scope list (promote/demote/needs-info→in-scope/duplicate→in-scope, etc.).

   **Approval marker semantics:** Sprint Lead detects approval by grep-ing for `[x] **Approved by user**` in `triage.md`. Once detected, the Sprint Lead fills `Approved at:` with current ISO 8601 timestamp before proceeding. If the user edits the lists, **the final classification** becomes the target of subsequent Jira writes.

7. **Handle needs-info tickets** (after approval, when not dry-run):
   ```
   For each needs-info ticket in approved triage.md:
     mcp__wrtn-mcp__jira_add_comment:
       issue_key: <key>
       body: "QA Triage — additional info needed: <specific question>"
   ```
   Record the actually-posted text in triage.md's "Question Posted" column.

8. **Handle duplicate tickets** (after approval, when not dry-run):
   ```
   For each duplicate ticket in approved triage.md:
     mcp__wrtn-mcp__jira_add_comment: "Duplicate of <master-key>"
     mcp__wrtn-mcp__jira_transition_issue: <to "Closed" with resolution=Duplicate>
   ```

   **Why ordering is enforced (steps 6→7,8):** Since the user can adjust needs-info/duplicate classifications during the triage approval step, Jira writes only apply to the approved final classification. Posting comments/transitions before approval can leave wrong comments on tickets the user promoted.

### Stage 2: Grouping

Bundle the approved in-scope tickets into groups.

**Grouping criteria** (in priority order):
1. Suspected same root cause — one fix can resolve many.
2. Same BE endpoint — avoid contract conflicts.
3. Same screen/module — avoid UI conflicts.

Each group: 1~5 tickets. If there are too many groups (>5), suggest to the user that we proceed only with the top-N priority groups.

For each group, write `qa-fix/groups/group-<N>.yaml` (template: `templates/qa-fix-group.template.yaml`).

**Gate**: every in-scope ticket must be assigned to exactly one group. Unassigned tickets move to deferred.

### Stage 3: Contract (per group)

**Reuses existing Phase 4.1**. Follow `phase-build.md` Section 4.1.

Differences:
- Done Criteria are not "AC fulfillment" but "each ticket's Verification Steps pass + Root Cause confirmed".
- The Verification Method must include each ticket's original repro steps.
- KB pattern auto-injection is applied identically.

Save: `qa-fix/contracts/group-<N>.md` (use the Phase 4.1 template directly — `templates/sprint-contract.template.md`).

### Stage 4: Implement + Evaluate (per group)

**Reuses existing Phase 4.2~4.5**. Follow `phase-build.md` Sections 4.2~4.5.

Only the differences:
- Task subject naming: `qa-fix/backend/<sprint-id>/group-<N>` / `qa-fix/app/...`.
- Inline the list of ticket keys + each ticket's repro steps in the Engineer task description.
- E2E Smoke (4.3.2): affected flows in this group + (where feasible) new regression flows.
- The Evaluator traces each ticket's verification steps 1:1.
- Evaluation output: `qa-fix/evaluations/group-<N>.md`.

**Tickets that remain FAIL after the fix loop is exhausted (2 iterations)**: separate from the group → add to `qa-fix/unresolved.md`. Block Stage 5 progress (for that ticket only).

### Stage 5: Close (per ticket, local-first)

For each PASSed ticket, **in order**:

1. **Add regression evidence** (where feasible): the FE/BE Engineer adds a Maestro flow alongside the fix commit. If infrastructure is unavailable or impractical, note an N/A reason.

2. **Author comment body locally** (SSOT):
   - File: `qa-fix/jira-comments/<TICKET-ID>.md`
   - Template: `templates/qa-fix-comment.template.md`
   - **Field rules**:
     - Root Cause: 1 paragraph, no "Unknown".
     - Fix Summary: 1 paragraph, no raw diffs pasted in.
     - Verification Steps: at least 1 step, 1:1 mapped to the original repro.
     - Evidence: PR link always required; if regression/screenshots are missing, write "N/A — <reason>".
   - If any Evidence is partial, add a ⚠️ marker in the header.

3. **Extract KB candidate** (priority ∈ {P0, P1} only):
   - File: `qa-fix/kb-candidates/<TICKET-ID>.yaml`
   - Template: `templates/qa-fix-kb-candidate.template.yaml`
   - candidate_type classification:
     - `pattern_gap`: an area not in the existing KB.
     - `pattern_violation`: existing pattern violated.
     - `new_pattern`: subset of gap but a clear new pattern.
   - Skip KB candidates for P2/P3 (included only in Pattern Digest stats — at Retro).

4. **Post Jira comment** (when not dry-run):
   ```
   mcp__wrtn-mcp__jira_add_comment:
     issue_key: <TICKET-ID>
     body: <full content of jira-comments/<TICKET-ID>.md>
   ```
   On failure: 2 retries. If still failing, report to the user and block transition. Preserve the comment SSOT.

   **HTML comment stripping:** The local SSOT `<TICKET-ID>.md` template contains an HTML comment block (e.g., `<!-- PARTIAL EVIDENCE: ... -->`) that is for the Sprint Lead's reference only — it MUST NOT be posted to Jira. Before calling `mcp__wrtn-mcp__jira_add_comment`, strip all `<!-- ... -->` blocks (including multi-line ones) from the body. Sprint Lead is responsible for this transformation.

5. **Jira transition** (only on successful comment post):
   ```
   target_name = sprint-config.qa_fix.ready_for_qa_transition  # default "Ready for QA"
   transitions = mcp__wrtn-mcp__jira_get_transitions(issue_key)
   target = transitions.find(name=target_name)
   if target is None:
       # transition name mismatch — apply failure mode (see table below)
       fail_with("transition_name_not_found", available=transitions.map(t => t.name))
   mcp__wrtn-mcp__jira_transition_issue(issue_key, transition_id=target.id)
   ```

6. **Posted marker**:
   ```bash
   touch qa-fix/jira-comments/<TICKET-ID>.posted
   ```

**FAIL tickets**: skip Stage 5 entirely. Leave them in `unresolved.md` and don't touch Jira.

## Failure Modes

| Situation | Handling |
|-----------|----------|
| Evaluator FAIL still unresolved after 2 fix-loop iterations | Detach the ticket from the group, add to `unresolved.md`. Don't touch Jira. |
| Reporter does not respond to needs-info | Mark timeout in `triage.md`, defer to next round. No auto-close. |
| JQL returns 0 results | Exit immediately, report "no issues to process". Don't create retro.md. |
| Jira comment post failure | 2 retries → if still failing, report to user, block transition, no marker. |
| Jira transition failure (comment succeeded) | Preserve `<TICKET-ID>.md`, no marker. Report to user; auto-retry on next run. |
| transition_name_not_found (`ready_for_qa_transition` not in Jira workflow) | No marker. Present available transition names to user → instruct to update `sprint-config.qa_fix.ready_for_qa_transition` and rerun. |

## Budget Pressure

Same as the existing Build Loop policy (`phase-build.md` Section "Budget Pressure Protocol"):
- 🟢 Normal — proceed normally.
- 🟡 Caution (1 fix loop in the group) — propose deferring minor tickets.
- 🔴 Urgent (2 fix loops in the group) — propose group split / scope reduction to the user.

## Retro

After all groups close:

1. Write `qa-fix/retro.md` (template: `templates/qa-fix-retro.template.md`).

2. **Pattern Digest auto-derivation**: category distribution across all processed fixes (including P2/P3). If the same pattern is violated 3+ times, automatically add a "Reinforcement needed" notice.

3. **KB Candidate Review** — user approval gate:
   - Present each candidate as a row → approve / reject / merge-into-existing.
   - If approvals exceed 5, add a "merge top-N only" gate.
   - Approved candidates trigger `zachflow-kb:write-pattern` (use each candidate's `proposed_pattern` field as input — interface-aligned).

   **Status transitions from Retro decisions:**
   - User selects `approve` → candidate's `status:` becomes `approved`. Sprint Lead invokes `zachflow-kb:write-pattern` (flattening `proposed_pattern.*`).
   - User selects `reject` → candidate's `status:` becomes `rejected`. `review_notes:` records why.
   - User selects `merge-into:<existing-id>` → candidate's `status:` becomes `duplicate`, `related_existing_pattern:` is updated to the merge target. No `zachflow-kb:write-pattern` call.
   - All decisions persist the candidate file (rejected/duplicate are kept as audit trail).

4. **Deferred Index**: list of deferred + needs-info + unresolved tickets.

5. **Next Round Suggestion**: auto-generate a JQL for deferred + new P0/P1 tickets.

## Gate → Done

- [ ] `triage.md` has the user approval marker.
- [ ] Every in-scope ticket is classified as either closed (`.posted` exists) or unresolved.
- [ ] `retro.md` is generated and KB-candidate user decisions are recorded.
- [ ] (When not dry-run) For every closed ticket, both `<TICKET-ID>.md` and `<TICKET-ID>.posted` exist.

End on Gate pass. Print Sprint Status.

## Output

```
Sprint QA-Fix: <sprint-id>

  [Stage 1] Triage approved (in-scope: 8, deferred: 3, needs-info: 1, duplicate: 0)
  [Stage 2] Grouped into 3 groups
  [Group 001] PASSED — closed 3/3 (kb candidates: 2)
  [Group 002] PASSED — closed 2/3 (kb candidates: 1, unresolved: 1 → PROJ-145)
  [Group 003] PASSED — closed 2/2 (kb candidates: 0)
  [Retro] 3 KB candidates approved → merged into KB (correctness-021, integration-014, code_quality-009)

[Sprint Status Dashboard]
```
