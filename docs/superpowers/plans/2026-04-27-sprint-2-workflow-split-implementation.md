# Sprint 2 — Workflow Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate sprint and qa-fix workflows from `.claude/skills/sprint/` (flat, monolithic) to `workflows/{sprint,qa-fix,_shared}/` (split with Build Loop primitive extracted), with symlink-based skill discovery matching the recall plugin pattern.

**Architecture:** Symlinks bridge `.claude/skills/{sprint,qa-fix}` → `workflows/<name>` (Claude Code's skill discovery still works, but source-of-truth lives in `workflows/`). Phase/stage markdown files reference `workflows/_shared/{build-loop,agent-team,worktree,kb-integration}.md` instead of inline-duplicating shared content. `phase-qa-fix.md` (one 254-line file) is split into 5 stage files + a SKILL.md dispatcher. `runs/` gets workflow-type subdirectories (`runs/sprint/<id>/`, `runs/qa-fix/<id>/`).

**Tech Stack:** bash 5+, git (for `git mv` to preserve history + symlink support), Python 3.11+ (CI smoke uses python3 + yaml), Claude Code skill system.

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-2-workflow-split-design.md` (commit `58caad8`). Read its sections 1 (directory layout), 2 (symlink mechanism), 3-7 (per-primitive extraction), 8 (runs/ structure), 9 (legacy alias), 10 (workflow-authoring) before starting.

---

## File Structure (Sprint 2 output additions/changes)

### Files added

```
~/dev/personal/zachflow/
├── workflows/                              # NEW top-level directory
│   ├── sprint/
│   │   ├── SKILL.md                        # ← git mv from .claude/skills/sprint/SKILL.md, Edit'd
│   │   ├── phase-init.md                   # ← git mv (path/ref edits inside)
│   │   ├── phase-spec.md                   # ← git mv (edits)
│   │   ├── phase-prototype.md              # ← git mv (edits)
│   │   ├── phase-build.md                  # ← git mv (edits — extract Build Loop)
│   │   ├── phase-pr.md                     # ← git mv (edits)
│   │   ├── phase-retro.md                  # ← git mv (edits)
│   │   └── phase-modes.md                  # ← git mv (edits)
│   ├── qa-fix/
│   │   ├── SKILL.md                        # NEW (entry + 5-stage dispatch)
│   │   ├── stage-1-triage.md               # NEW (extracted from phase-qa-fix.md Stage 1)
│   │   ├── stage-2-grouping.md             # NEW (extracted from Stage 2)
│   │   ├── stage-3-contract.md             # NEW (extracted, references _shared/build-loop.md)
│   │   ├── stage-4-implement-eval.md       # NEW (extracted, references _shared/build-loop.md)
│   │   └── stage-5-close.md                # NEW (extracted from Stage 5)
│   └── _shared/
│       ├── build-loop.md                   # NEW (extracted from phase-build.md Sections 4.x)
│       ├── agent-team.md                   # NEW (extracted role definitions + dispatch)
│       ├── worktree.md                     # NEW (extracted worktree protocol)
│       └── kb-integration.md               # ← git mv from .claude/skills/sprint/knowledge-base.md
│
├── .claude/skills/
│   ├── sprint -> ../../workflows/sprint    # NEW symlink (replaces directory contents)
│   └── qa-fix -> ../../workflows/qa-fix    # NEW symlink
│
├── runs/                                    # MODIFIED (subdirectory restructure)
│   ├── sprint/
│   │   └── .gitkeep                        # NEW
│   ├── qa-fix/
│   │   └── .gitkeep                        # NEW
│   └── (.gitkeep removed)
│
├── scripts/
│   └── install-workflows.sh                # NEW
│
├── docs/
│   └── workflow-authoring.md               # MODIFIED (Sprint 0 stub → full guide)
│
├── .github/workflows/ci.yml                 # MODIFIED (add install-workflows step)
└── CHANGELOG.md                             # MODIFIED ([0.3.0-sprint-2] entry)
```

### Files removed

- `.claude/skills/sprint/SKILL.md` (moved to `workflows/sprint/SKILL.md`)
- `.claude/skills/sprint/phase-{init,spec,prototype,build,pr,retro,modes,qa-fix}.md` — 8 files (7 moved, qa-fix split + deleted)
- `.claude/skills/sprint/knowledge-base.md` (moved to `workflows/_shared/kb-integration.md`)
- `runs/.gitkeep` (replaced by `runs/{sprint,qa-fix}/.gitkeep`)

After all moves, `.claude/skills/sprint/` directory should be empty before being replaced by a symlink.

---

## Task 1: Extract `workflows/_shared/` primitives

**Files:**
- Create: `~/dev/personal/zachflow/workflows/_shared/build-loop.md`
- Create: `~/dev/personal/zachflow/workflows/_shared/agent-team.md`
- Create: `~/dev/personal/zachflow/workflows/_shared/worktree.md`
- Move: `~/dev/personal/zachflow/.claude/skills/sprint/knowledge-base.md` → `~/dev/personal/zachflow/workflows/_shared/kb-integration.md` (via `git mv`)

The 4 _shared/ files each have ONE clear responsibility. Phase/stage files (Tasks 2 & 3) will reference them — never inline-duplicate. This task creates them in isolation.

- [ ] **Step 1.1: Create `workflows/_shared/` directory**

```bash
mkdir -p ~/dev/personal/zachflow/workflows/_shared
```

- [ ] **Step 1.2: Read source content for extraction**

```
Read ~/dev/personal/zachflow/.claude/skills/sprint/phase-build.md
Read ~/dev/personal/zachflow/.claude/skills/sprint/phase-pr.md
Read ~/dev/personal/zachflow/.claude/skills/sprint/SKILL.md
```

(For `agent-team.md` extraction we'll cross-reference these. For `worktree.md`, mainly phase-build.md and phase-pr.md. For `build-loop.md`, primarily phase-build.md Sections 4.0~4.6.)

- [ ] **Step 1.3: Write `workflows/_shared/build-loop.md`**

Write `~/dev/personal/zachflow/workflows/_shared/build-loop.md` with the structure below. **Extract corresponding content** from `phase-build.md` (Sections 4.0~4.6 + Severity table + Verdict rules + Budget Pressure Protocol + Frozen Snapshot Protocol).

```markdown
# Build Loop Primitive

> Shared by `workflows/sprint/phase-build.md` (Sprint Phase 4) and `workflows/qa-fix/{stage-3-contract,stage-4-implement-eval}.md` (QA-Fix Stages 3~4). Phase/stage files reference this — never inline-duplicate.

## The Loop

```
For each group:
  1. Contract     — Sprint Lead drafts → Evaluator reviews → consensus on done criteria
  2. Implement    — BE/FE Engineers in parallel worktrees
  3. Merge        — Sprint branch (--no-ff) or fix branch
  4. Evaluate     — Evaluator: Active Evaluation
  5. Verdict      — PASS → next group | ISSUES/FAIL → up to 2 fix iterations
```

## Severity Classification

(Extract from phase-build.md — keep the existing 3-row table verbatim: Critical / Major / Minor with definitions + examples.)

## Verdict Rules

(Extract from phase-build.md — keep the existing 3-row table: PASS / ISSUES / FAIL with conditions + follow-up.)

## Contract Phase (4.1 Detail)

(Extract from phase-build.md Section 4.1: Scope statement, Done Criteria format, Verification Method, KB Pattern Auto-Injection. Drop the "## 4.1" heading prefix — this file is workflow-agnostic.)

## Implement Phase (4.2 Detail)

(Extract from phase-build.md Section 4.2: parallel BE/FE dispatch, Cross-Repo Dependency Handling. Keep generic — drop sprint-specific group numbering.)

## Merge Phase (4.3 Detail)

(Extract from phase-build.md Section 4.3 + 4.3.1 QA Pattern Check + 4.3.2 E2E Smoke. The "Sprint branch --no-ff" specifics stay generic — qa-fix uses fix branch instead, and the consuming file specifies which.)

## Evaluate Phase (4.4 Detail)

(Extract from phase-build.md Section 4.4: Active Evaluation steps — Logic Tracing, Edge Case Probing, Cross-Task Integration, Contract Verification.)

## Fix Loop (4.5 Detail)

(Extract from phase-build.md Section 4.5 + Budget Pressure integration. 2-iteration max + escalation policy.)

## Budget Pressure Protocol

(Extract from phase-build.md "Budget Pressure Protocol" section — Normal/Caution/Urgent 3 levels + level transition triggers.)

## Frozen Snapshot Protocol

(Extract from phase-build.md frozen snapshot mention + cross-reference Section 4.0a KB Sync. The protocol: Sprint Lead reads reference docs once, inlines into TaskCreate Description.)

## Error Handling

(Extract from phase-build.md Section 4.6 Error Handling and Recovery Playbook. Keep all 5 P-cases.)
```

The implementer should write each section with content extracted from `phase-build.md`. Where source content references "Sprint" specifically, generalize to "the workflow caller" or "the consuming workflow's branch". The build-loop.md is **the workflow-agnostic primitive** — sprint/qa-fix specifics live in their own phase/stage files.

Target line count: ~150-200 lines.

- [ ] **Step 1.4: Write `workflows/_shared/agent-team.md`**

Write `~/dev/personal/zachflow/workflows/_shared/agent-team.md` extracting agent role definitions and dispatch protocol that's currently scattered across phase files.

```markdown
# Agent Team Primitive

> Shared by all workflows. Defines roles, responsibilities, and dispatch protocol. Phase/stage files reference this — never re-define agent roles inline.

## Roles

### Sprint Lead (Planner + Orchestrator)
(Extract role definition: Phase management, task dispatch, contract drafting, merge authority, KB integration ownership. From SKILL.md "Goal" + "Phase 1~6" sections.)

### BE Engineer (Generator)
(From .claude/teammates/be-engineer.md context — the Generator role's protocol when invoked by workflow phase: receives task description, works in worktree, commits, reports.)

### FE Engineer (Generator)
(Same pattern as BE Engineer but for app/frontend role.)

### Design Engineer (Generator)
(Specialized Generator for Phase 3 prototyping. Context Engine + Screen Spec + PTC 2-phase generation.)

### Evaluator (Independent Reviewer)
(Read-only constraint, Active Evaluation, no code mutations. Severity/Verdict authority.)

## Dispatch Protocol

### TaskCreate Pattern

(Extract from phase-build.md Section 4.2 + phase-prototype.md TaskCreate examples — the standard subagent dispatch pattern.)

```
TaskCreate(
  description: "<role>-<workflow>-<id>",
  prompt: "<scene-setting + frozen snapshot + task spec>",
  ...
)
```

### Subject Naming Convention

| Phase/Stage | Subject pattern | Owner |
|-------------|-----------------|-------|
| Prototype | `proto/app/{task-id}/{ScreenName}` | Design Engineer |
| Implementation | `impl/backend/{task-id}` | BE Engineer |
| Implementation | `impl/app/{task-id}` | FE Engineer |
| Evaluation | `eval/{project}/group-{N}` | Evaluator |
| Revision | `revise/{minor\|major}/app/{task-id}` | Design Engineer |
| Contract Review | `contract-review/group-{N}` | Evaluator |

### Frozen Snapshot Inclusion

When dispatching a Generator, the workflow caller (Sprint Lead) inlines reference data into the TaskCreate Description as a `--- FROZEN SNAPSHOT ---` block, so the Generator does not need to Read the references again.

(Reference: see `kb-integration.md` for KB-specific snapshot protocol.)

## Read-only Constraint

The Evaluator MUST NOT modify code. If the Evaluator detects an issue requiring code change, it surfaces in the verdict report — the Sprint Lead dispatches a Fix subagent (BE/FE Engineer) to apply the change.

## Cross-Task Communication

Agents communicate via files only — never via chat memory:
- `tasks/<role>/<id>.md` — task assignment
- `contracts/group-<N>.md` — Sprint Contract output
- `evaluations/group-<N>.md` — Evaluator verdict
- `checkpoints/<phase>-summary.md` — phase transition state
- `logs/*.jsonl` — structured activity log
```

Target line count: ~80-120 lines.

- [ ] **Step 1.5: Write `workflows/_shared/worktree.md`**

Write `~/dev/personal/zachflow/workflows/_shared/worktree.md` extracting worktree protocol from phase-build.md and phase-pr.md.

```markdown
# Worktree Primitive

> Shared worktree isolation + branch naming protocol. Phase/stage files reference this when they need to dispatch work into isolated worktrees.

## Setup

`scripts/setup-sprint.sh --config <run-config-path>` reads `repositories:` from the run-config and creates worktree directories per role:

```
{run-worktree}/
├── backend/        # git worktree, branch {branch_prefix}/{run-id}
├── app/            # git worktree
├── tokens/         # symlink (mode=symlink)
└── ...
```

## Branch Naming

| Item | Pattern |
|------|---------|
| Run branch | `{branch_prefix}/{run-id}` |
| Task branch | `{branch_prefix}/{run-id}/{task-id}` |
| Worktree path | `.worktrees/{role}_{task-id}` (per-role per-task) |

`branch_prefix` is set in `sprint-config.yaml`; default `sprint`.

## Merge Policy

- Task branch → Run branch: `--no-ff` merge from Sprint Lead
- Run branch → base branch: PR (Phase 5)
- Fix iterations: amend or new commit on task branch, re-merge
- Conflicts: surface to user — never auto-resolve

## Cleanup

`scripts/cleanup-sprint.sh --config <run-config-path>` after Phase 6 retro:
- Removes worktree directories
- Removes task branches (merged or fixed)
- Preserves run branch until PR is merged

`--force` for dirty worktrees (use with care).

## Constraints

- Engineer agents MUST NOT push or merge directly. Sprint Lead has merge authority.
- Worktree directory must NOT be modified outside the assigned task branch.
- Cross-repo task dependencies (BE↔FE in same group) coordinate via API contract — see `_shared/build-loop.md` § Cross-Repo Dependency Handling.
```

Target line count: ~50-80 lines.

- [ ] **Step 1.6: Move `knowledge-base.md` → `kb-integration.md`**

```bash
cd ~/dev/personal/zachflow
git mv .claude/skills/sprint/knowledge-base.md workflows/_shared/kb-integration.md
```

After the move, edit `workflows/_shared/kb-integration.md`:
- Update the top-level header from `# Knowledge Base` to `# KB Integration Primitive`
- Add this paragraph as the second paragraph (after current opening): "This file documents **how phase/stage files invoke KB skills**. For user-facing KB system reference (modes, schemas, lifecycle), see `docs/kb-system.md`. The two files have distinct audiences and overlapping content should be cross-referenced, not duplicated."

Use `Edit` tool. Other content stays as-is (it was already sanitized in Sprint 0/1).

- [ ] **Step 1.7: Verify all 4 _shared/ files exist + non-empty**

```bash
for f in build-loop agent-team worktree kb-integration; do
  fp=~/dev/personal/zachflow/workflows/_shared/$f.md
  [ -s "$fp" ] && echo "OK: $f.md ($(wc -l < $fp) lines)" || echo "FAIL: $f.md"
done
```

Expected: 4 OK lines.

- [ ] **Step 1.8: Verify no ZZEM literals (regression check)**

```bash
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' ~/dev/personal/zachflow/workflows/_shared/
```

Expected: no output.

- [ ] **Step 1.9: Commit**

```bash
cd ~/dev/personal/zachflow
git add workflows/_shared/
git commit -m "feat(workflows): extract _shared/ primitives (build-loop, agent-team, worktree, kb-integration)"
```

---

## Task 2: Migrate sprint workflow to `workflows/sprint/`

**Files:**
- Move (8 files): `~/dev/personal/zachflow/.claude/skills/sprint/{SKILL.md,phase-init.md,phase-spec.md,phase-prototype.md,phase-build.md,phase-pr.md,phase-retro.md,phase-modes.md}` → `~/dev/personal/zachflow/workflows/sprint/<same-name>`
- Edit (after move): all 8 files for content updates (path refs, _shared/ references, deprecation alias in SKILL.md)

- [ ] **Step 2.1: Create `workflows/sprint/` directory**

```bash
mkdir -p ~/dev/personal/zachflow/workflows/sprint
```

- [ ] **Step 2.2: Move 8 sprint files via git mv (preserves history)**

```bash
cd ~/dev/personal/zachflow
for f in SKILL.md phase-init.md phase-spec.md phase-prototype.md phase-build.md phase-pr.md phase-retro.md phase-modes.md; do
  git mv .claude/skills/sprint/$f workflows/sprint/$f
done
```

Verify:
```bash
ls ~/dev/personal/zachflow/workflows/sprint/
```
Expected: 8 .md files.

```bash
ls ~/dev/personal/zachflow/.claude/skills/sprint/
```
Expected: empty (or just `phase-qa-fix.md` if Task 3 hasn't run yet — that's expected).

- [ ] **Step 2.3: Edit `workflows/sprint/SKILL.md` — add deprecation alias**

Read the current `workflows/sprint/SKILL.md`. Find the "Invocation" or similar section (the part that shows `/sprint <id>` usage). Add a new subsection at the end of the invocation section:

```markdown
## Legacy `/sprint --type=qa-fix` (deprecated)

Calling `/sprint <id> --type=qa-fix --jql=...` is supported as a transitional alias but emits a deprecation warning:

```
⚠ /sprint --type=qa-fix is deprecated; use /qa-fix <id> directly. Will be removed in v2.0.
```

The Sprint Lead detects `--type=qa-fix` in the invocation args, prints the warning, then delegates to the `qa-fix` workflow (see `workflows/qa-fix/SKILL.md`). All other `--type=qa-fix` semantics are preserved during the deprecation window.
```

Use `Edit` tool to insert this section.

- [ ] **Step 2.4: Edit `workflows/sprint/phase-build.md` — extract Build Loop**

This is the largest edit. The current `phase-build.md` (~427 lines) has Build Loop sections (4.0~4.6, severity, verdict, budget pressure) inlined. Replace with references to `_shared/build-loop.md`.

Read `workflows/sprint/phase-build.md` first.

For each of these inline sections, replace with a single-line reference:

| Section to replace | Replacement |
|--------------------|-------------|
| `## 4.1 Sprint Contract (per group)` body (Done Criteria format, Verification Method) | "See `workflows/_shared/build-loop.md` § Contract Phase. Sprint-specific notes below:" + sprint-specific overrides only (group definition, sprint contract template path) |
| `## 4.2 Implement (Engineers)` body | "See `workflows/_shared/build-loop.md` § Implement Phase. Sprint-specific dispatch via Sprint Lead." |
| `## 4.3 Merge (Sprint Lead)` body | "See `workflows/_shared/build-loop.md` § Merge Phase. Sprint workflow uses --no-ff to sprint branch." |
| `## 4.4 Evaluate (Evaluator)` body | "See `workflows/_shared/build-loop.md` § Evaluate Phase." |
| `## 4.5 Fix Loop (with Budget Pressure integration)` body | "See `workflows/_shared/build-loop.md` § Fix Loop." |
| `## 4.6 Error Handling and Recovery Playbook` body | "See `workflows/_shared/build-loop.md` § Error Handling." |
| Severity Classification table | "See `workflows/_shared/build-loop.md` § Severity Classification." |
| Verdict Rules table | "See `workflows/_shared/build-loop.md` § Verdict Rules." |
| Budget Pressure Protocol section | "See `workflows/_shared/build-loop.md` § Budget Pressure Protocol." |
| Frozen Snapshot Protocol section | "See `workflows/_shared/build-loop.md` § Frozen Snapshot Protocol." |

Use `Edit` to do each replacement.

After edits, sprint-specific phase-build.md should be ~80-120 lines: just the sprint-workflow-specific framing (group ordering, KB sync invocation per phase, gate criteria for Phase 5 transition, parallelization rules, output format) without inline duplications of the primitive.

- [ ] **Step 2.5: Edit phase files — replace `runs/<id>/` paths with `runs/sprint/<id>/`**

For each of phase-init.md, phase-spec.md, phase-prototype.md, phase-build.md, phase-pr.md, phase-retro.md, phase-modes.md, SKILL.md:

```bash
grep -nE 'runs/<sprint-id>|runs/\{sprint-id\}|runs/[a-z]' ~/dev/personal/zachflow/workflows/sprint/<file>.md
```

Find each `runs/<id>` path reference and prepend `sprint/`:
- `runs/<sprint-id>/PRD.md` → `runs/sprint/<sprint-id>/PRD.md`
- `runs/{sprint-id}/...` → `runs/sprint/{sprint-id}/...`

Use `Edit` per match (or `replace_all` if pattern is unique enough).

- [ ] **Step 2.6: Edit phase files — replace agent role/dispatch inline → reference _shared/agent-team.md**

In each phase file, find passages that define agent roles or dispatch patterns (e.g., "Sprint Lead is the Planner and dispatches subagents via TaskCreate..."). Replace verbose definitions with a one-line reference: "See `workflows/_shared/agent-team.md` § <role>." Keep phase-specific dispatch instances (which agent dispatches which subagent in this phase).

- [ ] **Step 2.7: Edit phase files — replace worktree inline → reference _shared/worktree.md**

In phase-build.md and phase-pr.md, find worktree setup/cleanup/branch-naming references. Replace inline definitions with a reference: "See `workflows/_shared/worktree.md`." Keep phase-specific worktree invocations (which scripts to run, when).

- [ ] **Step 2.8: Verify no ZZEM literals + no inline Build Loop primitive remnants**

```bash
# 1. ZZEM literals
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' ~/dev/personal/zachflow/workflows/sprint/

# 2. Inline Build Loop heading remnants (these should now be references, not inline content)
grep -nE '## Severity Classification|## Verdict Rules|## Budget Pressure Protocol|## Frozen Snapshot Protocol' ~/dev/personal/zachflow/workflows/sprint/

# 3. Old runs/ paths without sprint/ subdir
grep -nE 'runs/(<sprint-id>|\{sprint-id\})' ~/dev/personal/zachflow/workflows/sprint/

# 4. KB skill names still zachflow-kb (Sprint 1 rename held)
grep -rE 'zzem-kb:' ~/dev/personal/zachflow/workflows/sprint/
```

Expected:
- 1: no output
- 2: no output (or only as references in "See ... § <heading>" format — `grep` would still match because of the literal string in the reference; ALLOW these)
- 3: no output
- 4: no output

For check #2, more precise:
```bash
# Each phase/stage file should have AT MOST 1 occurrence of "Severity Classification" (in a See ref), not the full table.
for f in ~/dev/personal/zachflow/workflows/sprint/*.md; do
  count=$(grep -c "Severity Classification" "$f")
  body_count=$(grep -c "^| Severity " "$f")
  if [ "$body_count" -gt 0 ]; then echo "FAIL: $f has inline Severity table"; fi
done
```

Expected: no FAIL output.

- [ ] **Step 2.9: Commit**

```bash
cd ~/dev/personal/zachflow
git add .claude/skills/sprint/ workflows/sprint/
git commit -m "refactor(workflows): migrate sprint workflow to workflows/sprint/ + reference _shared primitives"
```

---

## Task 3: Migrate qa-fix workflow + split into 5 stages

**Files:**
- Read source: `~/dev/personal/zachflow/.claude/skills/sprint/phase-qa-fix.md` (254 lines, 5 stages inline)
- Create: `~/dev/personal/zachflow/workflows/qa-fix/SKILL.md`
- Create: `~/dev/personal/zachflow/workflows/qa-fix/stage-1-triage.md`
- Create: `~/dev/personal/zachflow/workflows/qa-fix/stage-2-grouping.md`
- Create: `~/dev/personal/zachflow/workflows/qa-fix/stage-3-contract.md`
- Create: `~/dev/personal/zachflow/workflows/qa-fix/stage-4-implement-eval.md`
- Create: `~/dev/personal/zachflow/workflows/qa-fix/stage-5-close.md`
- Delete: `~/dev/personal/zachflow/.claude/skills/sprint/phase-qa-fix.md`

- [ ] **Step 3.1: Read source phase-qa-fix.md**

```
Read ~/dev/personal/zachflow/.claude/skills/sprint/phase-qa-fix.md
```

Identify the 5 stages by their `## Stage N:` headings. Note the Entry Paths section, Directory Layout, Task Subject Naming, and the existing Stage 1~5 content + Failure Modes + Budget Pressure + Retro sections at the end.

- [ ] **Step 3.2: Create `workflows/qa-fix/` directory**

```bash
mkdir -p ~/dev/personal/zachflow/workflows/qa-fix
```

- [ ] **Step 3.3: Write `workflows/qa-fix/SKILL.md`** (entry + dispatcher)

Write `~/dev/personal/zachflow/workflows/qa-fix/SKILL.md`:

```markdown
---
name: qa-fix
description: QA-Fix workflow — triage Jira tickets after a sprint, fix in groups, post evidence back to Jira, extract KB candidates. First-class entry point. Use when /qa-fix <run-id> --jql=... is invoked, or when user wants bulk Jira ticket fix orchestration.
---

# qa-fix Workflow

5-stage pipeline for processing Jira tickets after a sprint or in standalone integration rounds. Reuses the `_shared/build-loop.md` primitive for Stages 3-4.

## Invocation

```
/qa-fix <run-id> --jql="<JQL query>"          # full pipeline
/qa-fix <run-id> --phase=<stage>              # single stage
/qa-fix <run-id> --status                     # dashboard
/qa-fix <run-id> --dry-run                    # block all Jira write calls (comments, transitions); produce artifacts only
```

The legacy `/sprint <run-id> --type=qa-fix --jql=...` invocation still works as a deprecated alias (see `workflows/sprint/SKILL.md` § Legacy alias). v2.0 will remove the alias.

## Entry Paths

(Extract the 2 entry paths — per-sprint vs integration — from source phase-qa-fix.md. Update path references to use `runs/qa-fix/<run-id>/` instead of `sprints/<sprint-id>/qa-fix/`.)

| Path | Trigger | Run dir |
|------|---------|---------|
| **per-sprint** | `/qa-fix <existing-run-id>` while a sprint run is still active | `runs/sprint/<run-id>/qa-fix/` (nested under existing sprint run) |
| **integration** | `/qa-fix <new-run-id> --jql=...` standalone | `runs/qa-fix/<run-id>/` (top-level qa-fix run) |

## Directory Layout

(Extract from source phase-qa-fix.md — the directory tree showing jira-snapshot.yaml, triage.md, groups/, contracts/, evaluations/, jira-comments/, kb-candidates/, unresolved.md, retro.md.)

(Update path: was `sprints/<sprint-id>/qa-fix/` — now `runs/qa-fix/<run-id>/` for integration mode, `runs/sprint/<run-id>/qa-fix/` for per-sprint mode.)

## Task Subject Naming

(Extract the existing 6-row table.)

## 5-Stage Pipeline

| Stage | Detail file | Owner |
|-------|-------------|-------|
| 1. Fetch & Triage | [`stage-1-triage.md`](stage-1-triage.md) | Sprint Lead (self) |
| 2. Grouping | [`stage-2-grouping.md`](stage-2-grouping.md) | Sprint Lead (self) |
| 3. Contract | [`stage-3-contract.md`](stage-3-contract.md) | Sprint Lead → Evaluator |
| 4. Implement + Evaluate | [`stage-4-implement-eval.md`](stage-4-implement-eval.md) | BE/FE Engineer + Evaluator |
| 5. Close | [`stage-5-close.md`](stage-5-close.md) | Sprint Lead (self) |

## Shared Primitives

- Build Loop (Stages 3~4): `workflows/_shared/build-loop.md`
- Agent dispatch: `workflows/_shared/agent-team.md`
- Worktree protocol: `workflows/_shared/worktree.md`
- KB integration: `workflows/_shared/kb-integration.md`

## Budget Pressure

(Same as sprint Build Loop — see `workflows/_shared/build-loop.md` § Budget Pressure Protocol.)

## Failure Modes

(Extract the existing failure-modes table verbatim — Evaluator FAIL after 2 fix loops, Reporter no-response, JQL 0 results, comment post failure, transition failure, transition_name_not_found.)

## Gate → Done

(Extract the existing 4-item gate checklist.)

## Output

(Extract the existing output dashboard format.)
```

Target line count: ~80-120 lines.

- [ ] **Step 3.4: Write `workflows/qa-fix/stage-1-triage.md`**

Extract Stage 1 (Fetch & Triage) content from source phase-qa-fix.md. Preserve:
- Jira fetch invocation pattern + fields list
- Idempotency check (`<TICKET>.posted` marker exclusion)
- jira-snapshot.yaml + triage.md template references (point at `templates/qa-fix-jira-snapshot.template.yaml` etc — note these are .template.yaml after Sprint 0 rename)
- Auto-classification 4 buckets + heuristics
- ⚠️ User approval gate semantics (Approval marker grep + ISO 8601 timestamp)
- needs-info ticket processing (post-approval, dry-run-aware)
- duplicate ticket processing (post-approval, dry-run-aware)
- Stage ordering enforcement explanation

Update path: replace any `sprints/<sprint-id>/qa-fix/` with `runs/qa-fix/<run-id>/` (or `runs/sprint/<run-id>/qa-fix/` for per-sprint mode).

Header should be:
```markdown
# Stage 1: Fetch & Triage

Sprint Lead self-task. First stage of the qa-fix pipeline. See [`SKILL.md`](SKILL.md) for invocation context.
```

End with a navigation link:
```markdown
---
→ Next: [`stage-2-grouping.md`](stage-2-grouping.md)
```

Target line count: ~80-100 lines.

- [ ] **Step 3.5: Write `workflows/qa-fix/stage-2-grouping.md`**

Extract Stage 2 (Grouping) content. Preserve:
- Grouping criteria (root cause, BE endpoint, UI module)
- Group size constraint (1-5 tickets)
- Group config file template (`templates/qa-fix-group.template.yaml`)
- Gate: all in-scope tickets assigned

Update paths. Add navigation prev/next links.

Target line count: ~30-50 lines.

- [ ] **Step 3.6: Write `workflows/qa-fix/stage-3-contract.md`**

Extract Stage 3 content. **Reference `_shared/build-loop.md` § Contract Phase** for the Done Criteria + Verification Method format. qa-fix-specific differences:
- Done Criteria framed as ticket repro success, not AC fulfillment
- Verification Method includes ticket original repro steps inline
- KB pattern auto-injection for fix patterns (vs feature patterns)

Header reference: "qa-fix Stage 3 reuses the Build Loop primitive — see `workflows/_shared/build-loop.md` § Contract Phase. The differences specific to qa-fix are below."

Update paths. Add nav prev/next links.

Target line count: ~30-50 lines (most content is references, not inline).

- [ ] **Step 3.7: Write `workflows/qa-fix/stage-4-implement-eval.md`**

Extract Stage 4 content. **Reference `_shared/build-loop.md` § Implement/Merge/Evaluate/Fix phases**. qa-fix-specific differences:
- Task subject naming: `qa-fix/backend/<run-id>/group-<N>` etc
- Engineer task description includes ticket key list + repro steps inline
- E2E Smoke (4.3.2): impacted flows + new regression flow
- Evaluator traces ticket verification steps 1:1
- Fix loop 2-iteration max — failed tickets move to `unresolved.md`

Update paths. Add nav prev/next.

Target line count: ~50-80 lines.

- [ ] **Step 3.8: Write `workflows/qa-fix/stage-5-close.md`**

Extract Stage 5 (Close) content. Preserve:
- Per-ticket close order (regression evidence → comment SSOT → KB candidate → Jira post → transition → marker)
- Comment field rules (Root Cause, Fix Summary, Verification Steps, Evidence)
- HTML comment stripping (`<!-- -->` blocks must be removed before Jira post)
- KB candidate extraction (P0/P1 only, candidate_type enum)
- Transition target name logic + failure modes
- Posted marker idempotency

Update paths. Add nav prev (no next — this is the last stage).

Target line count: ~80-100 lines.

- [ ] **Step 3.9: Delete source phase-qa-fix.md**

```bash
cd ~/dev/personal/zachflow
git rm .claude/skills/sprint/phase-qa-fix.md
```

- [ ] **Step 3.10: Verify**

```bash
# 1. 6 files in workflows/qa-fix/
ls ~/dev/personal/zachflow/workflows/qa-fix/

# 2. SKILL.md frontmatter valid
python3 -c "
import yaml
content = open('/Users/zachryu/dev/personal/zachflow/workflows/qa-fix/SKILL.md').read()
assert content.startswith('---')
end = content.find('---', 3)
fm = yaml.safe_load(content[3:end])
assert fm['name'] == 'qa-fix', f'wrong name: {fm[\"name\"]}'
print('SKILL.md frontmatter OK')
"

# 3. No ZZEM literals
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' ~/dev/personal/zachflow/workflows/qa-fix/

# 4. Stage 3+4 reference _shared/build-loop.md
grep -l "_shared/build-loop.md" ~/dev/personal/zachflow/workflows/qa-fix/stage-3-contract.md ~/dev/personal/zachflow/workflows/qa-fix/stage-4-implement-eval.md

# 5. No inline Build Loop primitive in stages
for f in stage-3-contract.md stage-4-implement-eval.md; do
  if grep -q '^| Severity ' ~/dev/personal/zachflow/workflows/qa-fix/$f; then
    echo "FAIL: $f has inline Severity table"
  fi
done

# 6. runs/qa-fix/ paths used (not sprints/ legacy)
grep -rnE '(^|[[:space:]`])sprints/' ~/dev/personal/zachflow/workflows/qa-fix/
```

Expected:
- 1: 6 .md files
- 2: `SKILL.md frontmatter OK`
- 3: no output
- 4: 2 files listed
- 5: no FAIL output
- 6: no output

- [ ] **Step 3.11: Commit**

```bash
cd ~/dev/personal/zachflow
git add workflows/qa-fix/ .claude/skills/sprint/
git commit -m "feat(workflows): split qa-fix into 5 stages + SKILL.md dispatcher"
```

---

## Task 4: `install-workflows.sh` + symlinks

**Files:**
- Create: `~/dev/personal/zachflow/scripts/install-workflows.sh`
- Create (via symlink): `~/dev/personal/zachflow/.claude/skills/sprint` → `../../workflows/sprint`
- Create (via symlink): `~/dev/personal/zachflow/.claude/skills/qa-fix` → `../../workflows/qa-fix`

After Tasks 2 + 3, `.claude/skills/sprint/` should be empty (or close to). This task replaces it with a symlink and adds the qa-fix symlink. The installer script makes this idempotent + replicable.

- [ ] **Step 4.1: Verify pre-conditions**

```bash
# .claude/skills/sprint should be empty (or only ghost files)
ls -la ~/dev/personal/zachflow/.claude/skills/sprint/

