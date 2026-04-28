---
name: qa-fix
description: Post-sprint Jira issue triage/fix workflow. After a sprint ends, process functional QA tickets in group units — triage, group, contract, implement+evaluate, close. Use when invoked as /qa-fix, or when /sprint --phase=qa-fix or --type=qa-fix is requested.
---

# qa-fix — Post-Sprint Jira Triage & Fix Pipeline

After a sprint ends (or as an integration round across multiple base branches), process Jira issue tickets discovered during functional QA in group units. The Build Loop (Stages 3~4) reuses the shared primitive in `_shared/build-loop.md`; only the entry/exit stages (1, 2, 5) are qa-fix-specific.

## Invocation

```
/qa-fix <run-id>                                  # Full pipeline (Stages 1~5 + Retro)
/qa-fix <run-id> --stage=triage                   # Stage 1 only
/qa-fix <run-id> --stage=grouping                 # Stage 2 only
/qa-fix <run-id> --stage=contract                 # Stage 3 only
/qa-fix <run-id> --stage=implement                # Stage 4 only
/qa-fix <run-id> --stage=close                    # Stage 5 only
/qa-fix <run-id> --status                         # Status dashboard
/qa-fix <run-id> --dry-run                        # No Jira writes; produce artifacts only
```

`--dry-run` blocks all Jira write calls (comment posting, transition, update). Only local artifacts are produced.

## Entry Paths

| Path | Trigger | Run Dir |
|------|---------|---------|
| **per-sprint** | `/sprint <sprint-id> --phase=qa-fix --jql="..."` | `runs/sprint/<sprint-id>/qa-fix/` |
| **integration** | `/qa-fix <run-id> --jql="..." --base-branches=...` | `runs/qa-fix/<run-id>/` |

The per-sprint path attaches the workflow as a `qa-fix/` subdirectory under an existing sprint run. The integration path creates a standalone run directory and skips Phases 2~3 entirely (no spec/prototype — direct entry into Stage 1).

## Directory Layout

```
runs/qa-fix/<run-id>/                          # integration path (per-sprint uses runs/sprint/<sprint-id>/qa-fix/)
├── jira-snapshot.yaml                          # Stage 1
├── triage.md                                   # Stage 1 (user approval gate)
├── groups/
│   └── group-<N>.yaml                          # Stage 2
├── contracts/group-<N>.md                      # Stage 3 (Build Loop output)
├── evaluations/group-<N>.md                    # Stage 4 (Build Loop output)
├── jira-comments/
│   ├── <TICKET-ID>.md                          # Stage 5 (local SSOT)
│   └── <TICKET-ID>.posted                      # Stage 5 (post+transition success marker)
├── kb-candidates/<TICKET-ID>.yaml              # Stage 5 (P0/P1 only)
├── unresolved.md                               # FAILED tickets
└── retro.md                                    # Retro
```

## Task Subject Naming

Consistent with `workflows/_shared/agent-team.md` conventions. The Sprint Lead uses these when dispatching subagent tasks per Stage:

| Stage | Subject pattern | Owner |
|-------|----------------|-------|
| Stage 1 Triage | `qa-triage/<run-id>` | Sprint Lead (self) |
| Stage 3 Contract | `qa-contract/<run-id>/group-<N>` | Sprint Lead → Evaluator review |
| Stage 4 Implement | `qa-fix/backend/<run-id>/group-<N>` | BE Engineer |
| Stage 4 Implement | `qa-fix/app/<run-id>/group-<N>` | FE Engineer |
| Stage 4 Evaluate | `qa-eval/<run-id>/group-<N>` | Evaluator |
| Stage 5 Close | `qa-close/<run-id>/<TICKET-ID>` | Sprint Lead (self) |

## 5-Stage Pipeline

