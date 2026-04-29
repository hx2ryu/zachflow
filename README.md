# zachflow

Harness-driven sprint orchestration for AI coding agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)]()

zachflow is a workflow harness that brings explicit phase gates, file-based handoff, and contract-first development to long-running coding sessions on Claude Code's Agent Teams. It implements the **Planner–Generator–Evaluator** pattern with cross-session knowledge accumulation.

## Quick start

```bash
npx https://github.com/hx2ryu/zachflow/releases/download/v1.0.1/create-zachflow-1.0.1.tgz my-project --tag=v1.0.1
cd my-project
bash scripts/init-project.sh
```

The bootstrap is zero-deps and clones the v1.0.1 template, strips dev artifacts, and re-inits git. The interactive wizard then takes ~5 minutes. After completion, you have a working sprint runner ready to run `/sprint <run-id>` in Claude Code.

For non-interactive setup (CI):

```bash
npx https://github.com/hx2ryu/zachflow/releases/download/v1.0.1/create-zachflow-1.0.1.tgz my-project --tag=v1.0.1
cd my-project
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

> The `npx <tarball-url>` form works without an npm publish. A direct `npx create-zachflow` (no URL) is planned for a later release once the package is published to npm.

## Features

- **Two first-class workflows**: `/sprint` (PRD → Spec → Prototype → Build → PR → Retro) and `/qa-fix` (Jira ticket triage and fix orchestration)
- **Build Loop primitive** (Contract → Implement → Evaluate → Fix) shared across workflows
- **Embedded Knowledge Base** (`zachflow-kb:*` skills) — patterns/rubrics/reflections in `.zachflow/kb/`, no external repo required
- **Stack-agnostic teammate templates** — placeholder-based BE/FE/Design/Evaluator role guides, filled by interactive wizard
- **Plugin system** — optional, user-installable extensions (v1.0 ships `recall:ask` for interactive sprint/KB recall)
- **Auto-indexed gallery** — Astro shell that renders `runs/sprint/<id>/prototypes/` outputs (`packages/zachflow-gallery/`)
- **Worktree-isolated sprints** — each sprint runs in dedicated git worktrees, no cross-sprint contamination
- **Active Evaluation** — independent Evaluator agent traces logic + probes edge cases (not just static checks)

## Architecture

```
.claude/skills/         # Claude Code workflow + KB skill registration
workflows/              # platform-agnostic workflow content
  ├── sprint/           # 6-phase sprint pipeline
  ├── qa-fix/           # 5-stage QA fix pipeline
  └── _shared/          # Build Loop, agent dispatch, worktree, KB integration primitives
plugins/                # optional user-installable extensions
  └── recall/           # interactive sprint/KB recall (reference plugin)
packages/               # monorepo workspaces
  ├── zachflow-gallery/ # Astro auto-indexed prototype gallery
  └── create-zachflow/  # npm bootstrap wrapper
templates/              # init wizard templates + sprint artifact templates
schemas/                # JSON Schema for KB content (pattern, rubric, reflection)
runs/                   # sprint instance directories (sprint/, qa-fix/)
.zachflow/kb/           # embedded Knowledge Base (per-project)
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for principles + Build Loop detail, [`MANUAL.md`](MANUAL.md) for operations, [`docs/`](docs/) for KB system, plugin authoring, workflow authoring, and roadmap.

## Status

**v1.0.0** — released. Runs on Claude Code Agent Teams. Multi-LLM platform support is on the v1.x roadmap (see [`docs/llm-platform-coupling.md`](docs/llm-platform-coupling.md)).

Track v1.x progress in [`docs/roadmap.md`](docs/roadmap.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for issue reporting, PR conventions, and coding standards.

## License

MIT — see [`LICENSE`](LICENSE).
