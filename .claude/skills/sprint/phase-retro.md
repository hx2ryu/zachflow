# Phase 6: Retrospective (Sprint Lead solo)

After PR creation, analyze sprint outcomes and produce structured artifacts for follow-up work.

## Auto-Trigger

Runs automatically after Phase 5 completes. Can also be invoked standalone with `--phase=retro`.

## Workflow

### 6.0 KB Sync

Phase 6 performs bulk writes to the KB (pattern write/update, reflection, promote-rubric), so call `zachflow-kb:sync` before the first write to fast-forward against origin/main. This avoids push conflicts. Even if Phase 4 already synced, recommend re-syncing for long-running sprints.

### 6.1 Gap Analysis (PRD AC fulfillment)

Iterate every Acceptance Criterion in PRD.md and cross-check Evaluator reports + task statuses.

```
For each AC in PRD:
  1. Identify the implementing task (AC mapping in tasks/*.md)
  2. Check task status: COMPLETED / FAILED
  3. If COMPLETED: check related issues in evaluations/group-{N}.md
  4. Verdict: fulfilled / partially_fulfilled / unfulfilled
  5. Classify root_cause: spec_ambiguity / technical_limit / dependency / scope_creep
```

Save: `sprints/{sprint-id}/retrospective/gap-analysis.yaml`

```yaml
sprint_id: "{sprint-id}"
prd_source: "{prd-file}"
generated_at: "{ISO8601}"

coverage:
  total_ac: {N}
  fulfilled: {N}
  partially_fulfilled: {N}
  unfulfilled: {N}
  fulfillment_rate: "{fulfilled / total_ac}"

prototype_amendments:
  total: {N}
  applied: {N}
  deferred: {N}
  dismissed: {N}
  categories:
    new_ac: {N}
    clarify_ac: {N}
    add_ui_spec: {N}
    implicit_req: {N}
    add_rule: {N}

items:
  - ac_id: "AC-{N}"
    ac_text: "{original AC text}"
    task_id: "{implementing task}"
    group: "group-{N}"
    status: "{fulfilled | partially_fulfilled | unfulfilled}"
    reason: "{detail}"
    evidence: "{evaluations/group-{N}.md#issue-{N} | null}"
    root_cause: "{spec_ambiguity | technical_limit | dependency | scope_creep | null}"
    recommendation: "{follow-up suggestion}"
    priority: "{critical | high | medium | low}"
```

### 6.2 Pattern Digest (recurring failure patterns)

Cross-analyze every Evaluator report to extract systemic patterns.

```
1. Read all evaluations/group-*.md
2. Group issues by category: correctness / completeness / edge_case / integration / code_quality
3. Identify patterns recurring across 2+ groups
4. Derive systemic improvement proposals
```

Save: `sprints/{sprint-id}/retrospective/pattern-digest.yaml`

```yaml
patterns:
  - pattern: "{recurring pattern description}"
    category: "{correctness | completeness | edge_case | integration | code_quality}"
    frequency: {N}
    groups: ["group-{N}", ...]
    severity: "{critical | major | minor}"
    systemic_fix: "{system-level remediation}"

metrics:
  total_groups: {N}
  first_pass_rate: {0.0~1.0}       # ratio that PASSed on first evaluation
  avg_fix_cycles: {N.N}            # average fix-loop iterations
  critical_issues_found: {N}
  major_issues_found: {N}
  minor_issues_found: {N}
  issues_fixed: {N}
  issues_deferred: {N}
```

### 6.3 Deferral Index

Structure items from gap-analysis with `unfulfilled` or `partially_fulfilled`.

Save: `sprints/{sprint-id}/retrospective/deferred-items.yaml`

```yaml
deferred:
  - ac_id: "AC-{N}"
    original_task: "{task file path}"
    group: "group-{N}"
    status: "{unfulfilled | partially_fulfilled}"
    reason: "{why unmet}"
    root_cause: "{spec_ambiguity | technical_limit | dependency | scope_creep}"
    prior_attempts: {N}
    evaluator_notes: "{evaluations reference}"
    suggested_approach: "{approach for next attempt}"
    priority: "{critical | high | medium | low}"
    estimated_complexity: "{small | medium | large}"

improvements:
  - description: "{user feedback or further improvement}"
    source: "{user_feedback | pattern_digest | evaluator_suggestion}"
    priority: "{high | medium | low}"
```

### 6.4 Sprint Report

Integrate all retrospective artifacts and generate `REPORT.md`.