# workflows/sprint and workflows/qa-fix exist with content
[ -f ~/dev/personal/zachflow/workflows/sprint/SKILL.md ] && echo "sprint/ ready"
[ -f ~/dev/personal/zachflow/workflows/qa-fix/SKILL.md ] && echo "qa-fix/ ready"
```

Expected:
- `.claude/skills/sprint/` empty (no .md files inside)
- "sprint/ ready" + "qa-fix/ ready"

If `.claude/skills/sprint/` has any leftover files, investigate before proceeding (Tasks 2+3 should have moved everything).

- [ ] **Step 4.2: Write `scripts/install-workflows.sh`**

Write `~/dev/personal/zachflow/scripts/install-workflows.sh` with this exact content:

```bash
#!/usr/bin/env bash
# install-workflows.sh — symlink workflows/<name> into .claude/skills/<name>
# Idempotent: skip if symlink already correct, error if non-symlink exists at target.
# Run on fresh clone or after workflow directory restructure.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${PROJECT_ROOT}/.claude/skills"

for workflow in sprint qa-fix; do
  TARGET="${PROJECT_ROOT}/.claude/skills/${workflow}"
  SOURCE_REL="../../workflows/${workflow}"
  SOURCE_ABS="${PROJECT_ROOT}/workflows/${workflow}"

  if [ ! -d "$SOURCE_ABS" ]; then
    echo "Error: source ${SOURCE_ABS} does not exist" >&2
    exit 1
  fi

  if [ -L "$TARGET" ]; then
    current=$(readlink "$TARGET")
    if [ "$current" = "$SOURCE_REL" ]; then
      echo "already linked: $TARGET -> $current"
      continue
    fi
    echo "removing stale symlink: $TARGET -> $current"
    rm "$TARGET"
  elif [ -d "$TARGET" ]; then
    if [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then
      echo "removing empty directory: $TARGET"
      rmdir "$TARGET"
    else
      echo "Error: $TARGET is a non-empty directory; expected symlink target. Aborting." >&2
      ls "$TARGET" >&2
      exit 1
    fi
  elif [ -e "$TARGET" ]; then
    echo "Error: $TARGET exists and is not a symlink or directory. Aborting." >&2
    exit 1
  fi

  ln -s "$SOURCE_REL" "$TARGET"
  echo "linked: $TARGET -> $SOURCE_REL"
done

echo "workflow symlinks installed."
```

- [ ] **Step 4.3: Make executable + verify syntax**

```bash
chmod +x ~/dev/personal/zachflow/scripts/install-workflows.sh
bash -n ~/dev/personal/zachflow/scripts/install-workflows.sh && echo "syntax OK"
```

Expected: `syntax OK`.

- [ ] **Step 4.4: Run install-workflows.sh**

```bash
bash ~/dev/personal/zachflow/scripts/install-workflows.sh
```

Expected output:
```
linked: <project>/.claude/skills/sprint -> ../../workflows/sprint
linked: <project>/.claude/skills/qa-fix -> ../../workflows/qa-fix
workflow symlinks installed.
```

- [ ] **Step 4.5: Verify symlinks work**

```bash
ls -la ~/dev/personal/zachflow/.claude/skills/sprint
ls -la ~/dev/personal/zachflow/.claude/skills/qa-fix

# Read SKILL.md through the symlink
[ -f ~/dev/personal/zachflow/.claude/skills/sprint/SKILL.md ] && echo "sprint SKILL.md readable through symlink"
[ -f ~/dev/personal/zachflow/.claude/skills/qa-fix/SKILL.md ] && echo "qa-fix SKILL.md readable through symlink"

# Verify symlink targets are relative
readlink ~/dev/personal/zachflow/.claude/skills/sprint
readlink ~/dev/personal/zachflow/.claude/skills/qa-fix
```

Expected:
- Both `ls -la` outputs show `sprint -> ../../workflows/sprint` (or qa-fix variant)
- Both readable confirmations
- Both `readlink` outputs show `../../workflows/sprint` and `../../workflows/qa-fix` (relative paths)

- [ ] **Step 4.6: Re-run installer (idempotency check)**

```bash
bash ~/dev/personal/zachflow/scripts/install-workflows.sh
```

Expected: `already linked: ...` × 2 + `workflow symlinks installed.`

- [ ] **Step 4.7: Commit**

```bash
cd ~/dev/personal/zachflow
git add scripts/install-workflows.sh .claude/skills/sprint .claude/skills/qa-fix
git commit -m "feat(workflows): add install-workflows.sh + symlinks for skill discovery"
```

Verify the symlinks landed in git as type `120000`:
```bash
cd ~/dev/personal/zachflow
git ls-tree HEAD .claude/skills/
```

Expected: lines like `120000 blob ... .claude/skills/sprint` (mode 120000 = symlink in git).

---

## Task 5: `runs/` directory restructure

**Files:**
- Modify: `~/dev/personal/zachflow/runs/.gitkeep` → removed
- Create: `~/dev/personal/zachflow/runs/sprint/.gitkeep`
- Create: `~/dev/personal/zachflow/runs/qa-fix/.gitkeep`

- [ ] **Step 5.1: Restructure runs/**

```bash
cd ~/dev/personal/zachflow
git rm runs/.gitkeep
mkdir -p runs/sprint runs/qa-fix
touch runs/sprint/.gitkeep runs/qa-fix/.gitkeep
git add runs/sprint/.gitkeep runs/qa-fix/.gitkeep
```

- [ ] **Step 5.2: Verify tree**

```bash
find ~/dev/personal/zachflow/runs -type f -o -type d | sort
```

Expected:
```
~/dev/personal/zachflow/runs
~/dev/personal/zachflow/runs/qa-fix
~/dev/personal/zachflow/runs/qa-fix/.gitkeep
~/dev/personal/zachflow/runs/sprint
~/dev/personal/zachflow/runs/sprint/.gitkeep
```

- [ ] **Step 5.3: Verify git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: 1 deletion (`runs/.gitkeep`) + 2 additions (`runs/{sprint,qa-fix}/.gitkeep`) staged.

- [ ] **Step 5.4: Commit**

```bash
cd ~/dev/personal/zachflow
git commit -m "chore(runs): restructure runs/ into runs/{sprint,qa-fix}/ subdirectories"
```

---

## Task 6: CI integration + script updates

**Files:**
- Modify: `~/dev/personal/zachflow/.github/workflows/ci.yml` (add install-workflows step)
- Possibly modify: `~/dev/personal/zachflow/scripts/{kb-bootstrap,setup-sprint,sync-repos,cleanup-sprint,sprint-monitor,hook-handler}.sh` (if any have hardcoded `runs/<id>` paths that need workflow-type subdir)

- [ ] **Step 6.1: Inspect existing scripts for `runs/` path references**

```bash
grep -rnE 'runs/' ~/dev/personal/zachflow/scripts/
```

Note any matches. Most likely candidates: `setup-sprint.sh`, `sprint-monitor.sh`, `hook-handler.sh` (those reference run instances).

- [ ] **Step 6.2: Update scripts that have generic `runs/` paths**

For any script that currently writes/reads under `runs/` without workflow-type awareness, the script should accept a `--workflow=<sprint|qa-fix>` flag or read `workflow:` from sprint-config.yaml. Pragmatic approach for v1.0:

- For paths like `runs/<run-id>/` in script bodies → resolve via sprint-config field. If sprint-config.yaml has a `workflow: <sprint|qa-fix>` field (introduced this sprint), use that; default to `sprint` for backwards compat.

For Sprint 2's scope, the minimum needed:
- `setup-sprint.sh` and `cleanup-sprint.sh` create worktree dirs at `.worktrees/<role>_<task-id>/` (these are NOT inside `runs/` — they're separate). So these scripts likely don't need changes.
- `sprint-monitor.sh` reads sprint dashboard from `runs/<id>/`. Update to read from `runs/sprint/<id>/` OR scan both subdirs.
- `hook-handler.sh` finds active sprint. Update path to `runs/sprint/*/`.

For each script with a `runs/` path:
- Read the script
- Identify the path reference
- Update to `runs/sprint/` if it's sprint-specific, or `runs/{sprint,qa-fix}/` glob if it should match either

Use `Edit` per script.

If unsure whether a path needs updating, leave it and surface as a concern in the task report — Sprint 3 or v1.x can refine.

- [ ] **Step 6.3: Add `install-workflows` step to ci.yml**

Read `~/dev/personal/zachflow/.github/workflows/ci.yml`. Find the `smoke` job's steps. Add a new step **right after `actions/checkout@v4`** (so symlinks are set up before any subsequent step touches `.claude/skills/`):

```yaml
      - name: Install workflow symlinks
        run: bash scripts/install-workflows.sh
```

Use `Edit` to insert. Verify the YAML still parses:

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/ci.yml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 6.4: Run all CI smoke checks locally**

```bash
cd ~/dev/personal/zachflow

# 1. Bash syntax for all scripts (Sprint 0/1/2)
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 2. ZZEM-leak scan with current exclusions
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.zachflow \
  --exclude-dir=docs/superpowers \
  --exclude='CHANGELOG.md' \
  --exclude='docs/roadmap.md' \
  --exclude='docs/llm-platform-coupling.md' \
  --exclude='docs/kb-system.md' \
  --exclude='.github/workflows/ci.yml' \
  . > /dev/null && echo "leak scan FAIL" || echo "leak scan PASS"

# 3. KB smoke (now needs to also handle symlinked skills)
bash tests/kb-smoke.sh

# 4. Verify symlinks are followed by smoke check
[ -f .claude/skills/sprint/SKILL.md ] && echo "sprint symlink readable"
[ -f .claude/skills/qa-fix/SKILL.md ] && echo "qa-fix symlink readable"
```

Expected:
- "all scripts syntax OK"
- "leak scan PASS"
- "PASS: KB smoke check" (with 3 step lines)
- 2 symlink-readable lines

- [ ] **Step 6.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add .github/workflows/ci.yml scripts/
git commit -m "feat(ci): add install-workflows step + update scripts for runs/<workflow>/ paths"
```

(The commit may have only the ci.yml change if no scripts needed updates — that's fine.)

---

## Task 7: Expand `docs/workflow-authoring.md`

**Files:**
- Modify: `~/dev/personal/zachflow/docs/workflow-authoring.md`

- [ ] **Step 7.1: Read current stub**

Read `~/dev/personal/zachflow/docs/workflow-authoring.md`. Sprint 0 wrote a placeholder with content like:
> Sprint 2 fills this in (after the workflows/ directory split).

- [ ] **Step 7.2: Replace with full v1.0 guide**

Write `~/dev/personal/zachflow/docs/workflow-authoring.md` with this exact content:

```markdown
# Authoring Workflows

zachflow ships with two first-class workflows: `sprint` and `qa-fix`. This document explains how to add a new workflow, where the boundaries are, and what shared primitives are available.

## Workflow vs Plugin

| | Workflow | Plugin |
|-|----------|--------|
| Location | `workflows/<name>/` | `plugins/<name>/` |
| Discovery | `.claude/skills/<name>` symlink (auto-installed by `scripts/install-workflows.sh`) | `~/.claude/skills/<name>` symlink (user-installed by `plugins/<name>/scripts/install.sh`) |
| Distribution | Core, ships with zachflow v1.0 | Optional, user opt-in |
| Updates | Tied to zachflow version | Independent versioning |
| Examples | `sprint` (6-phase pipeline), `qa-fix` (5-stage pipeline) | `recall` (interactive sprint/KB recall) — Sprint 4 |

If you're adding orchestration logic that's central to zachflow's value, it's a workflow. If you're adding a peripheral tool that's nice-to-have for some users, it's a plugin.

## Workflow Directory Structure

```
workflows/<name>/
├── SKILL.md              # entry point — frontmatter `name: <name>` + invocation + dispatcher
├── phase-<n>-<verb>.md   # OR stage-<n>-<verb>.md — depending on workflow's mental model
└── ...                   # additional content as needed
```

Each phase/stage file:
- Begins with a heading and a one-line "Owner" + reference to SKILL.md
- Has `## Inputs`, `## Steps`, `## Failure handling`, `## Verification` sections (mirrors KB skill protocols)
- Ends with `→ Next:` or `← Prev:` navigation to adjacent phase/stage

## Shared Primitives (`workflows/_shared/`)

zachflow ships 4 primitives that workflows reference instead of defining inline:

| Primitive | File | When to reference |
|-----------|------|-------------------|
| Build Loop | `_shared/build-loop.md` | When your workflow has Contract → Implement → Eval → Fix iteration. The `sprint` workflow's Phase 4 and `qa-fix` workflow's Stages 3-4 both reference this. |
| Agent Team | `_shared/agent-team.md` | When you dispatch BE/FE/Design Engineer or Evaluator subagents. Reference to share the dispatch protocol and role definitions. |
| Worktree | `_shared/worktree.md` | When your workflow uses `setup-sprint.sh` for git worktree isolation (any workflow that does parallel BE/FE work). |
| KB Integration | `_shared/kb-integration.md` | When your workflow reads/writes the embedded KB. Phase 2 (load patterns), Phase 4.1 (auto-inject contract clauses), Phase 6 (write reflections + patterns) reference this. |

**Rule**: never inline-duplicate primitive content. If you need to override a primitive's behavior for your workflow (e.g., qa-fix uses a fix branch instead of sprint branch in Merge phase), reference the primitive then add a "Workflow-specific differences:" subsection.

## Adding a New Workflow

To add a new workflow (e.g., `document-release`):

1. **Decide the mental model** — phases (sequential, well-defined transitions like `sprint` 6-phase) or stages (more loosely coupled like `qa-fix` 5-stage)? Pick the framing that matches your workflow's reality.

2. **Create the directory**:
   ```bash
   mkdir -p workflows/document-release
   ```

3. **Write `workflows/document-release/SKILL.md`** with frontmatter `name: document-release` and an invocation section. Document the entry point: `/document-release <run-id>`.

4. **Decompose into phase or stage files** at `workflows/document-release/<phase-or-stage>-<n>-<verb>.md`. Each file describes one logical unit of work.

5. **Reference shared primitives** in phase/stage files. Don't redefine Build Loop, agent dispatch, or worktree protocol — link to `_shared/` files.

6. **Add the workflow to `scripts/install-workflows.sh`** — append your workflow's name to the loop:
   ```bash
   for workflow in sprint qa-fix document-release; do
     ...
   done
   ```

7. **Create `runs/document-release/.gitkeep`** — your workflow's run directory.

8. **Run `bash scripts/install-workflows.sh`** to create the `.claude/skills/document-release` symlink.

9. **Smoke test**:
   - `[ -L .claude/skills/document-release ]` → symlink exists
   - `[ -f workflows/document-release/SKILL.md ]` → SKILL.md exists
   - SKILL.md frontmatter parses cleanly

10. **Document in `CHANGELOG.md`** under the appropriate version.

## Cross-Workflow Concerns

zachflow does NOT support workflow-to-workflow event passing in v1.0. If your workflow needs another workflow's output, document the dependency in your SKILL.md ("Run `/sprint <id>` to completion before invoking this workflow") rather than auto-trigger.

Cross-workflow KB writes ARE supported (any workflow can read/write the embedded KB), but cross-workflow run state is not — each workflow's `runs/<workflow>/<id>/` is independent.

## Validation

CI runs `bash tests/kb-smoke.sh` which verifies:
- All `schemas/learning/*.json` files are valid JSON Schema (draft 2020-12)
- All `.claude/skills/zachflow-kb/*/SKILL.md` files have valid YAML frontmatter

If your workflow introduces new schemas or skills, extend `tests/kb-smoke.sh` (or add a workflow-specific smoke check) to validate them.

## Future (v1.x+)

- Workflow lifecycle hooks (post-phase, pre-merge, etc.) — currently informal
- Workflow-to-plugin invocation pattern (e.g., `sprint` invokes a `recall:summarize` plugin at retro)
- Cross-workflow KB schema validation
- Workflow yaml DSL (declarative — v2.0 candidate)
```

Target line count: ~120-150 lines.

- [ ] **Step 7.3: Verify**

```bash
[ -s ~/dev/personal/zachflow/docs/workflow-authoring.md ] && echo "exists, non-empty"
lc=$(wc -l < ~/dev/personal/zachflow/docs/workflow-authoring.md)
echo "lines: $lc"
[ $lc -ge 80 ] && echo "size OK"

# Code fences balanced
fc=$(grep -c '^```' ~/dev/personal/zachflow/docs/workflow-authoring.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"
```

Expected: all 3 OK lines, fences balanced.

- [ ] **Step 7.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add docs/workflow-authoring.md
git commit -m "docs: expand workflow-authoring.md to v1.0 (workflow vs plugin, primitives, new-workflow checklist)"
```

---

## Task 8: CHANGELOG + final smoke + v0.3.0-sprint-2 tag

**Files:**
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`

- [ ] **Step 8.1: Add Sprint 2 entry to CHANGELOG**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Find the existing `## [0.2.0-sprint-1] — 2026-04-27` section header. Use `Edit` to insert a new section ABOVE it (newer-on-top convention).

Find this line:
```markdown
## [0.2.0-sprint-1] — 2026-04-27
```

Replace with:
```markdown
## [0.3.0-sprint-2] — 2026-04-27

### Added
- `workflows/{sprint,qa-fix,_shared}/` directory split — workflows are now first-class, separated from `.claude/skills/` (which becomes a platform-compatibility shim via symlinks).
- `workflows/_shared/build-loop.md` — Build Loop primitive (Contract → Implement → Eval → Fix), referenced by `workflows/sprint/phase-build.md` and `workflows/qa-fix/{stage-3,stage-4}.md` instead of inline duplication.
- `workflows/_shared/agent-team.md` — agent role definitions + TaskCreate dispatch protocol.
- `workflows/_shared/worktree.md` — worktree isolation + branch naming.
- `workflows/_shared/kb-integration.md` — phase-by-phase KB invocation patterns (relocated from `.claude/skills/sprint/knowledge-base.md`).
- `workflows/qa-fix/` as 5 stage files + SKILL.md dispatcher (was 254-line monolith).
- `/qa-fix <run-id>` first-class slash command.
- `scripts/install-workflows.sh` — idempotent symlink installer for `.claude/skills/{sprint,qa-fix}`.
- `runs/{sprint,qa-fix}/` workflow-type subdirectories.
- `docs/workflow-authoring.md` — v1.0 guide for adding new workflows.

### Changed
- `runs/<id>/` paths in all phase/stage files updated to `runs/{sprint,qa-fix}/<id>/`.
- `phase-build.md` (was ~427 lines) shrunk to ~80-120 lines as Build Loop primitive moved to `_shared/`.
- `phase-qa-fix.md` (was 254 lines) split into 5 stage files + dispatcher SKILL.md.
- `.github/workflows/ci.yml` — added `install-workflows.sh` step before other smoke steps.
- `.claude/skills/sprint` and `.claude/skills/qa-fix` are now symlinks (mode 120000 in git) to `workflows/<name>/`.

### Deprecated
- `/sprint <id> --type=qa-fix` — emits deprecation warning, delegates to `/qa-fix <id>`. Will be removed in v2.0.

### Deferred to v1.x+
- Workflow yaml DSL (declarative workflow definitions) — v2.0 candidate.
- Plugin lifecycle hook system — v2.0 candidate.
- 3rd workflow (e.g., document-release, security-audit) — depends on N=3 abstraction validation.
- Windows native symlink compatibility (v1.0 = macOS/Linux + WSL).

## [0.2.0-sprint-1] — 2026-04-27
```

(The new section is inserted directly before the existing 0.2.0 section.)

- [ ] **Step 8.2: End-to-end smoke**

```bash
cd ~/dev/personal/zachflow

# 1. install-workflows.sh idempotent
bash scripts/install-workflows.sh

# 2. KB smoke
bash tests/kb-smoke.sh

# 3. ZZEM-leak (with current exclusions)
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.zachflow \
  --exclude-dir=docs/superpowers \
  --exclude='CHANGELOG.md' \
  --exclude='docs/roadmap.md' \
  --exclude='docs/llm-platform-coupling.md' \
  --exclude='docs/kb-system.md' \
  --exclude='.github/workflows/ci.yml' \
  . > /dev/null && echo "leak scan FAIL" || echo "leak scan PASS"

# 4. Bash syntax all scripts
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 5. Symlink integrity
[ -L .claude/skills/sprint ] && echo "sprint symlink intact"
[ -L .claude/skills/qa-fix ] && echo "qa-fix symlink intact"
[ -f .claude/skills/sprint/SKILL.md ] && echo "sprint SKILL.md readable through symlink"
[ -f .claude/skills/qa-fix/SKILL.md ] && echo "qa-fix SKILL.md readable through symlink"

# 6. _shared/ files all exist
for f in build-loop agent-team worktree kb-integration; do
  [ -f workflows/_shared/$f.md ] && echo "_shared/$f.md OK"
done

# 7. workflows/sprint/ has 8 .md files
sprint_count=$(ls workflows/sprint/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$sprint_count" = "8" ] && echo "workflows/sprint/ has 8 files" || echo "FAIL: $sprint_count files (expected 8)"

# 8. workflows/qa-fix/ has 6 .md files
qafix_count=$(ls workflows/qa-fix/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$qafix_count" = "6" ] && echo "workflows/qa-fix/ has 6 files" || echo "FAIL: $qafix_count files (expected 6)"
```

Expected: all OK lines, no FAIL.

- [ ] **Step 8.3: Final git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: only `CHANGELOG.md` modified (staged for commit). No other changes.

- [ ] **Step 8.4: Commit CHANGELOG**

```bash
cd ~/dev/personal/zachflow
git add CHANGELOG.md
git commit -m "docs(changelog): Sprint 2 — workflow split (0.3.0-sprint-2)"
```

- [ ] **Step 8.5: Tag v0.3.0-sprint-2**

```bash
cd ~/dev/personal/zachflow
git tag -a v0.3.0-sprint-2 -m "Sprint 2 — workflow split complete (workflows/{sprint,qa-fix,_shared}/ + symlinks + 4 _shared primitives)"
git tag -l --format='%(refname:short) - %(subject)' | tail -5
```

Expected: 3 tags listed (v0.1.0-bootstrap, v0.2.0-sprint-1, v0.3.0-sprint-2).

- [ ] **Step 8.6: Final commit history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -15
git rev-list --count v0.2.0-sprint-1..HEAD
```

Expected: 8-10 new Sprint 2 commits since v0.2.0-sprint-1 tag.

---

## Sprint 2 Done Criteria

- [ ] `workflows/sprint/` has 8 .md files (SKILL + 7 phase files)
- [ ] `workflows/qa-fix/` has 6 .md files (SKILL + 5 stage files)
- [ ] `workflows/_shared/` has 4 .md files (build-loop, agent-team, worktree, kb-integration)
- [ ] `.claude/skills/sprint` and `.claude/skills/qa-fix` are symlinks (mode 120000 in git) pointing to `../../workflows/<name>`
- [ ] `scripts/install-workflows.sh` is idempotent + valid bash
- [ ] `phase-build.md`, `stage-3-contract.md`, `stage-4-implement-eval.md` reference `_shared/build-loop.md` (no inline Severity/Verdict tables in any of them)
- [ ] `runs/sprint/.gitkeep` and `runs/qa-fix/.gitkeep` exist; `runs/.gitkeep` removed
- [ ] All phase/stage files use `runs/{sprint,qa-fix}/<id>/...` paths (no bare `runs/<id>/`)
- [ ] `/sprint <id> --type=qa-fix` deprecation alias documented in `workflows/sprint/SKILL.md`
- [ ] `docs/workflow-authoring.md` is the v1.0 reference (≥80 lines)
- [ ] CI smoke checks all pass locally (bash syntax, ZZEM leak, KB smoke, symlink integrity)
- [ ] CHANGELOG.md has `[0.3.0-sprint-2]` entry
- [ ] Tag `v0.3.0-sprint-2` exists
- [ ] Working tree clean

---

## Notes for Sprint 3+

- Sprint 3 (`stack-adapter`): introduces `init-project.sh` interactive wizard. The wizard will prompt for `workflow` activation (sprint/qa-fix/both) and run `install-workflows.sh` afterward. Sprint 3 also formalizes `templates/teammates/*.template.md` placeholder location.
- Sprint 4 (`gallery + plugins-formalize + release`): introduces `plugins/<name>/` directory pattern (Sprint 2's symlink approach is the same model — recall plugin install will follow `install-workflows.sh` precedent). `plugins/recall/` is ported as the first reference plugin.

The `_shared/` primitives (this sprint) become the foundation for any future workflow without further architectural work. The plugin system (Sprint 4) is orthogonal — it doesn't share primitives with workflows.
