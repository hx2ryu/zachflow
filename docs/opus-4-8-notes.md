# Running zachflow on Claude Opus 4.8

> Operational notes for running the sprint / qa-fix harness on Claude Opus 4.8.
> zachflow prompts are model-agnostic (no hardcoded model IDs), and Opus 4.8 runs
> existing prompts well out of the box. This page covers the few behaviors worth
> tuning at the **session level** plus the prompt adjustments already shipped.

## Why this page exists

Opus 4.8 changes a handful of default behaviors versus prior models. Most are
controlled by **Claude Code session / API settings**, not by zachflow's markdown —
so they cannot be fixed in the harness files and belong here as guidance.

Source: Anthropic "Prompting best practices" (Opus 4.8 section).

## Recommended session settings

The sprint and qa-fix workflows are long-horizon agentic + coding workloads — the
exact profile Opus 4.8's higher effort levels are tuned for.

- **Effort: `xhigh` (or at minimum `high`).** Opus 4.8 respects effort levels
  strictly, especially at the low end, where it scopes work narrowly and may
  under-think on the multi-step reasoning the Evaluator and Build Loop rely on.
  `xhigh` is the recommended setting for coding/agentic use.
- **Large max output budget.** At `xhigh`/`high`, give the model room to think and
  act across subagents and tool calls. Start around 64k and tune.
- **Adaptive thinking.** Opus 4.8 has thinking off unless `thinking: {type: "adaptive"}`
  is set. For agentic loops, adaptive thinking generally outperforms a fixed budget.

These are set in your Claude Code session, not in zachflow. zachflow stays
model-agnostic by design — see `docs/llm-platform-coupling.md`.

## Behaviors to expect

- **More literal instruction following.** Opus 4.8 does not silently generalize an
  instruction from one item to another. Where a teammate prompt means "apply to
  every endpoint/section," the scope is now stated explicitly.
- **Code-review recall.** A review prompt that says "be conservative" or "only
  report high-severity" is followed more faithfully, which can suppress real
  lower-severity findings. The Evaluator and Adversarial Evaluator now separate
  *coverage* (report everything with a severity tag) from *filtering* (the
  PASS/ISSUES/FAIL verdict gate) — see their "Coverage first, filter second"
  sections.
- **Fewer subagents by default.** Opus 4.8 spawns subagents more conservatively.
  Where fan-out is intended (prototype variants A/B/C, independent per-task
  engineers within a group), the dispatch protocol now states it explicitly —
  see `workflows/_shared/agent-team.md` § Parallel Dispatch.
- **Reasoning over tool calls.** Opus 4.8 favors reasoning, which can under-trigger
  KB skill calls. `workflows/_shared/kb-integration.md` now states that recalled
  patterns do not substitute for an actual `zachflow-kb:read`.
- **Frontend house style.** Opus 4.8 has a strong default aesthetic
  (cream/serif/terracotta). The Design Engineer's Pass 6 Anti-Slop Audit already
  rejects any raw hex not defined in `tokens.css`, so DESIGN.md tokens remain the
  source of truth and the default style cannot leak into prototypes.

## What was intentionally NOT changed

- No model IDs / version pins added — the harness stays model-agnostic.
- No RFC-2119 `[MUST]` prefixes, no `model_requirements` frontmatter, no wholesale
  prose→IF/THEN rewrites. Opus 4.8 guidance is to *dial back* aggressive emphasis
  ("CRITICAL: You MUST…" → "Use … when…"), not add more.
- The rigid N-step engineer protocols and 6-pass design audit are deliberate
  reproducibility constraints and are left as-is.
