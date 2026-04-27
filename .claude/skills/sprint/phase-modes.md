# Sprint Modes: --continue, --follow-up, --status

---

## --continue Mode (continue within the same sprint)

Process only the unfulfilled items left over from a previously-completed sprint.

### Prerequisites

- `retrospective/` directory exists (Phase 6 must be complete)
- 1+ items in `deferred-items.yaml`
- Sprint branch is in a valid state

### Workflow

```
/sprint {sprint-id} --continue

1. Read retrospective/deferred-items.yaml
2. Form deferred items into new groups (start from last group number + 1)
3. Read original task specs of deferred items
4. Update task specs reflecting Evaluator feedback + suggested_approach
5. Re-enter Phase 4 (Build) loop — start from the new group
   ├─ 4.1 Contract (include prior failure cause + reinforced verification method)
   ├─ 4.2 Implement
   ├─ 4.3 Merge (merge additional commits onto the existing sprint branch)
   ├─ 4.4 Evaluate
   └─ 4.5 Fix/Accept
6. On completion: push additional commits to the existing PR or create a new PR (user choice)
7. Re-run Phase 6 (refresh gap-analysis)
```

### Contract Reinforcement

The `--continue` Sprint Contract includes prior failure context:

```markdown
# Sprint Contract: Group {N} (Continuation)

## Prior Context
- Original group: group-{M}
- Prior attempts: {N}
- Root cause: {from deferred-items.yaml}
- Evaluator feedback: {key feedback summary}

## Revised Approach
- {suggested_approach from deferred-items.yaml}

## Done Criteria
- [ ] {reinforced criterion 1}
- [ ] {reinforced criterion 2}
- [ ] Regression: previous group's implementation is unaffected

## Verification Method
- {Concrete verification method to avoid repeating prior failure}
```

### Output
```
Sprint Continue: {sprint-id}
  Deferred items: {N}
  New groups: {N} (group-{M+1} ~ group-{M+K})

  Entering Phase 4: Build (continuation)
```

---

## --follow-up Mode (follow-up sprint)

Create a new sprint based on the previous sprint's Retrospective artifacts.

### Invocation

```
/sprint {new-sprint-id} --follow-up={prev-sprint-id}
```

### Prerequisites

- The previous sprint's `retrospective/` directory exists
- The previous sprint's `deferred-items.yaml` or additional user requirements exist

### Workflow

#### Phase 1: Init (extended)

Add to the existing Init:

```
1. Read the previous sprint's retrospective/:
   - gap-analysis.yaml → list of unfulfilled AC
   - pattern-digest.yaml → systemic patterns + metrics
   - deferred-items.yaml → carry-over items
2. Copy the previous sprint's api-contract.yaml (extend on this base)
3. Record follow-up metadata
```

Add to the directory:
```
sprints/{new-sprint-id}/
├── ... (existing structure)
└── follow-up-context.yaml       # links back to previous sprint
```

```yaml
# follow-up-context.yaml
previous_sprint: "{prev-sprint-id}"
inherited_from:
  deferred_items: {N}
  api_contract: true
  patterns: {N}
previous_metrics:
  fulfillment_rate: {0.0~1.0}
  first_pass_rate: {0.0~1.0}
  avg_fix_cycles: {N.N}
```

#### Phase 2: Spec (extended)

Add to the existing Spec:

1. **Generate Delta PRD**: a PRD integrating previous PRD + carry-over items + improvements.

```markdown
# Delta PRD: {new-sprint-id}

## Prior Sprint
- Sprint: {prev-sprint-id}
- Coverage: {fulfilled}/{total_ac} AC fulfilled
- Gap Analysis: {prev-sprint}/retrospective/gap-analysis.yaml

## Carry-over Items (Deferred from {prev-sprint-id})
### AC-{N}: {AC title}
- Cause: {root_cause}
- Prior approach: {prior attempts summary}
- Reinforced approach: {suggested_approach}
- Reinforced AC: {refined acceptance criteria}

## Improvements
{Confirm additional requirements with the user — proceed with carry-over only if none}

## Regression Guard
Verify that work completed in the previous sprint isn't broken by follow-up work:
- [ ] AC-001 ~ AC-{M}: no regression of previously fulfilled items
```