Save: `sprints/{sprint-id}/REPORT.md`

```markdown
# Sprint Report: {sprint-id}

> Generated: {date}
> Architecture: Planner-Generator-Evaluator (Harness Design)
> PRD: {prd-source}

## Executive Summary
{1-2 sentence summary: what was implemented and the outcome}

## PRD Coverage
| User Story | AC Count | Fulfilled | Unfulfilled |
{aggregate per US from gap-analysis.yaml}
**Fulfillment Rate: {rate}%**

## Build Results
| Group | Feature | BE Task | FE Task | Eval Result | Fix Loops |
{per-group results}

## Quality Metrics
| Metric | Value |
{metrics section from pattern-digest.yaml}

## Issues Found by Evaluator
### Critical
{issue table: Group, Issue, Root Cause, Resolution}
### Major
{issue table}
### Minor
{issue table}

## Systemic Patterns
{pattern-digest.yaml patterns rendered as prose}

## Deliverables
### Code
| Repository | Branch | Base | Files | Lines |
### New Modules / Screens / Components
{list of implemented modules, screens, components}
### API Contract
{endpoint count, file path}
### Sprint Artifacts
{contract count, DC count, evaluation report count}

## PR Links
| Repository | Status | Link |

## Improvements for Next Sprint
| Priority | Improvement | Source |
{improvements section from deferred-items.yaml}

## Timeline
| Phase | Duration | Notes |
{per-phase duration}
```

### 6.5 Suggest the user's Next Action

Branch on gap-analysis results:

| State | Suggestion |
|-------|------------|
| fulfillment_rate = 1.0 | "All AC fulfilled. Sprint complete." |
| 1-2 deferred (small) | "Recommend `--continue` to extend within the same sprint" |
| 3+ deferred or large | "Recommend `--follow-up` to create a follow-up sprint" |
| Many root_cause = spec_ambiguity | "Recommend rewriting PRD/task spec, then a follow-up sprint" |
| systemic_fix exists | "Recommend systemic improvement first, then a follow-up sprint" |

### 6.6 Design System Update Review

If the sprint introduced new components, screens, or interaction patterns, review whether the design system docs need updating.

- **Update triggers**: new component tokens, patterns that violate existing Do's/Don'ts, design system changes.
- **Update method** (depending on whether DESIGN.md is present):
  - `docs/designs/DESIGN.md` exists: run `/extract-design --update` → diff against existing DESIGN.md → apply after user confirmation.
  - Absent: directly add/update entries in `docs/designs/foundations/*.mdx` or `components/*.mdx` (Zod frontmatter — build verifies). New components require a `<key>.mdx` + `<key>.demo.html` pair.
  - DESIGN.md can be generated later via `/extract-design` if needed.
- **Skip condition**: skip when only existing components are used and there are no design system changes.

### 6.7 Knowledge Base Write (3-track promotion ritual)

> Ref: Hermes / Reflexion / DSPy — record sprint learning in the KB so the next sprint actually consumes it.
>
> 6.7 has 4 sub-steps:
> - **6.7a Rubric Promotion**: pattern → Evaluator rubric clause
> - **6.7b Skill Promotion** (placeholder, implemented in Phase B): pattern → reusable code skill
> - **6.7c Rule Promotion**: user feedback → permanent rule
> - **6.7d Reflection**: Reflexion-style 1-page natural-language retrospective
>
> The 6.7 main body below (Pattern KB Write) is the common foundation for the 4 steps; each promotion step runs sequentially after the main body.

Record Pattern Digest + Quality Report into the KB.

**Workflow**:

```
1. Read pattern-digest.yaml
2. For each pattern in pattern-digest:
   a. Match search: `zachflow-kb:read type=pattern category={category}` → Read returned files and
      determine match against existing patterns by title/description similarity
   b. Match found:
      - `zachflow-kb:update-pattern id={existing-id} source_sprint={current sprint-id}`
        (the skill handles frequency+1 + last_seen update + rebase-retry push)
   c. No match (new):
      - Call `zachflow-kb:write-pattern` with field mapping:
        - category: pattern-digest's category as-is
        - severity: pattern-digest's severity
        - title: pattern-digest's pattern summary (≤120 chars)
        - source_sprint: current sprint-id
        - source_group: pattern-digest.groups[0] (first observed group)
        - description: pattern-digest's pattern field
        - detection: how the pattern surfaced this sprint (≥10 chars)
        - prevention: pattern-digest's systemic_fix → preventive sentence (≥10 chars)
        - contract_clause: derive a Contract clause from systemic_fix (≥10 chars; if unclear, use the minimum description)
        (the skill auto-numbers the next ID + schema validation + commit/push)
3. Read prototypes/quality-report.yaml (if present)
4. fabrication_risk: medium items follow the same procedure under
   `category: design_proto` or `design_spec` (no separate store — common axis-1 `learning/patterns/`)
```

