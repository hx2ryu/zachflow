# Phase 1: Init (Sprint Lead solo)

Initialize the sprint directory.

## Workflow

1. **Collect arguments**: `sprint-id` and `prd-file` path. If missing, ask the user.
2. **Verify PRD exists**: check `docs/prds/{prd-file}`.
3. **Create directory** — branches by sprint type:

   **type=standard (default)**:
   ```
   runs/{sprint-id}/
   ├── PRD.md
   ├── sprint-config.yaml
   ├── tasks/
   │   ├── app/.gitkeep
   │   └── backend/.gitkeep
   ├── contracts/.gitkeep
   ├── evaluations/.gitkeep
   ├── prototypes/app/.gitkeep
   ├── checkpoints/.gitkeep
   └── logs/.gitkeep
   ```

   **type=qa-fix**:
   ```
   runs/{sprint-id}/
   ├── sprint-config.yaml       # type=qa-fix, qa_fix.jql required
   ├── qa-fix/
   │   ├── groups/.gitkeep
   │   ├── contracts/.gitkeep
   │   ├── evaluations/.gitkeep
   │   ├── jira-comments/.gitkeep
   │   └── kb-candidates/.gitkeep
   ├── checkpoints/.gitkeep
   └── logs/.gitkeep
   ```

   PRD.md, tasks/, and prototypes/ are not created for qa-fix type (Phase 1~3 are skipped).
4. **PRD.md** (type=standard only): auto-generate the original link + scope summary.

5. **sprint-config.yaml**: ask the user for the base branch, then generate. For type=qa-fix, additionally:
   - `qa_fix.jql` (required) — ask the user for the JQL.
   - `qa_fix.jira_base_url` (required)
   - `qa_fix.ready_for_qa_transition` (optional, default "Ready for QA")
6. **Create repository worktrees**: run `./scripts/setup-sprint.sh --config runs/{sprint-id}/sprint-config.yaml`. The script loops over the sprint-config `repositories` map; for each role:
   - `mode: worktree` → create a git worktree in `{role}/` and check out branch `{branch_prefix}/{sprint-id}` (forked from `origin/{base}`).
   - `mode: symlink` → create a symbolic link from `{role}/` to the source path.

   The main checkout in each source repo is left untouched (HEAD/working tree preserved). Show the script output to the user; on errors, resolve the cause (e.g., a missing source path) and rerun.

7. **Repository sync (optional)**: run `./scripts/sync-repos.sh --config runs/{sprint-id}/sprint-config.yaml`. This only runs `git fetch origin {base}` in each source repo (sprint branches are not touched). Skip if the network is unavailable or you're in a read-only environment.

## Gate → Next Phase

**type=standard → Phase 2**:
- [ ] `runs/{sprint-id}/` directory layout complete (PRD.md, sprint-config.yaml, tasks/, contracts/, evaluations/, checkpoints/, logs/)
- [ ] PRD.md contains the original PRD link + scope summary
- [ ] sprint-config.yaml has `repositories` (role → {source, base, mode}) + `branch_prefix`
- [ ] `setup-sprint.sh` ran successfully and each role directory was created (`{role}/.git` or symlink)
- [ ] (Optional) repository fetch complete

**type=qa-fix → Phase QA-Fix** (Phase 2~3 auto-skipped):
- [ ] `runs/{sprint-id}/` directory layout complete (sprint-config.yaml, qa-fix/, checkpoints/, logs/)
- [ ] sprint-config.yaml has `type: qa-fix` + `qa_fix.jql` + `qa_fix.jira_base_url`
- [ ] sprint-config.yaml has `repositories` + `branch_prefix`
- [ ] `setup-sprint.sh` ran successfully and each role directory was created

## Output

When the Gate passes:
1. **Print Sprint Status** — emit the `--status` dashboard to show current progress.
2. Enter the next Phase.

**type=standard**:

```
Sprint initialized: {sprint-id}
  Directory: runs/{sprint-id}/
  PRD: {prd-file}
  Repositories: (role → branch)
    backend → {branch_prefix}/{sprint-id} (base: {base})
    app     → {branch_prefix}/{sprint-id} (base: {base})
    tokens  → symlink (read-only)

[Sprint Status Dashboard]

→ Proceeding to Phase 2: Spec
```

**type=qa-fix**:

```
Sprint initialized: {sprint-id} (type=qa-fix)
  Directory: runs/{sprint-id}/
  JQL: {qa_fix.jql}
  Repositories: (role → branch)
    backend → {branch_prefix}/{sprint-id} (base: {base})
    app     → {branch_prefix}/{sprint-id} (base: {base})

[Sprint Status Dashboard]

→ Proceeding to Phase QA-Fix
```