2. **Evaluator calibration reinforcement (auto-query KB)**:

Look up the KB pattern index to auto-reinforce evaluation criteria.

```
1. `zachflow-kb:read type=pattern` to load all patterns (or narrow by category filter)
2. Filter to severity: critical OR (severity: major AND frequency >= 2)
3. Read each pattern's .yaml file from its path
4. Add each pattern's detection + contract_clause to evaluation/criteria.md:

## KB-Calibrated Checks (from {prev-sprint-id} + accumulated KB)
- Pattern: {title} (KB: {pattern-id}, freq: {N})
  Detection: {detection field summary}
  Contract clause: {contract_clause}
```

Keep the existing pattern-digest-based calibration, but apply KB first since it's more comprehensive:
- Pattern present in both KB and pattern-digest → use the KB version (frequency reflected).
- Pattern only in pattern-digest → add as before.

3. **Generate Regression AC**: a simplified regression checklist of previously fulfilled AC.

```yaml
# Add to each tasks/{project}/{task-id}.md AC section
## Regression Guard
- [ ] {prior AC-001}: {verification method — confirm existing behavior}
- [ ] {prior AC-002}: {verification method}
```

#### Phase 3~5: same as before

#### Phase 6: Retrospective (extended)

Add to the existing Retrospective:
- Record improvement trend vs prior sprint
- Track resolution of carry-over items

```yaml
# Add to gap-analysis.yaml
follow_up_tracking:
  previous_sprint: "{prev-sprint-id}"
  inherited_deferred: {N}
  resolved_in_this_sprint: {N}
  still_deferred: {N}
  trend:
    fulfillment_rate: "{prev} → {current}"
    first_pass_rate: "{prev} → {current}"
```

### Output
```
Sprint Follow-Up Init: {new-sprint-id}
  Based on: {prev-sprint-id}
  Inherited: {N} deferred items, {N} patterns
  API Contract: inherited + extended

→ Proceeding to Phase 2: Spec (Delta PRD)
```

---

## --status Mode (auto + manual)

### Automatic Output

The `--status` dashboard prints automatically on every Phase Gate pass. In the Build Phase, it also prints on each Group completion. No separate invocation is needed.

### Live Monitoring in a Separate Terminal

For real-time monitoring, run sprint-monitor.sh in a separate terminal:

```bash
./scripts/sprint-monitor.sh {sprint-id}
```

This refreshes Agent Activity, Group state, Checkpoints, and the Hook Event Log every 2 seconds. Exit with `Ctrl+C`.

### Manual Invocation

You can still invoke `--status` manually:

```bash
/sprint {sprint-id} --status
```

### Hook-Based Event Capture

`scripts/hook-handler.sh` records the following events automatically via Claude Code Hooks:

| Hook Event | Recorded |
|------------|----------|
| `SubagentStart` | teammate activation (agent_id, agent_type) |
| `SubagentStop` | teammate exit (agent_id, agent_type) |
| `TaskCreated` | task assignment (task_id, subject, teammate) |
| `TaskCompleted` | task completion (task_id, subject, teammate) |

Events are recorded in `logs/events.jsonl`, alongside existing manual agent logging (`logs/{agent}.jsonl`). Hook events handle teammate lifecycle; manual logging handles implementation phase detail.

### Information Sources

1. **Task status**: TaskList or result files
2. **Prototype status**: `approval-status.yaml`
3. **Sprint Contract status**: `contracts/` directory
4. **Evaluation status**: `evaluations/` directory
5. **Branch status**: commit count on the sprint branch
6. **PR status**: `gh pr list`
7. **Agent Activity**: `logs/*.jsonl` — parse the last line of each agent's JSONL file
8. **Retrospective status**: existence of `retrospective/` + gap-analysis summary
9. **Checkpoint status**: `checkpoints/` directory — list of created checkpoints

### Log Parsing

Parse JSONL files in `sprint-orchestrator/sprints/{sprint-id}/logs/`:

1. For each agent file (`be-engineer.jsonl`, `fe-engineer.jsonl`, `design-engineer.jsonl`, `evaluator.jsonl`), read the **last line**.
2. Parse JSON to extract `task`, `phase`, `message`, `ts`.
3. Compute elapsed time from `ts`.
4. Map `phase` → Display Status:

| phase | Display |
|-------|---------|
| `started`, `context_loaded` | LOADING |
| `worktree_created`, `implementing`, `html_generating`, `evaluating`, `fixing` | ACTIVE |
| `build_check` | BUILDING |
| `build_failed` | BUILD FAIL |
| `html_complete` | SAVING |
| `completed` | IDLE (the agent is currently waiting if the last log is completed) |
| `error` | ERROR |

5. If no log file exists or it is empty, display **IDLE** (agent not yet activated).

### Dashboard Output

```
═══════════════════════════════════════════════════════
  Sprint: {sprint-id}
  PRD: {prd-source}
  Architecture: Planner-Generator-Evaluator
═══════════════════════════════════════════════════════

  Build Progress: ████████░░░░ Group {N}/{M}

  Group   Contract   Backend         App             Evaluation
  ─────   ────────   ────────────    ────────────    ──────────
  001     agreed     COMPLETED       COMPLETED       PASS
  002     agreed     COMPLETED       RUNNING         pending
  003     draft      pending         pending         —

  ─── Agent Activity ───────────────────────────────────
  Agent              Task                    Phase        Elapsed   Detail
  ────────────────   ─────────────────────   ──────────   ───────   ──────────────────────
  BE Engineer        impl/backend/002-api    BUILDING     2m ago    tsc --noEmit
  FE Engineer        impl/app/002-ui         ACTIVE       5m ago    creating FollowerList component
  Design Engineer    —                       IDLE         —         —
  Evaluator          —                       IDLE         —         —

  Prototypes:
    001-profile-screen    ProfileScreen     approved
    002-follow-ui         FollowerListScreen approved

  PRs:
    backend:  not created
    app:      not created

  ─── Checkpoints ────────────────────────────────────
  phase-2-summary.md    ✓
  phase-3-summary.md    ✓
  group-001-summary.md  ✓
  group-002-summary.md  —

  ─── Bottleneck Detection ────────────────────────────
  ⚠ FE Engineer ACTIVE for 15m+ on impl/app/002-ui (threshold: 10m)
  ⚠ Group 002 blocked: waiting for FE completion

═══════════════════════════════════════════════════════
  Next step: {context-aware suggestion}
═══════════════════════════════════════════════════════
```

### Bottleneck Detection Rules

| Condition | Warning |
|-----------|---------|
| Agent ACTIVE for 10m+ | `⚠ {Agent} ACTIVE for {N}m+ on {task}` |
| Agent BUILD FAIL state | `🔴 {Agent} build failed on {task}` |
| Agent ERROR state | `🔴 {Agent} error on {task}` |
| One side complete in a group, the other side 5m+ idle | `⚠ Group {N} blocked: waiting for {side}` |
| Entering fix loop iteration 2 | `⚠ Group {N} in fix loop round 2` |

### Progress Calculation

```
progress = (accepted_groups / total_groups) * 100
bar_filled = round(progress / 100 * 12)
```

### Next Step Logic

State-based auto recommendation:
- All groups ACCEPTED → "Ready for Phase 5: PR"
- Group currently being evaluated → "Waiting for Evaluator on Group {N}"
- In fix loop → "Fix loop round {R} for Group {N}"
- FAILED group exists → "Group {N} FAILED — user decision required"
- Implementation in progress → "Engineers working on Group {N}"
- PR created, retrospective not yet run → "Ready for Phase 6: Retrospective"
- Retrospective complete, deferred exists → "`--continue` or `--follow-up` recommended"
- Retrospective complete, all fulfilled → "Sprint complete. All AC fulfilled."

### Auto Monitoring

Auto-output on Phase transitions + a separate-terminal monitor:

```bash
# Live monitor in a separate terminal (recommended)
./scripts/sprint-monitor.sh {sprint-id}

# Or the existing /loop approach
/loop 3m /sprint {sprint-id} --status
```
