# Design Principles

These nine principles are the foundation of zachflow's harness design. They are non-negotiable for v1.x.

## 1. Planner–Generator–Evaluator separation

Generation and evaluation are performed by *different* agents. Self-evaluation is structurally unreliable — an agent that wrote code optimistically interprets its own output. The Evaluator is independent and read-only.

## 2. Sprint Contract before code

Before any line of code is written for a feature group, the Generator(s) and Evaluator agree in writing on Done Criteria and Verification Method. This forces the disagreement to surface in spec, not in review.

## 3. Feature-by-feature iteration

Sprints decompose into groups sized so the Build Loop (Contract → Implement → Evaluate → Fix) completes in 1–2 hours. Larger units accumulate context debt.

## 4. Active Evaluation

The Evaluator does not check whether files exist or functions are defined. It traces execution flow, probes edge cases (boundary values, null, permission), and verifies business rules against code. Static checks are necessary but insufficient.

## 5. Deliverable-focused spec

Specifications define *what* the result must be, not *how* to implement. Implementation details are the Generator's domain. Premature how-spec produces brittle code and frustrated Generators.

## 6. File-based handoff

Agents communicate via structured artifacts on disk: `tasks/*.md`, `contracts/*.md`, `evaluations/*.md`, `checkpoints/*.md`. Chat memory is unreliable; files are auditable.

## 7. Minimal harness

Scaffolding is removed wherever the model can self-manage. The harness exists to prevent failure modes (drift, self-deception, context exhaustion, recurring regressions — see "Failure Modes" below), not to enforce ceremony.

## 8. Context checkpoint

Every phase or group transition produces a structured summary file. Subsequent phases reference the checkpoint, not the original artifacts. Auto-compaction is a fallback, not the strategy.

## 9. Cross-session knowledge

Patterns discovered in retrospect (`Pattern Digest`) feed forward into future Sprint Contracts via the Knowledge Base. Self-improvement is the long-game lever.

## Failure Modes

The nine principles are not nine separate solutions — they form a distributed design constraint against four LLM-agent failure modes that recur in long-running, agentic coding sessions. Every principle exists to push back against at least one mode; most push back against several. The harness does not eliminate these modes; it makes them surface early, in artifacts and verdicts, rather than silently in shipped code.

| Mode | What it looks like | Why agents fall into it |
|---|---|---|
| **Drift** | Agent strays from the original spec into incidental refactors, extra features, "while-I'm-here" cleanups | Easier to do something nearby than to stay narrowly on-spec; instruction-following decays as context grows |
| **Self-deception** | Agent reads its own output optimistically; declares broken code "done" or "fine" | Output it produced gets the benefit of the doubt — the same bias humans have when reviewing their own work |
| **Context exhaustion** | Decision quality degrades as the context window fills with prior reasoning, prior code, prior reports | Token pressure → less attention on each new instruction; auto-compaction loses load-bearing detail |
| **Recurring regressions** | The same defect pattern reappears in sprint N+1 that was already fixed (or learned about) in sprint N | No mechanism to carry hard-won lessons forward beyond the in-session memory of one agent |

### How the principles map

| Mode | Principles that push back | Mechanism (in this repo) |
|---|---|---|
| **Drift** | §2 Sprint Contract before code, §5 Deliverable-focused spec, §7 Minimal harness | `workflows/_shared/build-loop.md` §Contract Phase Detail (Done Criteria are written + signed off by the Evaluator before any code), §Frozen Snapshot Protocol (KB + design + contract loaded once, then immutable for the group), §Budget Pressure Protocol Caution/Urgent levels inject "no incidental improvements" into task descriptions |
| **Self-deception** | §1 Planner–Generator–Evaluator separation, §4 Active Evaluation, §6 File-based handoff | `workflows/_shared/agent-team.md` §Read-only Constraint (Evaluator never edits — verdict is the only output); `workflows/_shared/build-loop.md` §Evaluate Phase Detail ("assume there is a bug, find it" + logic tracing + edge-case probing — not file/function existence checks); all artifacts live on disk for the next agent to audit |
| **Context exhaustion** | §3 Feature-by-feature iteration, §8 Context checkpoint | `workflows/sprint/SKILL.md` §Checkpoint System (subsequent phases reference checkpoints, not originals); §Progressive File Reading (`offset`/`limit` on long files); `workflows/_shared/build-loop.md` §Budget Pressure Protocol (Hermes IterationBudget pattern — Normal → Caution → Urgent reshapes agent behavior before context runs out) |
| **Recurring regressions** | §9 Cross-session knowledge | `docs/kb-system.md` §Lifecycle (Pattern Digest → Promotion Log → Rubric → automatic injection into the next sprint's Contract); `workflows/sprint/phase-modes.md` §--follow-up (Regression Guard re-verifies prior sprint's AC in the follow-up sprint) |

### What the harness does NOT do

- It does not enforce. An agent that decides to ignore Done Criteria can — there is no runtime jailer. The Evaluator catches the result, not the intent.
- It partially verifies the verifier. After the standard Evaluator returns PASS, the Adversarial Evaluator (`.claude/teammates/evaluator-adversarial.md`) runs a single read-only second pass probing four spec-orthogonal surfaces — Security / Race / Malformed input / Resource exhaustion. This catches the *false-PASS* failure mode in those four categories. What it does not catch: a wrong ISSUES/FAIL verdict, or false PASS outside those four surfaces. Multi-LLM cross-evaluation for the full verdict surface still belongs to a later phase (`docs/llm-platform-coupling.md`).
- It detects KB staleness partially. The pattern curator (`scripts/lib/curator.py` + `zachflow-kb:list-stale`) archives stable patterns whose `use_count` stays at zero past a TTL — so prose-stale patterns are eventually flushed. What it does *not* yet detect: a pattern whose content is *wrong* but still referenced (the high-cosine-similarity-for-bad-reasons case). Confidence-scored drift detection remains on the v1.x roadmap (see `docs/structural-review-2026-05.md` §T2-F and `docs/roadmap.md`).

These limits are the boundary between option A (solo / small-team harness, where the current shape is correct) and option B (enterprise control plane, where verification needs verification).
