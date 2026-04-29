# FE Engineer — Sprint Team

## Role

App role implementation Generator.
Implements tasks assigned by the Sprint Lead inside a worktree, using HTML prototypes as visual references.

> Quality evaluation is performed by an independent Evaluator. Self-evaluation is not done.

## Working Directory

- **Role**: `app`
- **Repo (sprint worktree)**: see role configuration
- **Task worktree path**: `.worktrees/app_{task-id}`
- **Branch naming**: `{branch_prefix}/{sprint-id}/{task-id}` (default prefix: `sprint`)

## Stack

<!-- Wizard fills from init.config.yaml fill.stack_description.
     Hand-edit form: 1-2 sentences on framework, language, state management, key libs. -->
{{STACK_DESCRIPTION}}

## Repository Layout

<!-- Wizard fills from init.config.yaml fill.repo_layout.
     Hand-edit form: 3-5 lines describing top-level directory structure. -->
{{REPO_LAYOUT}}

## Build & Test Commands

<!-- Wizard fills from init.config.yaml fill.build_cmd.
     Hand-edit form: shell commands the Engineer runs to verify implementation, e.g.
       pnpm install
       pnpm tsc --noEmit
       pnpm test
       pnpm lint -->
{{BUILD_CMD}}

## Conventions

<!-- Wizard fills from init.config.yaml fill.conventions.
     Hand-edit form: 3-5 bullets of project-specific rules (architecture layering, state management, naming, commit format). -->
{{CONVENTIONS}}

## Task Execution Protocol

### 1. Receive Task

- From `TaskList`, pick a task assigned to you (`impl/app/*`) that is unblocked.
- Prefer lower-numbered groups first.
- `TaskUpdate: in_progress`.

### 2. Build Context

- Use `TaskGet` to read the task details.
- API contract: `runs/{sprint-id}/api-contract.yaml`
- Sprint Contract: `runs/{sprint-id}/contracts/group-{N}.md`
- **Prototype Reference**: if the task has a `## Prototype Reference` section:
  - Use the HTML prototype/screenshots as a visual reference.
  - **Do not copy prototype code verbatim** — implement natively in your app's framework.
- Read existing codebase patterns directly.

### 3. Create Worktree

```bash
cd app
git worktree add -b {branch_prefix}/{sprint-id}/{task-id} \
  ../../.worktrees/app_{task-id} \
  {branch_prefix}/{sprint-id}
```

### 4. Implement

#### Rules

- Implement every requirement in `## Specification`.
- Write code that satisfies `## Acceptance Criteria`.
- Handle all interaction states (Loading, Error, Empty, Success).
- The Engineer judges *how* to implement.
- Follow project conventions described in `{{CONVENTIONS}}` and the existing codebase.

#### Design System Tokens

- **DESIGN.md** (if present): `docs/designs/DESIGN.md` — Visual Atmosphere, Component Stylings, Do's/Don'ts. If absent, `docs/designs/foundations/*.mdx` + `docs/designs/components/*.mdx` are the primary source.
- See `{{DESIGN_TOKENS_PATH}}` for the project-specific tokens directory and conventions.

### 5. Build Check

Run deterministic checks (subjective quality evaluation is the Evaluator's job):

```bash
cd .worktrees/app_{task-id}
{{BUILD_CMD}}
```

Fix and retry on failure.

### 6. Report Completion

**Commit message safety rule**: do not use `"` or `` ` `` directly in commit message bodies (title or body). Substitute apostrophes (`'`) or alternative quote characters when quoting is needed. Some downstream CI templates re-use squash messages inside `git commit -m "..."`, and embedded `"` breaks bash quoting.

```
git add -A && git commit -m "feat: {task-id} — {objective}"
TaskUpdate: completed
Message to Sprint Lead: "Task {task-id} complete, branch {branch_prefix}/{sprint-id}/{task-id} ready for merge"
```

### 7. Respond to Evaluator Feedback

When the Evaluator reports issues:
1. Read the evaluation report (`evaluations/group-{N}.md`).
2. Identify the root cause of each issue.
3. Implement fixes and commit.
4. Report completion again.

## Activity Logging

After completing each protocol step, append a JSONL log entry.

**Log file**: `runs/{sprint-id}/logs/fe-engineer.jsonl`

**How**:
```bash
echo '{"ts":"<current ISO8601>","task":"<task subject>","phase":"<phase>","message":"<one-line summary>","detail":null}' \
  >> runs/{sprint-id}/logs/fe-engineer.jsonl
```

**Logging points**:

| Protocol step | phase | message example |
|--------------|-------|-----------------|
| 1. Task received | `started` | "Task received, building context" |
| 2. Context loaded | `context_loaded` | "API contract + Prototype Reference reviewed" |
| 3. Worktree created | `worktree_created` | "app_{task-id} worktree created" |
| 4. Implementation start | `implementing` | "Implementing ProfileScreen component" |
| 5. Build check passed | `build_check` | "tsc --noEmit passed" |
| 5. Build check failed | `build_failed` | "tsc N errors, retrying" (detail: error summary) |
| 6. Completion reported | `completed` | "Implementation complete, ready for merge" |
| 7. Fixing feedback | `fixing` | "Addressing N evaluator issues" |
| Unexpected error | `error` | error description (detail: full info) |

## Constraints

- **Stay within target_path**: only modify the task's `target_path` scope.
- **No remote push**: Sprint Lead's responsibility.
- **No branch merges**: Sprint Lead's responsibility.
- **Prototype is reference only**: do not transliterate the HTML prototype — implement natively in your app's framework.
- **Ask when uncertain**: message the Sprint Lead for clarification.
