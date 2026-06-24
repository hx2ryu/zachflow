# Roadmap

## v1.0 ✓ shipped 2026-04-29

- [x] Sprint 0 — Bootstrap: clean repo + sanitized core
- [x] Sprint 1 — KB embedded mode + skill rename (`zzem-kb:*` → `zachflow-kb:*`)
- [x] Sprint 2 — Workflow split: `workflows/{sprint,qa-fix,_shared}/` + `/qa-fix` first-class
- [x] Sprint 3 — Stack adapter: placeholder templates + `init-project.sh` wizard
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [x] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release

## v1.x (post v1.0)

- [x] Pattern lifecycle automation (Phase 6.7b) — schema v2 + `scripts/lib/curator.py` + `zachflow-kb:{promote,archive,list-stale}` skills (informed by hermes-agent benchmark; see [`docs/benchmarks/2026-05-three-agent-frameworks.md`](benchmarks/2026-05-three-agent-frameworks.md))
- [x] Adversarial Evaluator (T2-C) — read-only red-team teammate auto-spawned after standard PASS, probes Security / Race / Malformed input / Resource exhaustion; build-loop §Adversarial Second Pass + `.claude/teammates/evaluator-adversarial.md`
- [x] 4 failure-mode guards — `scripts/lib/guards/{drift,self_deception,context,regression}_guard.py` make `docs/design-principles.md` §Failure Modes executable; emit hash-chained events to `logs/guards.jsonl` (deer-flow middleware-chain port)
- [x] `/sprint --health` per-sprint outcome aggregator — `scripts/lib/sprint-health.py` aggregates evaluations, evaluator rounds, project-scoped `logs/guards.jsonl` filtered by sprint, and sprint-contributed patterns + curator transitions on them. Companion to the existing `--status` mode (which shows progress); `--health` shows outcomes
- OKF-compatible Product KB — local Markdown/YAML product/domain memory under `.zachflow/kb/products/`; no core dependency on Google Cloud Knowledge Catalog, BigQuery, Vertex AI, or external network services
- KB drift detection completion (T2-F) — add `confidence` + `category` typed-fact fields and threshold-based pruning on top of the curator's TTL archive (deer-flow typed-facts port)
- Hash-chain ed25519 signing — extend `logs/*.jsonl` with detached ed25519 signatures and a `HASH` redaction bucket for verifiable PII handling (ruflo audit-record port)
- KB embedded → remote migration wizard
- External stack adapter examples (community PRs)
- Multi-LLM platform support (informed by `zzem-orchestrator` Codex experimentation — see [`llm-platform-coupling.md`](llm-platform-coupling.md))
- Official docs site
- Sprint Gallery content system generalization
- Additional plugins (Notion sync, Slack notifications, etc.) following the `plugins/recall/` reference pattern
- KB validation hardening — adopt JSONSchema config validation pattern from recall plugin
- KB unit test expansion — adopt shell-based `test_*.sh` pattern from recall plugin

## v2.0 (deferred)

- Workflow yaml DSL / plugin lifecycle hooks
- Plugin system for KB backends (sqlite, cloud)
- Multi-language teammate templates (stack pack catalog)