> **Note**: A standalone KB has no separate pattern index README. Match against `zachflow-kb:read`
> results by directly Reading them. The `groups` array field does not exist in the current pattern schema
> (see schemas/learning/pattern.schema.json), so do not accumulate it. Repeated observations are
> represented only by the `frequency` counter.

**Design Engineer pattern recording**:

Recurring quality issues from prototypes are also recorded in the KB:

| Signal | Design KB pattern |
|--------|--------------------|
| Same revision reason recurs 2+ times | `design-proto-{NNN}`: recurring revision pattern |
| fabrication_risk: medium + approved | `design-spec-{NNN}`: PRD implicit requirement |
| quality_score.extraction_accuracy < 0.8 | `design-spec-{NNN}`: extraction accuracy needs improvement |

**Nudge mechanism**:

After producing retrospective artifacts, check the following conditions:

```
if new_patterns_count >= 2:
    To user: "{N} new patterns discovered this sprint, recorded in KB.
    They will be auto-applied to the next sprint's Contract/Evaluation."

if any pattern.frequency >= 3:
    To user: "⚠ Pattern '{title}' has recurred across {N} sprints.
    Recommend permanent inclusion in the Sprint Contract template."
    → On user approval, add the clause to sprint-contract-template.md
```

**Append to output** (within the existing Phase 6 Output block):
```
  KB Update:
    Patterns updated: {N} (existing: {M} updated, new: {K} created)
    Design patterns: {N}
    Template nudge: {show if any, omit if none}
```

### 6.7a Rubric Promotion (Pattern → Evaluator Rubric Clause)

> Ref: ExpeL — accumulate cross-task insight into the evaluation rubric.

**Trigger**: patterns in pattern-digest with `frequency >= 2` and a defined `contract_clause`.

**Workflow**:
1. Check the active rubric: `zachflow-kb:read type=rubric status=active` (return the latest v(N) path only — content reading is handled by the skill in step 2).
2. **Add a Promotion Log row (skill):**
   `zachflow-kb:promote-rubric source_sprint=<current-sprint-id> source_pattern=<pattern-id> clause_id=C<next-number> clause_title="<short title>"`
   (the skill handles row insertion + `validate:content` + rebase-retry push + cumulative-count nudge)
3. Branch on the skill's nudge result:
   - **Cumulative `< 2`**: only append. The clause is not yet inlined into the body, but next sprint prioritizes evaluation if the same pattern recurs.
   - **Cumulative `>= 2`**: create a new v(N+1) file (**currently a manual direct op** — see note below).
     Write `$KB_PATH/learning/rubrics/v{N+1}.md`:
     - Frontmatter: `version: N+1`, `status: active`, `superseded_by: null`, `schema_version: 1`
     - Body: all clauses from v(N) + clauses from the cumulative Promotion Log inlined into the Clauses section
     - Promotion Log: keep only the baseline row (empty otherwise)
     - Update v(N) frontmatter to `status: superseded` + `superseded_by: N+1`
     - `cd $KB_PATH && git add learning/rubrics/ && git commit -m "rubric: bump to vN+1 ({sprint-id})" && git pull --rebase origin main && git push`
4. User nudge:
   ```
   Rubric: keep v{N} (promotion log {N} accumulated) | create v{N+1} (inline {N} clauses)
   ```

**Effect**: In the next sprint's Phase 4.4, the Evaluator auto-loads the latest vN → applies the accumulated criteria.

> **Note (rubric version bump skill not yet provided)**: `zachflow-kb:promote-rubric` covers only
> Promotion Log row insertion (records short `clause_title` text only). The v(N) → v(N+1) promotion
> requires the full clause body, so no skill exists yet — perform via direct git op in step 3's
> cumulative `>= 2` branch. A future `zachflow-kb:bump-rubric` (taking a clauses array as input
> for body migration) is under consideration. When doing the direct op, rebase-retry is required.

### 6.7b Skill Promotion (Pattern → Reusable Code Skill)

> This step is a **placeholder**. Implemented in Phase B (skill library construction).
>
> Trigger conditions only defined for now:
> - Same code pattern is implemented across 2+ groups.
> - 90%+ identical structure across Generator-written code.

