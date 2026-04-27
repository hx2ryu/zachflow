# Phase 3: Prototype (Sprint Lead + Design Engineer)

Generate self-contained HTML prototypes for app tasks and review them.

## Auto-Skip Conditions

If any of the following apply, skip Phase 3 and go directly to Phase 4:
- `tasks/app/` contains 0 task files.
- No app task has a `### Screens / Components` section.
- `sprint-config.yaml` sets `prototype: skip`.

Skip output:
```
Phase 3 skipped: no prototypable UI tasks found
→ Proceeding to Phase 4: Build
```

## Workflow

### 3.0 KB Sync

Before referencing the Design KB, call `zachflow-kb:sync` once (fast-forward pull). If sync was already performed in Phase 2 it can be skipped, but it is required when entering Phase 3 directly without Phase 2.

### 3.1 Task Filter

Only app tasks that contain a `### Screens / Components` section are in scope.

### 3.2 Spawn Design Engineer

For each in-scope task:

**Step 1: Assemble the Frozen Snapshot** (Sprint Lead — once only)

Before creating the first Design Engineer task, read and assemble the snapshot:

```
1. docs/designs/DESIGN.md (if present)
   → Excerpt §1 Visual Theme, §4 Component Stylings, §7 Do's/Don'ts, §9 Agent Prompt Guide
2. docs/designs/README.md (+ docs/designs/components/*.mdx)
   → Excerpt only patterns relevant to the current sprint's tasks
3. `zachflow-kb:read type=pattern category=design_proto` (+ `design_spec`)
   → Returns design pattern .yaml file paths → Read inline into the snapshot
4. `zachflow-kb:read type=asset category=sample_image` (if present)
   → Returns a list of reusable sample assets (feed thumbnails, avatars, etc.)
   → Use as a fallback source candidate for the `context-engine.yaml assets:` layer
5. (Optional persona hint) If the project maintains design personas (e.g., `.claude/teammates/personas/{archetype}.md`) and the Sprint Lead specified an archetype hint, inline that persona file into the Snapshot. Sprint 0 ships without a fixed persona system — skip this step if no persona library exists.
6. (Optional exemplar lookup) If the project maintains an exemplar/pattern library (e.g., a sprint gallery or design archive), inline the top-2 valid exemplars of the same archetype into the snapshot's `## Exemplar References` section. If no library exists or 0 results — omit the section, log `exemplars_none`.
```

This snapshot is **included identically in every Design Engineer task**.
Do not reassemble it within the sprint.

**Step 2: Task creation**

**Variant trigger evaluation** (once on first entry to Step 2):

Use **variants mode** — issue 3 parallel TaskCreates instead of 1 — when any of these is true:

- Task `quality_score.fabrication_risk` == `medium`
- Task Description contains `variants_required: true`
- The user explicitly says, just before this screen, "I want to see multiple options"

Otherwise, use single mode (the default flow).

**Variants-mode flow**:

1. Issue 3 parallel TaskCreates with the same Frozen Snapshot input (apply superpowers:dispatching-parallel-agents).
2. Append to each TaskCreate Description:
   ```
   variant_id: A | B | C
   variant_directive: "{persona-1-line: conservative / expressive / minimal / etc.}"
   shared_inputs: identical Frozen Snapshot — no extra context allowed
   ```
3. Three fixed variant directives:
   - **A — Conservative**: Stay close to the PRD/pattern baseline. No new components. Safe choices only.
   - **B — Expressive**: Emphasize visual hierarchy (large hero, color contrast, motion hints). Lean on DESIGN.md §3 expressive tokens.
   - **C — Minimal**: Lowest information density. Maximum whitespace. Reduce CTAs to 1-2.
4. After all 3 complete Step C (HTML generation), proceed to §3.2.6 Comparison Gate.
5. **Adjust loop limit**: 1 round through all 3 variants — if the Sprint Lead wants to change variants, stop at the comparison gate and restart.

**Auto-skip conditions** (variants mode disabled):
- `sprint-config.yaml` has `variants_mode: disabled` → globally disabled (the default is conditional).
- Task Description contains `variants_disabled: true` → forces single mode.

**Logging**: The Sprint Lead appends to `logs/events.jsonl`:
- `{"phase":"variants_spawned","screen":"{ScreenName}","variants":["A","B","C"],"trigger":"fabrication_risk_medium"}`

```
TaskCreate:
  Subject: proto/app/{task-id}/{ScreenName}
  Description: |
    --- FROZEN SNAPSHOT ---
    ## Design System (from DESIGN.md)
    {excerpt}

    ## Component Patterns (from docs/designs/README.md)
    {relevant pattern excerpts}

    ## Known Design Patterns (from KB)
    {relevant KB design patterns}
    --- END SNAPSHOT ---

    Exemplar reference rule: the inlined ## Exemplar References are for structural patterns only.
    - Never copy exemplar text/images.
    - Do not directly read the exemplar's prototype_path (use only the inlined metadata).
    - If this screen comes too close to the exemplar, the DE self-flags → quality-report `exemplar_drift_warning: true`.

    Task: tasks/app/{task-id}.md
    Assumption Preview output: runs/{sprint-id}/prototypes/app/{task-id}/{ScreenName}.intent.md
    Preview template: templates/assumption-preview.template.md
    Screen Spec template: templates/screen-spec.template.md
    HTML template: templates/html-prototype.template.html
    Context Engine template: templates/context-engine.template.yaml
    Archetype hint (optional): the Sprint Lead can specify an archetype inferred from PRD analysis — e.g., archetype: feed
      → If unspecified, the DE classifies in B.1.1 from PRD/task content.
      → 7 enum values: feed | detail | onboarding | form | modal | empty_state | nav_list
      → If the project maintains a persona library, point the DE at it via the task description; otherwise the DE relies on the project's design system / brand guidelines.
    Design tokens: tokens/  (symlink → external tokens repo)
    Context output: runs/{sprint-id}/prototypes/context/
    Prototype output: runs/{sprint-id}/prototypes/app/{task-id}/
  Owner: Design Engineer