| Stage | File | Owner | Purpose |
|-------|------|-------|---------|
| Stage 1: Fetch & Triage | [`stage-1-triage.md`](stage-1-triage.md) | Sprint Lead | JQL fetch, normalize, classify (in-scope / deferred / needs-info / duplicate), user approval gate |
| Stage 2: Grouping | [`stage-2-grouping.md`](stage-2-grouping.md) | Sprint Lead | Bundle approved tickets into 1~5-ticket groups by root cause / endpoint / module |
| Stage 3: Contract (per group) | [`stage-3-contract.md`](stage-3-contract.md) | Sprint Lead → Evaluator | Reuses Build Loop Contract Phase; Done Criteria framed as ticket repro success |
| Stage 4: Implement + Evaluate (per group) | [`stage-4-implement-eval.md`](stage-4-implement-eval.md) | BE/FE Engineer + Evaluator | Reuses Build Loop Implement/Merge/Evaluate/Fix phases; ticket-by-ticket verification |
| Stage 5: Close (per ticket) | [`stage-5-close.md`](stage-5-close.md) | Sprint Lead | Local-first comment SSOT, KB candidate extraction, Jira post+transition, posted marker |

After all groups close, write `retro.md` with Pattern Digest + KB Candidate Review (user approval gate) + Deferred Index + Next Round Suggestion.

## Shared Primitives

The qa-fix pipeline reuses the following shared primitives — never inline-duplicate their content:

| Primitive | File | Used by |
|-----------|------|---------|
| Build Loop (Contract → Implement → Merge → Evaluate → Fix) | [`../_shared/build-loop.md`](../_shared/build-loop.md) | Stage 3, Stage 4 |
| Agent team roles + dispatch protocol | [`../_shared/agent-team.md`](../_shared/agent-team.md) | Stages 3, 4 |
| Worktree setup + branch naming | [`../_shared/worktree.md`](../_shared/worktree.md) | Stage 4 |
| KB integration (sync/read/write) | [`../_shared/kb-integration.md`](../_shared/kb-integration.md) | Stage 3 (KB Pattern Auto-Injection), Stage 5 (KB candidate write), Retro |

## Budget Pressure

See [`../_shared/build-loop.md`](../_shared/build-loop.md) § Budget Pressure Protocol. Same level computation as the sprint Build Loop:
- 🟢 Normal — proceed normally.
- 🟡 Caution (1 fix loop in the group) — propose deferring minor tickets.
- 🔴 Urgent (2 fix loops in the group) — propose group split / scope reduction to the user.

## Failure Modes

| Situation | Handling |
|-----------|----------|
| Evaluator FAIL still unresolved after 2 fix-loop iterations | Detach the ticket from the group, add to `unresolved.md`. Don't touch Jira. |
| Reporter does not respond to needs-info | Mark timeout in `triage.md`, defer to next round. No auto-close. |
| JQL returns 0 results | Exit immediately, report "no issues to process". Don't create retro.md. |
| Jira comment post failure | 2 retries → if still failing, report to user, block transition, no marker. |
| Jira transition failure (comment succeeded) | Preserve `<TICKET-ID>.md`, no marker. Report to user; auto-retry on next run. |
| transition_name_not_found (`ready_for_qa_transition` not in Jira workflow) | No marker. Present available transition names to user → instruct to update `run-config.qa_fix.ready_for_qa_transition` and rerun. |

## Gate → Done

- [ ] `triage.md` has the user approval marker.
- [ ] Every in-scope ticket is classified as either closed (`.posted` exists) or unresolved.
- [ ] `retro.md` is generated and KB-candidate user decisions are recorded.
- [ ] (When not dry-run) For every closed ticket, both `<TICKET-ID>.md` and `<TICKET-ID>.posted` exist.

End on Gate pass. Print Status Dashboard.

## Output

```
QA-Fix Run: <run-id>

  [Stage 1] Triage approved (in-scope: 8, deferred: 3, needs-info: 1, duplicate: 0)
  [Stage 2] Grouped into 3 groups
  [Group 001] PASSED — closed 3/3 (kb candidates: 2)
  [Group 002] PASSED — closed 2/3 (kb candidates: 1, unresolved: 1 → PROJ-145)
  [Group 003] PASSED — closed 2/2 (kb candidates: 0)
  [Retro] 3 KB candidates approved → merged into KB (correctness-021, integration-014, code_quality-009)

[Status Dashboard]
```
