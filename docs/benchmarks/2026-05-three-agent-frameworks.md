# Benchmark — hermes-agent · ruflo · deer-flow (2026-05)

Comparative read of three open-source LLM-agent frameworks, with portability decisions for zachflow recorded inline. Companion to the implementation that lands in `feat/v14-pattern-curator`.

Sources: each project's README + the deepest accessible design doc (deer-flow `backend/CLAUDE.md`, hermes `AGENTS.md`, ruflo README + repo tree).

## 1. One-paragraph summaries

**[nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent)** — Python MIT, ~150k★. Single-process synchronous agent + CLI. State is SQLite with FTS5 over every past message. Skills live as files under `~/.hermes/skills/`; a *curator* tracks `use_count` / `state` / `created_by` / `pinned` in `.usage.json` and auto-archives unused skills after a TTL. Sub-agents are spawned via `delegate_task` with a static role-gated ACL (`leaf` vs `orchestrator`) and `max_spawn_depth=2`.

**[ruvnet/ruflo](https://github.com/ruvnet/ruflo)** — TypeScript MIT, ~51k★. Multi-agent orchestration that lives *inside* Claude Code. Planner is **GOAP A\*** (Goal-Oriented Action Planning) that re-plans from the current state on failure. Memory is **AgentDB**, an HNSW vector store in a single on-disk `agentdb.rvf` file. Adds a trust-tiered PII pipeline (`BLOCK / REDACT / HASH / PASS`) and federation identity via mTLS + ed25519 challenge-response.

**[bytedance/deer-flow](https://github.com/bytedance/deer-flow)** — Python + TypeScript MIT, ~68k★. LangGraph harness whose entire personality is an ordered **18-component middleware chain** built by `build_lead_runtime_middlewares()`: each middleware (`LoopDetectionMiddleware`, `SubagentLimitMiddleware`, `ClarificationMiddleware → Command(goto=END)`, …) intercepts `after_model` / `after_tool`. Skills are `SKILL.md` files with YAML frontmatter including `allowed-tools`. Memory is per-user typed facts (`{id, content, category, confidence, source, createdAt}`) with a 0.7 confidence threshold and whitespace-normalized dedup.

## 2. Seven portable ideas — evaluation

| # | Idea | Source | Difficulty | ROI | Coupling | zachflow gap | Decision |
|---|------|--------|------------|-----|----------|--------------|----------|
| 1 | Skill curator (`.usage.json` + auto-archive) | hermes | Med | **High** | `scripts/lib/`, KB | Phase 6.7b | **adopted** (this PR) |
| 2 | 4-failure-mode guards (middleware chain) | deer-flow | Med | High | `workflows/_shared/guards/` | design-principles §Failure Modes → executable | **v1.x candidate** |
| 3 | Typed-facts pattern fields (confidence/category/source) | deer-flow | Med | High | `schemas/learning/`, KB migration | T2-F drift detection | **partial** (this PR ships state/use_count/last_referenced_at; confidence pruning → v1.x) |
| 4 | Adversarial Evaluator (read-only red-team) | hybrid | Med | High | `.claude/teammates/`, `build-loop.md §4.4` | T2-C | **v1.x candidate** |
| 5 | `SKILL.md` `allowed-tools` frontmatter | deer-flow | Low | Med | every skill file | new ACL | **v2.0** (global skill rewrite) |
| 6 | Role-gated sub-agent ACL (leaf/orchestrator) | hermes | Low | Med | `.claude/teammates/` | T2-C secondary | **v2.0** (Evaluator is already read-only by convention) |
| 7 | PII HASH bucket + ed25519 audit signing | ruflo | High | Med | `scripts/lib/jsonl-append.py` | hash-chain extension | **v1.x candidate** (needs separate key-management design) |

## 3. Adopted in this PR — Pattern curator (Phase 6.7b)

Hermes's `~/.hermes/skills/.usage.json` is the single best concrete mechanism across the three repos for the open zachflow gap. Two adjustments for zachflow's shape:

- **No sidecar `.usage.json`.** zachflow's §6 file-based handoff principle says the pattern file is the single source of truth. `state`, `use_count`, `last_referenced_at` go into the pattern's own yaml frontmatter; the only sidecar is `logs/curator.jsonl` (the audit trail, which is append-only and hash-chained — orthogonal to the source-of-truth file).
- **Reference counting reads structured jsonl fields only.** A record contributes to a pattern's `use_count` only if it carries `pattern_id` (string) or `pattern_ids` (list). Free-text matches (e.g. agents naming `correctness-001` in prose) are deliberately ignored to avoid use-count inflation.

See `scripts/lib/curator.py`, the 3 new skills under `.claude/skills/zachflow-kb/{promote-pattern,archive-pattern,list-stale}/`, and the schema-v2 migration script.

## 4. Decisions on the four re-evaluated items

### 4a. ruflo — GOAP A\* planner → **stays skipped**

zachflow's Sprint Lead decomposes PRD → tasks in natural language. §5 *Deliverable-focused spec* explicitly says the harness defines *what*, not *how*; an A\* state-space planner is a hard-coded *how* layer. The LLM handles state-space reasoning fine when given a clear contract, and the "re-plan from current position" behaviour is implicit in zachflow's Fix Loop. No port.

### 4b. ruflo — HNSW vector retrieval → **stays skipped**

KB is intentionally plain markdown / yaml so a human can `grep` and a CI can validate. Vector retrieval makes "why was this pattern surfaced?" opaque, which directly fights the T2-F drift-detection direction (a stale pattern that returns high cosine similarity *because of phrasing* is exactly the failure we want to surface). Plain-text + curator's structured fields is the right tool here.

### 4c. ruflo — PII HASH bucket + ed25519 audit signing → **v1.x candidate**

A natural extension of the existing SHA-256 hash chain on `logs/*.jsonl`. The HASH bucket (vs PASS / REDACT / BLOCK) lets a redacted value remain verifiable: replace `user_email: zach@…` with `user_email_sha256: <hex>`; the line's hash still chains, but the raw value is gone. Adding ed25519 signatures over each line would let a third party verify the chain wasn't merely rewritten by someone with write access. Deferred because key storage / rotation / who-signs needs its own design pass — out of scope for this PR but recorded as the next hash-chain step.

### 4d. deer-flow — 4-failure-mode guards (middleware chain port) → **v1.x candidate**

zachflow's `docs/design-principles.md` already names the four failure modes (Drift / Self-deception / Context exhaustion / Recurring regressions) and maps each to documents. The deer-flow pattern shows how to make the table *executable*: one named script per mode, each emitting a typed event into `logs/*.jsonl`. The work is real (~4 new shell/python guards + workflow integration) and deserves a focused PR.

## 5. Skipped wholesale

- **LangGraph** itself — heavy framework lock-in; a Node-bash harness gets no free lift from adopting it.
- **ruflo's consensus protocols (Raft / Byzantine / Gossip)** — designed for distributed node disagreement; LLM agent failures are output errors, not node-state disagreement. Over-engineered for the problem class.
- **hermes's separate `web/` `ui-tui/` `gateway/` trees** — accidental complexity; zachflow stays markdown-bash-script first.

## 6. Forward links

- Implementation PR: `feat/v14-pattern-curator`
- Roadmap update: [`docs/roadmap.md`](../roadmap.md) — v1.x section gains 4 new candidates.
- Pattern lifecycle docs: [`docs/kb-system.md`](../kb-system.md) §Pattern Lifecycle (new).