```

The Design Engineer produces the HTML prototype, then `TaskUpdate: completed`.

### 3.2.5 Assumption Preview Gate (conditional)

Before entering Step C, present the DE's `{ScreenName}.intent.md` to the user to validate assumptions early. See `.claude/teammates/design-engineer.md` §B.6 for conditions and templates.

**On rule conflict (PRD vs Persona, etc.)**:

If the DE recorded a `rule_conflict` or `prd_copy_conflict` block in quality-report, the Sprint Lead asks the user this standardized question before passing the gate:

```
[{ScreenName}] Rule conflict detected:
- Higher-priority rule: {rule_a} ({source_a, e.g., PRD ### NEVER DO})
- Lower-priority rule: {rule_b} ({source_b, e.g., empty_state persona #4})
- DE current behavior: {current — typically the higher-priority rule}
- DE proposed change: "{original}" → "{proposed copy}" (not applied)

Choose:
A. Keep current (higher-priority rule wins) — no change
B. Adopt DE proposal (one-time exemption from higher-priority rule) — record reason in quality-report
C. mix — user writes the copy directly

Choice (A/B/C)?
```

Record the user's choice in quality-report's `prd_copy_conflict.resolution` (or `rule_conflict.resolution`). Consider auto-applying the same decision next time the same pattern appears (zero search results, zero friends, etc.) — `prd_copy_conflict.precedent: applied_from_{ScreenName}`.

**Precedent accumulation**: If the same rule-conflict pattern occurs 2+ times within the same sprint, the Sprint Lead records the first decision in sprint-config.yaml under `rule_conflict_precedents` → automatic application + user notification afterward. Carrying over to a different sprint is a retrospective decision (manual carry-over).

**Mutually exclusive with variants mode**: If this task forked into variants mode in §3.2 Step 2, **skip this gate** (rationale: a 3-variant comparison is coming up — post-comparison is more powerful than pre-validation). Log `phase: preview_skipped, reason: variants_mode`.

**Execution flow**:

1. When the DE produces `{ScreenName}.intent.md`, the Sprint Lead reads it.
2. Summarize the `gate_questions` block to the user (3 sentences or fewer):
   ```
   [{ScreenName} Assumption Preview]
   - Inferred layout {N} items: {one-line summary}
   - Placeholder positions {M}: {one-line summary}
   Questions:
   - {gate_question 1}
   - {gate_question 2}
   proceed / adjust / stop?
   ```
3. Handle the user's response:

| Choice | Action |
|--------|--------|
| **proceed** | Tell the DE "preview approved, proceed to Step C". Keep `TaskUpdate: in_progress`. |
| **adjust** | Append the user's directives to the DE task Description as a `### Preview Adjustments` block. The DE updates the Screen Spec → regenerates intent.md → rerun this gate. |
| **stop** | `TaskUpdate: blocked`. Record a PRD gap in `runs/{sprint-id}/prototypes/prd-gaps.md`. The item is auto-included in Phase 3.4 Amendment extraction. |

**Auto-skip conditions**:
- DE log contains `phase: preview_skipped` → treat as gate-passed (DE skipped at its own discretion).
- `sprint-config.yaml` has `preview_gate: skip` → globally skipped (CI/batch mode).

**Adjust-loop limit**: After 2 adjusts on the same screen, the Sprint Lead escalates:
- **continue**: Allow a 3rd round (user explicitly agrees).
- **switch-to-stop**: Abandon preview and proceed to Step C ("just draw it" agreed by user).
- **abandon**: Drop this screen from Phase 3 → mark rejected.

**Logging**: The Sprint Lead appends to `logs/events.jsonl`:
- `{"phase":"preview_gate","screen":"{ScreenName}","action":"proceed|adjust|stop","iteration":{N}}`

### 3.2.6 Variant Comparison Gate (variants mode only)

Tasks that forked into variants mode in §3.2 Step 2 go through this gate after all 3 variants complete.

**Inputs**: `runs/{sprint-id}/prototypes/app/{task-id}/variants/{A,B,C}/prototype.html` + each variant's spec/quality-report.

**Sprint Lead actions**:

1. Present the auto-generated `variants/_comparison.png` (3 frames horizontally) to the user.
2. Fill `templates/variant-comparison.template.md` and save as `variants/comparison.md`.
3. Summarize for the user (3-5 sentences):
   ```
   [{ScreenName}] 3-variant comparison
   - A (Conservative): {diff_highlights[0]}
   - B (Expressive): {diff_highlights[0]}
   - C (Minimal): {diff_highlights[0]}
   See _comparison.png. A / B / C / mix / stop?
   ```
4. Handle the response:

| Choice | Action |
|--------|--------|
| **A/B/C** | Promote the chosen variant to `prototype.html` (variants parent dir) via file move. Move the 2 unselected to `variants/_archive/`. Record `chosen_variant: {id}` in approval-status.yaml. Proceed to §3.3 normal review. |
| **mix** | Spawn a new single-mode TaskCreate with the user's direction ("A's X + B's Y") inlined into the Description → 1 DE instance. Move all 3 originals to `_archive/`. The mix follows single-mode flow (preview gate may be active). |
| **stop** | Move all 3 to `_archive/`. Append a gap item to `prd-gaps.md` (cite the user's reason). `TaskUpdate: blocked`. |

**Adjust-loop limit**: variants → mix once → if the result is unsatisfactory, stop. No mix-after-mix — prevent infinite loops.

**Logging**:
- `{"phase":"variant_comparison","screen":"{ScreenName}","action":"chose_A|chose_B|chose_C|mix|stop"}`
- On mix: `{"phase":"variant_mix_spawned","screen":"{ScreenName}","mix_spec":"..."}`

### 3.3 Review (Sprint Lead ↔ User)

> Variant-mode tasks enter §3.3 only after passing the §3.2.6 Comparison Gate (promote complete).

Review each prototype with the user, one at a time:

**Review method**:
1. Auto-capture screenshots (browse skill) — each screen × each state.
2. Present screenshots in the chat.
3. If needed, guide the user to open prototype.html directly in a browser to verify interactions.

| Choice | Action |
|--------|--------|
| **approve** | Update `approval-status.yaml`, add `## Prototype Reference` to the task |
| **reject** | Record status, exclude prototype reference |
| **revise** | Run the Revision workflow below |
| **skip** | Keep pending, move to the next screen |

**`## Prototype Reference` format** (added to the task on approve):
```markdown
## Prototype Reference
- **Prototype**: `prototypes/app/{task-id}/prototype.html`
- **Screenshots**: `prototypes/app/{task-id}/screenshots/`
- **Status**: approved
```

### 3.3.1 Revision Routing

When the user picks `revise`, the Sprint Lead automatically classifies the size of the change from the feedback content.

| Class | Criteria | Examples |
|-------|----------|----------|
| **minor** | CSS/content changes — no structural change | spacing, color, size, text, font |
| **major** | Layout structure, components, or interaction changes | tab order, component add/remove, new states, navigation changes |

**Rule**: Do not ask the user for minor/major. Auto-classify from the feedback. If ambiguous, treat as major.

### 3.3.2 Baseline Management

When entering revise, preserve pre-edit screenshots for before/after comparisons.

```
runs/{sprint-id}/prototypes/app/{task-id}/
├── prototype.html
├── screenshots/                 # latest (after edits)
└── baseline/                    # pre-edit (auto-created on revise)
```

| Moment | Action |
|--------|--------|
| First revise entry | Copy `screenshots/` → `baseline/` |
| Consecutive revise (baseline already exists) | Keep baseline, only refresh screenshots |
| approve | Delete `baseline/` |
| reject | Restore `baseline/` → `screenshots/`, then delete baseline |

### 3.3.3 Minor Revision (Annotation flow)

```
1. Collect user feedback
2. Preserve baseline (rule 3.3.2)
3. Assign a fix task to the Design Engineer:
   TaskCreate:
     Subject: revise/minor/app/{task-id}
     Description: |
       Feedback:
       - {feedback item 1}
       - {feedback item 2}
       Target file: prototypes/app/{task-id}/prototype.html
       Affected screen: {ScreenName}
     Owner: Design Engineer
4. After Design Engineer finishes, auto-recapture screenshots
5. Visual Regression diff (3.3.5)
6. User confirmation → approve / revise / reject
```

### 3.3.4 Major Revision (Live Preview flow)

```
1. Preserve baseline (rule 3.3.2)
2. Start a local server:
   python3 -m http.server 8080 --directory runs/{sprint-id}/prototypes/app/{task-id}/
   Tell the user: http://localhost:8080/prototype.html
3. Assign a fix task to the Design Engineer:
   TaskCreate:
     Subject: revise/major/app/{task-id}
     Description: |
       Mode: live-preview
       Feedback:
       - {feedback item 1}
       - {feedback item 2}
       Target file: prototypes/app/{task-id}/prototype.html
       Local server: http://localhost:8080/prototype.html
     Owner: Design Engineer
4. Interactive edit loop:
   user feedback → Design Engineer edits → user refreshes → repeat
5. The user declares "approve" or "this is good now"
6. Capture final screenshots + Visual Regression diff (3.3.5)
7. User final confirmation → approve / revise
8. Stop the local server
```

### 3.3.5 Visual Regression (before/after)

Common to both minor and major after the edit completes.

1. Identify only the changed screens (re-capture all screen × state, then compare to baseline).
2. Present changed screens side-by-side:

```markdown
## Revision diff: {ScreenName}

| Before | After |
|--------|-------|
| baseline/{ScreenName}-default.png | screenshots/{ScreenName}-default.png |

Changes:
- {feedback item 1 reflected}
- {feedback item 2 reflected}
```

3. Do not present unchanged screens.

### 3.3.6 approval-status.yaml extensions

Add revision-tracking fields to a prototype that has been revised:

```yaml
tasks:
  {task-id}:
    {ScreenName}:
      status: approved
      prototype: "prototype.html#{ScreenName}"
      screenshot: "screenshots/{ScreenName}-default.png"
      states_captured: [default, loading, empty, error]
      revision_count: 2          # number of revises (0 means approved on first review)
      last_revision: "minor"     # last revise type (minor | major | null)
      quality_score: "{schema_completeness score}"
      fabrication_risk: "{none | low | medium}"
      reviewed_at: null
      notes: ""
```

### 3.4 PRD Amendment Extraction

For sprints that had revisions, reverse-extract PRD gaps and produce amendment proposals.

**Auto-skip condition**: If 0 screens in `approval-status.yaml` have `revision_count >= 1`, skip.

Skip output:
```
Phase 3.4 skipped: no revisions occurred — PRD amendment not needed
```

**Inputs**:
- `approval-status.yaml` — revision_count, last_revision, fabrication_risk per screen
- Each revision task's Description (feedback list)
- Before/After screenshots (`baseline/` vs `screenshots/`)
- Original PRD's relevant AC (Given/When/Then)
- Original task spec's `### Screens / Components` section

**Analysis logic**:

| Revision signal | PRD gap type | Amendment category |
|-----------------|--------------|--------------------|
| Major revision + new component added | Missing AC | `new_ac` — propose a new AC |
| Minor revision + text/label change | Ambiguous AC | `clarify_ac` — clarify the existing AC |
| Major revision + layout structure change | Missing UI spec | `add_ui_spec` — add a UI requirement |
| fabrication_risk: medium + approved | Implicit unspecified inference approved | `implicit_req` — codify the implicit requirement |
| Same revision pattern across many screens | Missing common rule | `add_rule` — add a business rule |

**Workflow**:

1. Collect screens with `revision_count >= 1` from `approval-status.yaml`.
2. Extract feedback items from each revision task's Description.
3. Classify feedback into PRD gap types (table above).
4. Cross-check against the original PRD AC and produce amendment items.
5. Generate `prd-amendment.md` and save to `runs/{sprint-id}/prototypes/prd-amendment.md`.
6. Present a summary to the user + confirm apply per amendment.

**Output artifact**: `runs/{sprint-id}/prototypes/prd-amendment.md` (template: `templates/prd-amendment.template.md`)

**User actions** (per amendment):

| Choice | Action |
|--------|--------|
| **apply** | Reflect the amendment in the task spec AC. Update API contract if needed. |
| **defer** | Record only in `prd-amendment.md`. Revisit in Phase 6 Retrospective. |
| **dismiss** | Ignore. |

**On apply (auto-reflection)**:
- Add/modify the amendment in the task spec's `## Acceptance Criteria` section.
- If the API contract needs to change, the Sprint Lead manually updates `api-contract.yaml`.
- Display the changed task list when entering Phase 4.

**Output**:
```
PRD Amendment: {sprint-id}
  Revised screens: {N}
  Amendments generated: {M}
    new_ac: {N}, clarify_ac: {N}, add_ui_spec: {N}
    implicit_req: {N}, add_rule: {N}
  Applied: {N}, Deferred: {N}, Dismissed: {N}
  Task specs updated: {list}
```

### 3.5 Prototype-Driven PRD Refinement

Analyze approved prototypes to back-extract a more concrete PRD. The prototype becomes the visual source of truth, producing precise specs for the Build phase.

**Trigger**: at least one screen in `approval-status.yaml` has `revision_count >= 1` **AND** `status: approved`.

**Auto-skip**: If every approved screen has `revision_count === 0`, skip (approved as-is means no extra extraction needed).

Skip output:
```
Phase 3.5 skipped: all prototypes approved without revision — PRD refinement not needed
```

**Inputs**:
- Approved prototype HTML files (`prototypes/app/{task-id}/prototype.html`)
- Original PRD AC (Given/When/Then)
- Task spec's `### Screens / Components` section
- `approval-status.yaml` (revision history)
- `prd-amendment.md` (Phase 3.4 output, if present)

**Extraction targets**:

| Category | Items | Examples |
|----------|-------|----------|
| **UI Components** | Every component, property, and hierarchy on the screen | `Header: logo(left) + coin_btn + bell_btn(right)` |
| **Screen States** | State list defined in the control panel + UI differences per state | `default`, `notification-badge`, `ranking-expanded` |
| **Interactions** | Click/tap/scroll/toggle interactions | `chip tap → grid filter`, `heart tap → like toggle` |
| **Data Schema** | Displayed data fields, formats, placeholder values | `card: thumbnail + title(max 1 line) + creator(avatar 20px + name) + likeCount` |
| **Layout Rules** | Columns, gaps, scroll direction, sticky behavior | `2-col magazine, col gap 6px, row gap 16px, filter chips sticky` |
| **Edge Case UI** | Empty, error, loading states | `filter result 0 → empty state` |

**Workflow**:

1. Collect screens with `revision_count >= 1 AND status: approved` from `approval-status.yaml`.
2. Read each screen's prototype.html.
3. Analyze HTML structure:
   - `#screen-select` → screen list
   - `#state-toggles` → state list
   - `.screen` → DOM structure of each screen → component hierarchy
   - `onclick`, `navigate()` → interaction mapping
   - `[data-state]` → per-state UI differences
4. Structure the extracted requirements and generate `refined-prd.md`.
5. Diff against the original PRD AC:
   - **new**: in the prototype but not in the original PRD
   - **refined**: in the original PRD but the prototype is more specific
   - **unchanged**: matches the original PRD
6. Present the diff summary to the user + confirm reflection.

**Output artifact**: `runs/{sprint-id}/prototypes/refined-prd.md`

```markdown
# Refined PRD: {sprint-id}

> Source: Approved prototypes (post-revision)
> Generated: {date}
> Original PRD: {prd-source}

## {task-id}: {Screen Name}

### Components
| Component | Properties | Notes |
|-----------|-----------|-------|
| {name}    | {props}   | {notes} |

### States
| State | Trigger | UI Changes |
|-------|---------|-----------|
| {state} | {trigger} | {ui delta} |

### Interactions
| Element | Action | Result |
|---------|--------|--------|
| {element} | {action} | {result} |

### Data Schema
| Field | Type | Format | Constraints |
|-------|------|--------|------------|
| {field} | {type} | {format} | {constraints} |

### Layout
| Rule | Value |
|------|-------|
| {rule} | {value} |

### Diff from Original PRD
| Type | AC | Detail |
|------|----|----|
| new | — | {requirement only in prototype} |
| refined | AC {N} | {original → refined detail} |
| unchanged | AC {N} | {match} |
```

**User actions**:

| Choice | Action |
|--------|--------|
| **accept** | Refresh the task spec AC entirely from `refined-prd.md`. Phase 4 uses this spec. |
| **partial** | User picks which items to apply. Only those are reflected in the task spec. |
| **review-only** | Keep as a record. Task specs unchanged. Phase 4 uses it as reference material. |

**On accept (auto-reflection)**:
- Replace the task spec's `## Acceptance Criteria` section based on refined-prd.
- Add a `## Refined PRD Reference` section to the task spec:
  ```markdown
  ## Refined PRD Reference
  - **Refined PRD**: `prototypes/refined-prd.md#{task-id}`
  - **Extraction source**: approved prototype (revision {N})
  - **Status**: accepted
  ```
- If the API contract needs to change, the Sprint Lead updates `api-contract.yaml`.

**Relationship with Phase 3.4**:
- 3.4 (Amendment Extraction): based on revision feedback → **what changed** (delta).
- 3.5 (PRD Refinement): based on the approved prototype → **what exists** (full spec).
- 3.4 runs first and reflects amendments into the task spec; 3.5 then analyzes the full prototype to capture additional missing requirements.
- Items already applied in 3.4 appear as `unchanged` in 3.5's diff.

**Output**:
```
PRD Refinement: {sprint-id}
  Analyzed screens: {N} (revised + approved)
  Requirements extracted:
    Components: {N}, States: {N}, Interactions: {N}
    Data fields: {N}, Layout rules: {N}
  Diff from original PRD:
    new: {N}, refined: {N}, unchanged: {N}
  User action: {accept | partial | review-only}
  Task specs updated: {list}
```

### 3.6 Gate → Phase 4

Verify:
- [ ] `approval-status.yaml` exists.
- [ ] Every target screen has approve/reject/skip (pending count = 0).
- [ ] For rejected screens, the `## Prototype Reference` is removed from the task.
- [ ] If `prd-amendment.md` exists, every amendment has apply/defer/dismiss.
- [ ] If `refined-prd.md` exists, the user has decided accept/partial/review-only.

**Warning**: emit a warning if pending or rejected exist. `--force` overrides.

## Checkpoint (at Phase 3 completion)

Create `checkpoints/phase-3-summary.md`:

```markdown
# Phase 3 Checkpoint: {sprint-id}

## Prototype Results
| Task | Screen | Status | Revisions | Type |
|------|--------|--------|-----------|------|
| {task-id} | {ScreenName} | approved/rejected/skipped | {N} | {minor/major/null} |

## PRD Amendments Applied
- {amendment 1 summary}
- {amendment 2 summary}

## PRD Refinement
- Status: {accept/partial/review-only}
- New requirements: {N}
- Refined requirements: {N}

## Key User Decisions
- {Major user decision and rationale}
```

> Phase 4 references this checkpoint + approval-status.yaml + each task's Prototype Reference, instead of re-reading revision conversations.

## Output

When the Gate passes:
1. Create the checkpoint file (`checkpoints/phase-3-summary.md`).
2. **Print Sprint Status** — emit the `--status` dashboard to show current progress.
3. Enter the next Phase.

```
Sprint Prototype: {sprint-id}
  Generated: {N} screens (HTML)
  Approved: {N}, Pending: {N}, Rejected: {N}
  PRD Amendments: {N} applied, {N} deferred, {N} dismissed
  PRD Refinement: {N} new, {N} refined — {accept | partial | review-only}

[Sprint Status Dashboard]

→ Proceeding to Phase 4: Build
```
