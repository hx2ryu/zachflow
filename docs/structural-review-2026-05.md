# Structural Review — zachflow as Enterprise AI-Native Workflow

**Date:** 2026-05-13
**Reviewer:** internal (assisted)
**Scope:** zachflow v1.2.0 as currently shipped
**Frame:** "Can zachflow replace enterprise AI-native dev workflows?"

This is a direction-setting document, not a commit punch list. It is the source of truth for the v1.x positioning decision made on this date.

---

## Verdict

zachflow is a strong **1-person to small-team harness**. It is **not** an enterprise-platform replacement — by design, and that is fine. The 9 design principles solve real LLM-agent failure modes (drift, self-deception, context exhaustion, recurring regressions). The control-plane layer that enterprises require (audit, cost attribution, RBAC, multi-LLM, dashboards) is mostly absent.

The chosen direction is **A) Consolidate solo/small-team strengths**. Enterprise build-out (option B) is correctly out of scope at current capital and team size. Partnership integration (option C) is a future fallback.

---

## What zachflow does well

| Design decision | Why it matters | Where it lives |
|---|---|---|
| Planner ≠ Generator ≠ Evaluator (separate agents) | Blocks self-evaluation optimism | `workflows/_shared/agent-team.md` |
| Sprint Contract before code | Surfaces disagreement in spec, not review | `workflows/_shared/build-loop.md` §Contract |
| Active Evaluation (logic trace + edge probe) | Static checks miss real defects | `workflows/_shared/build-loop.md` §Evaluate |
| File-based handoff, no chat-memory dependency | Deterministic + resumable (`--resume`) | `workflows/_shared/agent-team.md` §Cross-Task Communication |
| Worktree isolation + group-scoped merges | Concurrent-sprint contamination blocked | `workflows/_shared/worktree.md` |
| Budget Pressure Protocol (Normal→Caution→Urgent) | Active steering before context exhaustion (Hermes-style) | `workflows/_shared/build-loop.md` §Budget Pressure |
| Frozen Snapshot Protocol | Stops token explosion in 4-agent × multi-call loops | `workflows/_shared/build-loop.md` §Frozen Snapshot |
| Pattern → Rubric → Reflection KB cycle | Retro feeds forward into next Contract automatically | `docs/kb-system.md` §Lifecycle |
| 9 Design Principles, declared non-negotiable | Refactor-safety: future maintainers know what is the asset | `docs/design-principles.md` |

These are **not derivative**. They reflect real production experience with long-running agentic loops. This is the IP worth protecting.

---

## Enterprise control-plane requirements (the comparison baseline)

