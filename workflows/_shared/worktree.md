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
