# Model Adaptation — Claude Fable 5 Readiness Review

> Review date: 2026-06-11. Trigger: Claude Code's frontier tier moved to the Claude 5 family (Claude Fable 5). zachflow's prompts and harness were written against Claude 4.x-era behavior; this document records the structural review and the decisions taken.

## Scope of the review

zachflow does **not** call the Anthropic API directly. There are no model IDs, `thinking`/`effort` parameters, `max_tokens` settings, or SDK calls anywhere in the repo — all LLM interaction goes through Claude Code's subagent dispatch (`TaskCreate`), and the runtime model is whatever the user's Claude Code session runs (see `docs/llm-platform-coupling.md`).

That means the entire adaptation surface is **prompt content**:

| Surface | Files |
|---|---|
| Teammate behavioral playbooks | `.claude/teammates/*.md` (5 roles) |
| Teammate templates (shipped to user projects) | `templates/teammates/*.template.md` (5 roles) |
| Workflow markdown | `workflows/{sprint,qa-fix,_shared}/*.md` |
| Harness mechanisms | guards, checkpoints, Frozen Snapshot, Budget Pressure |

The review was driven by Anthropic's Fable 5 migration guidance. The behavioral shifts that matter for a harness like zachflow:

1. **Over-prescriptive prompts reduce output quality** — step-by-step scaffolding written for prior models can hurt; prefer stating goal + constraints.
2. **Strong instruction following** — explicit boundary/style sections work better than ever; use them.
3. **More deliberate, asks more often** — grant autonomy on minor decisions explicitly, or ask-rate climbs.
4. **Unrequested-but-adjacent actions** — state boundaries explicitly (maps directly onto zachflow's *drift* failure mode).
5. **Grounded progress claims** — requiring evidence-audited status reports nearly eliminates fabricated "done" claims (maps onto *self-deception*).
6. **Rare early stopping** — deep in long sessions, may end a turn with a stated intention instead of the tool call; autonomous pipelines need a "finish the turn" instruction.
7. **Code-review harnesses**: report-everything-filter-downstream beats self-filtering — severity filters are followed *literally*, which silently depresses recall.
8. **New tokenizer** — same content ≈ 30% more tokens than Opus-tier; context-efficiency mechanisms gain value.
9. **Parallel sub-agents are dependable** — delegation no longer needs suppressing; it needs *when-to-use* guidance.

## Decisions

### Applied — `## Working Style` section per teammate (instance + template pairs)

Each of the five roles gained a short, role-calibrated Working Style section (guidance items 3, 4, 5, 6 above):

| Role | Calibration |
|---|---|
| BE/FE Engineer | Simplest-thing-that-works (anti-drift, reinforces `drift_guard`), grounded completion claims (reinforces `self_deception_guard`), small-decisions-are-yours (cuts ask-rate; spec/scope questions still go to the Sprint Lead), finish-the-turn |
| Evaluator | Coverage over self-filtering (item 7 — Verdict Rules are the downstream filter), finish-the-turn |
| Adversarial Evaluator | Coverage over self-filtering scoped to *traced* findings (the existing "drop untraced hunches" rule is the only drop criterion), finish-the-turn |
| Design Engineer | Spec-scoped generation (anti-drift for UI), grounded artifact claims, micro-choices-are-yours within the design system, finish-the-turn |

The `Ask when uncertain` constraint on BE/FE was narrowed to **spec/scope uncertainty** so it no longer contradicts the autonomy grant.

### Kept as-is — already aligned with Fable 5 guidance

| Mechanism | Why it survives |
|---|---|
| Evaluator's "When uncertain, report ISSUE" + Anti-Pattern Watchlist | This is the report-everything-filter-downstream pattern the migration guide recommends for code-review harnesses. The Verdict Rules (`build-loop.md`) are the downstream filter. Softening this would *reduce* recall on a model that follows severity filters literally. |
| Four failure-mode guards (`drift`, `self_deception`, `context`, `regression`) | Model-agnostic, artifact-level checks. Fable 5 guidance independently recommends the behaviors they enforce (boundaries, grounded claims). |
| Frozen Snapshot Protocol + Checkpoint system | Context-efficiency mechanisms gain value under the new tokenizer (~30% more tokens for the same content). No change needed — the concept is platform-level, not model-parameter-level. |
| Budget Pressure Protocol | Pressure levels are artifact-driven (fix-loop counts), not token-count-driven. Note: the guide warns that surfacing explicit remaining-token countdowns can trigger "context anxiety" — zachflow never surfaces token counts to agents, so no change. |
| Parallel BE/FE dispatch within a group | Fable 5 is explicitly dependable at parallel sub-agent work; the existing structure needs no suppression or expansion. |
| KB read/write timing | KB calls are workflow-scheduled (Phase 2/4/6 + group entry), not left to model initiative — so Fable 5's tendency to under-reach for memory tools is structurally bypassed. |

### Deferred — needs A/B evidence before changing

| Candidate | Why deferred |
|---|---|
| De-prescribing `design-engineer.md` Steps A/B/C (972 lines, the most step-by-step prompt in the repo) | The migration guide recommends removing prior-model step scaffolding *after A/B-testing the workload* — it also warns prescriptive structure sometimes is the right call (deterministic extraction, Zero-Contamination rule). Run one sprint's Phase 3 with a goal-and-constraints variant against the current version and compare prototype quality + spec fidelity before touching it. |
| Softening the Evaluator's mandatory protocol ordering (Build Check → Logic Tracing → …) | Sequencing here encodes a real dependency (no point evaluating code that doesn't compile), not ceremony. Leave until evidence shows the model wastes effort on it. |

### Not applicable

| Item | Reason |
|---|---|
| Model ID swaps, `thinking`/`effort`/`max_tokens` re-baselining, `refusal` stop-reason handling, prefill removal, tokenizer cost re-measurement | zachflow makes no direct API calls. These concerns live in Claude Code itself. If a future version adds direct API dispatch (multi-LLM roadmap), run the official migration checklist then. |
| Prompt-caching breakpoint changes | Caching is managed by Claude Code; the Frozen Snapshot convention is unaffected. |

## Re-review checklist for future model generations

When the underlying Claude Code model changes generation again:

1. Read the official migration guide's **behavioral shifts** section (API breaking changes rarely apply here — confirm the repo still makes no direct API calls).
2. Re-test the **Working Style** sections: are the calibrations still needed, or now over-correcting? (E.g., a future model may not need finish-the-turn nudges.)
3. Re-check the Evaluator stance against the guide's code-review recommendation — coverage-vs-filtering advice has flipped between generations before.
4. Re-run the deferred A/B items above if still open.
5. Update this document's decision tables; keep superseded decisions in git history rather than inline.