```
┌────────────────────── ENTERPRISE CONTROL PLANE ──────────────────────┐
│                                                                        │
│  Identity & Access (SSO/RBAC/team boundary)                            │
│  Audit & Compliance (SOC2 trail: who/when/which model/which prompt)    │
│  Cost & Usage Observability (per-team/per-sprint LLM attribution)      │
│  Multi-LLM Vendor Neutrality                                           │
│  Multi-Repo / Multi-Tenant Orchestration                               │
│  CI/CD & PR Gate Integration                                           │
│  Issue Tracker / PM Tool Suite (Jira·Linear·Notion·Confluence)         │
│  Observability & SLO (metrics/logs/traces, dashboards, alerts)         │
│  Secrets / Supply Chain Security                                       │
│  Data Residency (on-prem / VPC / air-gap)                              │
│  Reliability (retries, idempotency, partial-failure recovery)          │
│  Onboarding-at-Scale (IaC, Terraform, fleet management)                │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
                              ▲
                              │  zachflow operates here
                              ▼
┌─────────────────────── WORKFLOW LAYER ───────────────────────────────┐
│                                                                        │
│  Planner-Generator-Evaluator orchestration         strong              │
│  Sprint Contract / Build Loop / Active Eval        strong              │
│  File-based handoff / Worktree isolation           strong              │
│  KB-driven self-improvement                        strong              │
│  QA-Fix (Jira) post-sprint pipeline                present (Jira only) │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

The workflow layer scores 7–8/10. The control plane scores 1–2/10. That is the entire gap.

---

## Gap analysis

### Tier 1 — enterprise adoption blockers

| Gap | Impact | Current state |
|---|---|---|
| **T1-A** Single-LLM lock-in (Claude Code only) | Procurement cannot sign. Exposed to model price/policy shifts | `docs/llm-platform-coupling.md` acknowledges. On v1.x roadmap |
| **T1-B** No cost/usage observability | No chargeback, no per-team budget enforcement | `logs/*.jsonl` exists but no token/cost aggregation |
| **T1-C** No RBAC / org / team boundary | Per-developer per-project CLI. No human permission model | Sprint Lead has merge authority by convention only |
| **T1-D** No tamper-evident audit log | SOC2/ISO27001 sign-off impossible | `logs/*.jsonl` exists but no append-only or hash-chain guarantee |
| **T1-E** No central control plane / dashboard | 50-project fleet view absent | Per-sprint `--status` only. No org-level view |
| **T1-F** No secrets / token rotation guidance | Jira/npm/git tokens via env var only. No vault integration | Not addressed in docs |
| **T1-G** No data residency / on-prem option | Locks out finance/healthcare/public sector (Claude API egress required) | Architecture assumes hosted Claude API |
| **T1-H** No multi-repo orchestration | 100-repo orgs cannot do cross-repo (BE+iOS+Web) changes coherently | Each repo = independent zachflow project |

### Tier 2 — functional gaps

| Gap | Impact |
|---|---|
| **T2-A** PM tool single (Jira-only, qa-fix-scoped) | Linear/Asana/Notion users must write adapters themselves |
| **T2-B** No PRD ingestion channel | Notion/Confluence/Google Docs PRDs are manually copy-pasted in |
| **T2-C** Evaluator is single-pass | Adversarial / red-team / security review not part of Active Evaluation |
| **T2-D** No deploy/canary integration | Build Loop ends at sprint-branch merge. Deploy + rollback is a separate domain |
| **T2-E** Workflow DSL is markdown + bash | Flexible but hard to validate/diff/version. YAML DSL is v2.0 only |
| **T2-F** No KB drift detection | Patterns can go stale without surfacing |
| **T2-G** No metrics emission (otel/prom) | Sprint pass rate, avg fix-loop count, time-to-PR are not captured |
| **T2-H** PR review is human-enforced | Sprint Lead opens PRs but reviewer assignment / checklist enforcement is absent |

### Tier 3 — UX / scale gaps

| Gap | Impact |
|---|---|
| **T3-A** No web UI — all CLI | PM/design/leadership have zero visual visibility |
| **T3-B** Onboarding = 5-min wizard | Great for solo. Enterprise IaC (Terraform/Helm) is zero |
| **T3-C** KB is project-local | No cross-team learning. Remote KB is v1.x roadmap |
| **T3-D** No v1→v2 migration path | How does a 50-project org upgrade simultaneously? |
| **T3-E** No test-framework autodetect | Sprint Phase 4 test gate is stack-blind |

---

## Skill inventory

### Present

```
WORKFLOW SKILLS
  ├── sprint              core
  └── qa-fix              Jira QA cycle

KB SKILLS (zachflow-kb:*)
  ├── read, sync          query / pull
  ├── write-pattern,
      update-pattern      pattern accumulation
  ├── write-reflection    sprint-end record
  └── promote-rubric      append-only; version-bump is manual

PLUGIN (recall:*)
  └── ask                 past-sprint / KB recall
```

### Missing for enterprise

```
OBSERVABILITY
  ├── usage:cost-report                   missing  (Tier 1)
  ├── usage:token-budget-check            missing
  ├── metrics:export (otel/prom)          missing
  ├── sprint:fleet-dashboard              missing
  └── compliance:audit-export             missing  (SOC2)

GOVERNANCE
  ├── org:config (RBAC, team mapping)     missing
  ├── policy:enforce                      missing
  └── secrets:rotate                      missing

QUALITY GATES (Evaluator augmentation)
  ├── eval:security-review                missing  (T2-C)
  ├── eval:adversarial / red-team         missing
  ├── eval:performance (N+1, mem, SLO)    missing
  └── eval:accessibility                  missing

INTEGRATION ADAPTERS
  ├── prd:sync-from-notion / confluence   missing  (T2-B)
  ├── issues:linear-adapter               missing  (T2-A)
  ├── deploy:canary-gate                  missing  (T2-D)
  └── pm:roadmap-sync                     missing

PLATFORM PORTABILITY
  ├── codex / aider / cursor adapter      missing  (T1-A)
  └── multi-llm:route                     missing

KB GOVERNANCE
  ├── kb:validate (user content)          partial  (CI only, no skill)
  ├── kb:drift-detect                     missing
  └── kb:promote-rubric (auto version)    partial
```

Workflow core: 7–8/10. Governance / observability / integration adapters: 1–2/10.

---

## Failure scenarios — what breaks if forced into enterprise

| Scenario | Trigger | Current response | UX |
|---|---|---|---|
| 100 devs running concurrent sprints | Fleet adoption | No dashboard. Visibility = 0 | PM panic |
| Claude API price doubles | External | Cannot swap LLM in place | Cost runaway, lock-in surfaced |
| Security audit demands trail | SOC2 renewal | git log + jsonl exist, tamper-evidence absent | Audit fail |
| 1000-ticket QA-fix run | Bulk cleanup | Sequential group merge → too slow | Week-plus runtime |
| Sprint Lead session dies | Net/host failure | `--resume` works, but no dashboard surfaces the dead run | Hidden stall until human notices |
| KB pattern goes stale | 6 months of use | No drift detection. Stale clause injected into Contract | New sprints follow obsolete rules |
| External PRD changes | Notion edit | No sync. Manual copy required | Spec drift |

**Critical gaps** (silent failure — operator does not even notice the break): **T1-D (audit), T1-G (data residency), T1-C (RBAC), T2-G (metrics)**.

---

## Positioning options considered

```
                ┌─ A) Solo/Small-Team Harness — current strength held
                │     OSS dev / boutique studio / indie hacker
                │     Keep the 9 Principles. Do not build control plane.
                │
zachflow next  ─┼─ B) Enterprise Control Plane build-out
12 months       │     Fill all 8 Tier-1 gaps. 12–24 months. Team of 5–10.
                │     Red ocean (Cursor / Devin / Factory / Sourcegraph).
                │
                └─ C) Harness Layer inside a bigger platform
                      Backstage / GitHub / GitLab plugin.
                      Outsource control plane; zachflow keeps workflow IP.
```

| Option | Strength | Cost | Risk | Score |
|---|---|---|---|---|
| A) Solo/Small-Team consolidation | Plays current strength. OSS momentum. | Low | TAM narrow. Zero enterprise revenue. | ★★★ |
| B) Full enterprise build | Large TAM | 12–24 months + 5–10 engineers | Red-ocean feature-parity competition | ★ |
| C) Harness-as-plugin | Faster enterprise reach | Partnership + contract cost | Distribution dependent on partner | ★★ |

**Decision (2026-05-13): A.**
Path: A now → C if enterprise inbound signal emerges → B only with capital + team in place.

---

## Immediate actions for A (cost-low, value-high)

These four land as separate PRs, sequentially. They consolidate the current strengths without expanding scope.

1. **Extend `tests/kb-smoke.sh` to validate `.zachflow/kb/` user content.**
   - `docs/kb-system.md` already calls this "forward-compatible".
   - Schemas exist at `schemas/learning/`.
   - Boil the lake: user-side KB drift catches itself in CI.

2. **Automate `promote-rubric` version-bump.**
   - Today: skill appends to Promotion Log; rubric version is bumped by hand.
   - Close the loop: when N promotions accumulate (or on explicit `--bump`), produce `rubrics/v{N+1}.md` and mark prior `status: superseded`.

3. **`/sprint --status` cross-sprint dashboard.**
   - Today: status is per-sprint-id.
   - Add: zero-arg `/sprint --status` lists all in-flight sprints with phase, group, fix-loop count, last-checkpoint timestamp.
   - Mini-version of T1-E. Same project, multiple sprints. Not a fleet view yet.

4. **`logs/*.jsonl` append-only + hash chain.**
   - Today: jsonl is plain append, no tamper evidence.
   - Add: each line includes `prev_hash` + `hash`. CI validates the chain.
   - Real audit log is bigger than this. This is the minimum tamper-detection floor.

If a C-signal arrives (enterprise pilot inquiry, design-partner offer), add:

5. **Multi-LLM adapter spike — pick one (Codex).**
   - `llm-platform-coupling.md` documents the coupling surface but ships no implementation.
   - One concrete port validates the abstraction.

---

## What this document does NOT decide

- It does not commit to a v1.x release schedule.
- It does not promise any of the four actions ship before some external date.
- It does not foreclose option C — that re-opens the day a credible partner appears.
- It does not foreclose option B — that re-opens the day capital is in place and a clear design-partner pipeline exists.

---

## Cross-reference

- Memory: `project_zachflow_status.md` next entry point is **npm publish 403 diagnosis**. That work is independent of this document. The 403 unblock should land before action 1 starts.
- Roadmap: `docs/roadmap.md` v1.x bullets that map to these actions:
  - "KB validation hardening — adopt JSONSchema config validation pattern from recall plugin" → Action 1.
  - "KB unit test expansion — adopt shell-based test_*.sh pattern from recall plugin" → Action 1 / 2.
- Design coupling doc: `docs/llm-platform-coupling.md` — pre-work for Action 5 (deferred until C-signal).
