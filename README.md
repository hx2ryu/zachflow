# zachflow

Harness-driven sprint orchestration for AI coding agents. Built on the Planner–Generator–Evaluator pattern: explicit `Sprint Contract` consensus before code, parallel `Generator` teammates for implementation, independent `Evaluator` for active evaluation, with `Knowledge Base` feedback for cross-session learning.

> **Status:** v1.0 ships on Claude Code Agent Teams. Multi-LLM platform support (Codex, Aider, Cursor, etc.) is on the v1.x roadmap — see [`docs/llm-platform-coupling.md`](docs/llm-platform-coupling.md).

## Why zachflow

Long-running coding sessions tend to drift. Self-evaluation is unreliable. Solo agents accumulate context until they lose the thread. zachflow is a **harness** — explicit phase gates, structured file-based handoff, contract-first development, and an Evaluator that does not write code.

Reference: ["Harness Design for Long-Running Agentic Applications"](https://www.anthropic.com/engineering) (Anthropic Engineering).

## Quick Start

```bash
# Coming with v1.0 release:
npx create-zachflow my-project
cd my-project
# Wizard configures your stack, then:
/sprint my-first-sprint
```

(Sprint 0 ships the scaffold — `create-zachflow` wrapper lands in Sprint 4.)

## Workflows

zachflow ships two first-class workflows:

| Workflow | Slash command | Use case |
|---------|---------------|----------|
| Sprint | `/sprint <id>` | New feature implementation: PRD → Spec → Prototype → Build → PR → Retro |
| QA-Fix | `/qa-fix <id>` | Bulk Jira ticket triage and fix orchestration |

Both share the **Build Loop primitive** (`Contract → Implement → Evaluate → Fix`) — see [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Status

v0.1 — Sprint 0 bootstrap. Not yet usable end-to-end. Track v1.0 progress in [`docs/roadmap.md`](docs/roadmap.md).

## License

MIT — see [`LICENSE`](LICENSE).
