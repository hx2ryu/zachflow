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

Scaffolding is removed wherever the model can self-manage. The harness exists to prevent failure modes (drift, self-deception, context exhaustion), not to enforce ceremony.

## 8. Context checkpoint

Every phase or group transition produces a structured summary file. Subsequent phases reference the checkpoint, not the original artifacts. Auto-compaction is a fallback, not the strategy.

## 9. Cross-session knowledge

Patterns discovered in retrospect (`Pattern Digest`) feed forward into future Sprint Contracts via the Knowledge Base. Self-improvement is the long-game lever.