For now, only tag matching items in Pattern Digest with `skill_candidate: true` and pass through without writing to the KB.

### 6.7c Rule Promotion (User Feedback → Permanent Rule)

> Ref: Cursor Rules / Claude Code CLAUDE.md auto-promotion.

**Trigger**: User provides the same correction 2+ times during the sprint.

**Workflow**:
1. Extract `source: user_feedback` items from `deferred-items.yaml`'s `improvements` section.
2. Check if the same/similar feedback already exists in the previous sprint's reflection "What failed" or in KB rules.
3. New + frequency 2+ items → present to the user as candidates for adding `feedback_*.md` to the `MEMORY.md` index:
   ```
   ⚠ User feedback "{summary}" repeated {N} times.
   → Promote to memory/feedback_{slug}.md? (y/n)
   ```
4. On user approval, follow the auto-memory guide procedure to create the file (with frontmatter) and update the MEMORY.md index.

### 6.7d Reflection (Reflexion-style 1-page retrospective)

> Ref: Reflexion (Shinn 2023) — inject natural-language self-reflection into the next attempt.

**Trigger**: Always run in Phase 6 (do not skip — the next sprint's Phase 2 depends on it).

**Workflow**:
1. Read `pattern-digest.yaml` + `gap-analysis.yaml`.
2. Check the previous sprint (same domain) reflection: `zachflow-kb:read type=reflection domain=<domain> limit=1`
   (if present, retain the Read result for step 3's "reflection-degree" line).
3. Call `zachflow-kb:write-reflection` (schema: `$KB_PATH/schemas/learning/reflection.schema.json`):
   - `sprint_id`: current sprint-id
   - `domain`: one of the configured domains (enum; schema-enforced)
   - `completed_at`: current ISO 8601 with offset
   - `outcome`: `pass | fail | partial` — based on gap-analysis fulfillment_rate
     (`= 1.0` → pass / `>= 0.7` → partial / `< 0.7` → fail. Confirm team conventions.)
   - `related_patterns`: array of pattern ids written/updated this sprint
   - `body` (≤ 400 words, markdown):
     - **What worked**: 2-3 success factors from PASS groups (in reusable form)
     - **What failed (with root cause)**: one-line trace + root_cause for ISSUES/FAIL items
     - **Lesson (next-sprint actionable)**: concrete guidance to apply in the next sprint's Phase 2/4
     - **Pointers**: references to pattern-digest, gap-analysis, KB pattern ids
     - (If the previous reflection existed in step 2) closing line:
       `> Prior lesson reflected: {fully | partially | not} — {brief assessment}`
   (the skill handles schema validation + rebase-retry push)

**Output update** (Phase 6 Output block):
```
  Promotions:
    Rubric: {keep v(N) | create v(N+1), {K} clauses inlined}
    Skill candidates: {N} (placeholder)
    Rule promotions: {N}
    Reflection: $KB_PATH/learning/reflections/{sprint-id}.md
```

## Cleanup (optional, manual)

After the sprint is fully closed and all PRs are merged, clean up worktrees and the sprint branch. **Not auto-run** — the user runs it after confirming PR merges.

```bash
./scripts/cleanup-sprint.sh --config sprint-orchestrator/sprints/{sprint-id}/sprint-config.yaml --delete-branch
```

- Loops over the `repositories` map and removes each role directory (worktree/symlink).
- With `--delete-branch`, also delete the merged `{branch_prefix}/{sprint-id}` branch from the source repo (uses `git branch -d`, which only succeeds on fast-forward).

## Gate

Phase 6 is the final stage, so it has no gate. End on artifact generation.

## Output
```
Sprint Retrospective: {sprint-id}

  PRD Coverage: {fulfilled}/{total_ac} AC fulfilled ({fulfillment_rate}%)
    Fulfilled:           {N}
    Partially fulfilled: {N}
    Unfulfilled:         {N}

  Build Quality:
    First-pass rate:     {N}% ({N}/{M} groups PASS on first eval)
    Avg fix cycles:      {N.N}
    Issues found:        {N} (C:{N} M:{N} m:{N})

  Patterns detected:     {N} systemic patterns
  Deferred items:        {N} ({N} critical, {N} high)

  Retrospective saved: sprints/{sprint-id}/retrospective/
  Sprint Report: sprints/{sprint-id}/REPORT.md

→ Recommendation: {context-aware next action}
```
