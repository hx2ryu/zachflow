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
