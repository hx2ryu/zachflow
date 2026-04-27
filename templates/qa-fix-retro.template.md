# QA-Fix Retro — <sprint-id>

**Generated at:** <ISO timestamp>
**Round entry path:** per-sprint | integration
**Triage approved at:** <triage.md timestamp>

## Health Score

| Outcome | Count |
|---------|-------|
| PASS (closed in Jira) | <n> |
| FAILED (in unresolved.md) | <n> |
| DEFERRED (from triage) | <n> |
| NEEDS-INFO (awaiting reporter) | <n> |
| DUPLICATE | <n> |

**Total in-scope:** <n>
**Pass rate:** <n%>
**Fix loop budget:** <total fix-loop iterations across groups>

## Pattern Digest (all severities)

For trend tracking. Includes P2/P3 even though they don't generate KB candidates.

| Category | Count | Notes |
|----------|-------|-------|
| correctness | <n> | <if any pattern_violation triggered "reinforcement needed", flag here> |
| integration | <n> | |
| code_quality | <n> | |
| edge_case | <n> | |
| design_proto | <n> | |
| design_spec | <n> | |
| completeness | <n> | |

## KB Candidates Review

> **User action required:** For each P0/P1 candidate, choose one decision below. After your decisions, the Sprint Lead invokes `zachflow-kb:write-pattern` for each `approved` candidate.

| Candidate File | Ticket | Pri | Title | Type | Decision |
|----------------|--------|-----|-------|------|----------|
| `kb-candidates/PROJ-123.yaml` | PROJ-123 | P0 | <title> | pattern_gap | [ ] approve / [ ] reject / [ ] merge-into:<existing-id> |

**Reinforcement alerts** (auto-detected — same pattern violated 3+ times this round):
- `<existing-pattern-id>`: violated in tickets <T1>, <T2>, <T3> → consider revising the pattern's `detection` or `prevention`.

**Volume gate:** If approved count > 5, user is asked to pick top-N before merge.

## Deferred Index

For next-round planning.

| Ticket | Pri | Summary | Defer Reason | Next Round Candidate |
|--------|-----|---------|--------------|----------------------|
| PROJ-456 | P3 | <summary> | <reason> | yes/no |

## Unresolved

Tickets that exhausted fix loop (2 rounds) without PASS. Jira not transitioned. Human intervention required.

| Ticket | Pri | Summary | Last Evaluator Verdict | Suggested Next Action |
|--------|-----|---------|------------------------|----------------------|
| PROJ-789 | P1 | <summary> | <verdict summary> | <reassignment / scope-cut / external dep> |

## Next Round Suggestion

Generated JQL for the next QA-Fix round (deferred + new since this snapshot).

```
project = <PROJECT> AND (key in (<deferred keys>) OR (created > "<this snapshot_at>" AND priority in (P0, P1)))
```
