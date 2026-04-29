# Contributing to zachflow

Thanks for considering a contribution! zachflow is an opinionated harness — most contributions land best as plugins or stack adapter examples rather than core changes.

## Reporting Issues

Open a GitHub issue with:
- zachflow version (`v1.0.0` etc, see CHANGELOG.md)
- macOS/Linux + bash version (`bash --version`)
- Reproduction steps
- Expected vs actual behavior

For Claude Code-related issues (subagent dispatch, skill discovery), include the relevant SKILL.md path and frontmatter.

## Submitting Pull Requests

1. **Open an issue first** for non-trivial changes — discuss scope before implementing
2. Fork + branch from `main`
3. Make your changes following the coding standards below
4. Add CHANGELOG entry under `## [Unreleased]`
5. Run smoke tests locally: `bash tests/kb-smoke.sh && bash tests/init-project-smoke.sh && bash plugins/recall/tests/test_config.sh && bash plugins/recall/tests/test_session.sh`
6. Open PR with description: what changed, why, how tested

## Coding Standards

### Bash scripts (`scripts/`, `tests/`, `packages/*/scripts/`)
- Bash 3.2+ compatible (no `declare -A` associative arrays — macOS default `/bin/bash` is 3.2.57)
- Always `set -euo pipefail`
- Use `${KB_PATH:-./.zachflow/kb}` style env-var fallback
- Validate with `bash -n` before commit
- For new scripts: include header comment block with usage + flags

### Markdown content (workflows/, plugins/, docs/)
- English only
- No ZZEM literals (zachflow inherited a sanitization commitment from upstream zzem-orchestrator — see `docs/llm-platform-coupling.md`)
- Code fences balanced
- Cross-references use relative paths

### Skill protocols (`.claude/skills/*/SKILL.md`, `plugins/*/<skill>/SKILL.md`)
- Frontmatter with `name: <skill-name>` (or `<plugin>:<skill>` for plugins)
- Sections: Inputs, Preconditions, Steps, Failure handling, Verification
- Reference shared primitives (`workflows/_shared/build-loop.md`) instead of inline duplication

### Adding a new plugin

See `docs/plugin-authoring.md` for the 10-step checklist. Plugins live under `plugins/<name>/` and are user-installable via `bash scripts/install-plugins.sh <name>`.

### Adding a new workflow

See `docs/workflow-authoring.md`. Workflows live under `workflows/<name>/` and auto-install via `scripts/install-workflows.sh`.

## License Sign-off

By submitting a PR, you agree your contribution is licensed under MIT (the project license). Add a `Signed-off-by: Your Name <email>` line to commit messages for significant contributions.

## Code of Conduct

(v1.x will add a formal CoC. For v1.0, the rule is simple: be respectful, focus on the work, no harassment.)
