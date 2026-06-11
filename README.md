# zachflow

Harness-driven sprint orchestration for AI coding agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.6.0-blue.svg)]()
[![npm](https://img.shields.io/npm/v/create-zachflow.svg)](https://www.npmjs.com/package/create-zachflow)

zachflow is a workflow harness that brings explicit phase gates, file-based handoff, and contract-first development to long-running coding sessions on Claude Code's Agent Teams. It implements the **Planner–Generator–Evaluator** pattern with cross-session knowledge accumulation.

## Quick start

```bash
npx create-zachflow my-project
```

That's it. `create-zachflow` clones zachflow at the matching tag (`create-zachflow@X.Y.Z` → `vX.Y.Z`, currently `v1.6.0`), strips dev artifacts, re-inits git, and then **auto-runs the interactive wizard** when stdin is a TTY. End-to-end setup takes ~5 minutes. After it completes, open the project in Claude Code and run `/sprint <run-id>`.

To pin a specific zachflow tag, pass `--tag=vX.Y.Z` (defaults to the matching CLI version). To track main, pass `--branch=main`.

**Want to try it without wiring up your own codebase?** After `npx create-zachflow`, run:

```bash
bash scripts/init-project.sh --demo
```

Synthesizes a throwaway Node.js source repo + role + KB so you can run `/sprint demo-1` immediately. The wizard prints the cleanup path at the end.

For non-interactive setup (CI), skip the wizard with `--no-init` and feed a config file:

```bash
npx create-zachflow my-project --no-init
cd my-project
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

The legacy GitHub Release tarball one-liner — `npx https://github.com/hx2ryu/zachflow/releases/download/vX.Y.Z/create-zachflow-X.Y.Z.tgz my-project --tag=vX.Y.Z` — still works as a backup install path.

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

**v1.6.0** — runs on Claude Code Agent Teams. Model-generation calibration for the Claude Fable 5 era: every teammate playbook now carries a role-calibrated Working Style section (grounded completion claims, anti-drift scoping, small-decision autonomy, evaluator coverage-over-self-filtering), with the full review and decision log in [`docs/model-adaptation.md`](docs/model-adaptation.md). Builds on v1.5.0's install/setup UX overhaul (one-command `npx` wizard, prerequisite preflight, `--demo` mode). Multi-LLM platform support is on the v1.x roadmap (see [`docs/llm-platform-coupling.md`](docs/llm-platform-coupling.md)).

Track v1.x progress in [`docs/roadmap.md`](docs/roadmap.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for issue reporting, PR conventions, and coding standards.

## License

MIT — see [`LICENSE`](LICENSE).
