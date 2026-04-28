# Stage 1: Fetch & Triage

Sprint Lead self-task. First stage of the qa-fix pipeline. See [`SKILL.md`](SKILL.md) for invocation context.

## 1. Jira Fetch

Sprint Lead fetches from Jira using the JQL passed via CLI argument or `run-config.qa_fix.jql`:

```
mcp__wrtn-mcp__jira_search_issues:
  jql: <CLI argument or run-config.qa_fix.jql>
  fields: [summary, priority, issuetype, status, reporter, assignee, labels, components, fixVersions, created, description]
```

## 2. Idempotency Check

If a returned ticket already has `runs/qa-fix/<run-id>/jira-comments/<key>.posted` marker, the ticket has already been closed in a prior run. **Auto-exclude** from this run before any further processing.

## 3. Write Snapshot

Write `runs/qa-fix/<run-id>/jira-snapshot.yaml` (template: `templates/qa-fix-jira-snapshot.template.yaml`).

**Ticket `type` enum mapping** — the snapshot's `type` field uses a normalized enum (`Bug | UX | Perf | Copy | Other`), not the raw Jira `issuetype.name`. Map as follows:

| Jira issuetype | Normalized `type` |
|----------------|-------------------|
| Bug | `Bug` |
| Story / Task containing UI/visual concerns | `UX` |
| Performance / load issues | `Perf` |
| Copy / text / typo | `Copy` |
| Everything else | `Other` |

The triage and group templates use this same normalized enum.

**Ticket `priority` enum mapping** — the snapshot's `priority` field uses a normalized enum (`P0 | P1 | P2 | P3`), not Jira's raw `priority.name`. Map as follows:

| Jira priority | Normalized `priority` |
|---------------|-----------------------|
| Highest | `P0` |
| High | `P1` |
| Medium | `P2` |
| Low / Lowest | `P3` |

If the project's Jira workflow uses different priority names, document the mapping as a comment in `run-config.yaml` (no separate config field). All triage/KB-candidate logic downstream uses these P-values.

## 4. Auto-Classification

Classify each ticket into one of 4 buckets:

- **in-scope**: priority ∈ {P0, P1, P2}, status open-like, summary clear, related to the same scope as this run.
- **deferred**: priority = P3, OR scope outside this round.
- **needs-info**: no repro steps in the description, or missing key info (build number, device, user ID, etc.).
- **duplicate**: another open ticket appears to share the same root cause.

**Classification heuristics are not deterministic** — explicitly note the Sprint Lead's judgment in `triage.md`. The user can promote/demote items in the approval step.

## 5. Write Triage Document

Write `runs/qa-fix/<run-id>/triage.md` (template: `templates/qa-fix-triage.template.md`).

## 6. User Approval Gate

Before any destructive Jira write, present `triage.md` to the user and wait until the marker

```
[x] **Approved by user** — proceed to Stage 2 (Grouping)
```

is filled in (with an ISO 8601 timestamp). The user can edit the in-scope list — promote/demote, move needs-info → in-scope, move duplicate → in-scope, etc.

**Approval marker semantics**: Sprint Lead detects approval by grep-ing for `[x] **Approved by user**` in `triage.md`. Once detected, the Sprint Lead fills `Approved at:` with the current ISO 8601 timestamp before proceeding. If the user edits the lists, **the final classification** becomes the target of subsequent Jira writes.

## 7. Handle needs-info Tickets

After approval (and only when not `--dry-run`):

```
For each needs-info ticket in approved triage.md:
  mcp__wrtn-mcp__jira_add_comment:
    issue_key: <key>
    body: "QA Triage — additional info needed: <specific question>"
```

Record the actually-posted text in `triage.md`'s "Question Posted" column.

## 8. Handle duplicate Tickets

After approval (and only when not `--dry-run`):

```
For each duplicate ticket in approved triage.md:
  mcp__wrtn-mcp__jira_add_comment: "Duplicate of <master-key>"
  mcp__wrtn-mcp__jira_transition_issue: <to "Closed" with resolution=Duplicate>
```

## Stage Ordering Enforcement (steps 6 → 7, 8)

Why ordering is enforced: since the user can adjust needs-info/duplicate classifications during the triage approval step, Jira writes only apply to the **approved final classification**. Posting comments/transitions before approval can leave wrong comments on tickets the user later promoted.

**Hard rule**: do not call any Jira write API (comment, transition, update) for needs-info or duplicate tickets until the `[x] **Approved by user**` marker is detected in `triage.md`.

## Gate → Stage 2

- [ ] `jira-snapshot.yaml` exists with normalized `type` + `priority` enums.
- [ ] `triage.md` has the user approval marker with an ISO 8601 timestamp.
- [ ] needs-info comments posted (or skipped under `--dry-run`).
- [ ] duplicate tickets transitioned (or skipped under `--dry-run`).

---
→ Next: [`stage-2-grouping.md`](stage-2-grouping.md)
