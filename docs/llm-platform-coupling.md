# LLM Platform Coupling

zachflow v1.0 runs on Claude Code's Agent Teams. This document describes the **coupling surface** between zachflow and Claude Code, so that future ports to other agentic LLM CLIs (Codex, Aider, Cursor, etc.) can target the right boundaries.

> **v1.0 scope:** Claude Code only. Multi-LLM dispatch abstraction is on the v1.x roadmap, designed after hands-on experience accumulates in upstream lab projects.

## Coupling Surface

| Surface | Portability | Notes |
|---------|-------------|-------|
| Markdown content (`workflows/`, `templates/`, `.claude/teammates/`) | High — model-agnostic | Just prompt content. Any LLM can read. |
| Slash commands (`/sprint`, `/qa-fix`) | Medium — entry point only | Each platform has its own command system. The handler can be re-written for the target platform. |
| Skill system (`.claude/skills/`) | Medium — directory + meta | Codex/Aider use different conventions. Content survives. |
| Subagent dispatch (Claude Code Agent Teams + `TaskCreate`) | Low — core mechanism | Each platform has different subagent semantics. This is the largest porting surface. |
| Tool names (`Read`, `Edit`, `Bash`, etc.) | High — mapping table | All agentic CLIs have these primitives, named differently. |
| MCP servers | Increasing — gradually standardizing | Some platforms support MCP directly. |
| Prompt caching / frozen snapshot | Claude API specific | Other models have different caching models. Concept generalizes; mechanism does not. |

## v1.0 Hygiene (already applied)

zachflow v1.0 minimizes future port costs without paying abstraction tax now:

1. **Directory boundary**: platform-specific (`.claude/`) is separate from platform-agnostic (`workflows/`, `templates/`, `scripts/`, `.zachflow/`). A future port adds `.codex/` etc. without disturbing the rest.

2. **Generic vocabulary in workflow markdown**: workflow body refers to "the orchestrator dispatches the BE Engineer teammate" rather than "Sprint Lead calls `TaskCreate`". Tool-specific calls are isolated to clearly marked Tool Reference sections.

3. **This document**: the coupling table above + porting checklist.

## Porting Checklist (when v1.x lands)

- [ ] Implement subagent dispatch for the target platform (the core work)
- [ ] Add platform-specific command/entry-point files (e.g., `.codex/commands/sprint.toml`)
- [ ] Map tool names (Claude Code `Read` → target platform's read tool)
- [ ] Verify MCP server compatibility for required integrations (Jira, etc.)
- [ ] Add platform-specific CI matrix entry
- [ ] Add an `examples/` adapter for the platform

## Learning Feedback Channel

Multi-LLM design lessons flow into zachflow via **design specs**, not direct code merges:

```
upstream lab (e.g., zzem-orchestrator running Codex experiments)
    ↓ design learnings only
docs/superpowers/specs/2026-XX-XX-multi-platform-design.md
    ↓ N≥2 validated abstractions only
zachflow v1.x release
```

This keeps zachflow's API stable while platform-specific learning happens in environments that can move faster.