# Stage 2: Grouping

Sprint Lead self-task. Bundle the approved in-scope tickets into groups for the Build Loop. See [`SKILL.md`](SKILL.md) for invocation context.

## Input

- `runs/qa-fix/<run-id>/triage.md` with `[x] **Approved by user**` marker.
- `runs/qa-fix/<run-id>/jira-snapshot.yaml`.

## Grouping Criteria

Apply in priority order:

1. **Suspected same root cause** — one fix can resolve many tickets.
2. **Same backend endpoint** — avoid contract conflicts when fixing in parallel.
3. **Same screen / module** — avoid UI conflicts when fixing in parallel.

## Group Size Constraint

Each group: **1~5 tickets**.

- Single-ticket groups are allowed when no clustering applies.
- If the resulting number of groups is too large (>5), suggest to the user that the run proceed with only the **top-N priority groups** for this iteration. Remaining groups roll over to the next round (recorded in the Deferred Index at Retro).

## Output

For each group, write `runs/qa-fix/<run-id>/groups/group-<N>.yaml` (template: `templates/qa-fix-group.template.yaml`).

Group numbering: `001`, `002`, `003`, ... in priority order (P0-heavy first; ties broken by suspected-root-cause cluster size).

## Gate → Stage 3

- [ ] Every approved in-scope ticket is assigned to **exactly one** group. Unassigned tickets move to deferred and are recorded in `triage.md`.
- [ ] No group exceeds 5 tickets.
- [ ] Group YAML files exist for `001` through `<N>`.

---
← Prev: [`stage-1-triage.md`](stage-1-triage.md)  ·  → Next: [`stage-3-contract.md`](stage-3-contract.md)
