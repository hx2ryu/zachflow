# Sprint Contract: Group {N}

> Before implementation begins, this contract is the place where Generator (Engineer) and Evaluator agree on what "done" means.
> The Sprint Lead drafts the contract; the Evaluator reviews and signs off; only then does implementation start.

## Scope

- **Sprint**: {sprint-id}
- **Tasks**:
  - `{task-id-1}`: {objective}
  - `{task-id-2}`: {objective}
- **API Endpoints**: {related endpoints from api-contract.yaml}

## Done Criteria

Each criterion must be verifiable in code. Ambiguous criteria are not allowed.

### Task: {task-id-1}

- [ ] {testable criterion 1 — e.g. "POST /api/profiles returns 201 + creates a profile record in the DB"}
- [ ] {testable criterion 2 — e.g. "When nickname is omitted, the server-generated nickname is ≤ 8 chars"}
- [ ] {testable criterion 3}

### Task: {task-id-2}

- [ ] {testable criterion 1}
- [ ] {testable criterion 2}

## Verification Method

Specify **how** the Evaluator verifies each criterion.

| Criterion | Verification |
|-----------|--------------|
| {criterion 1} | Trace Controller → Service → Repository |
| {criterion 2} | Edge cases: null input, empty string, max-length overflow |
| {criterion 3} | Compare API contract schema against actual DTO types |

### Default Verification Gates

These grep/trace gates are included by default in every Contract. Exclude only when explicitly noted.

- [ ] **No mapper fallbacks** (KB: completeness-008) — When extending Entity/DTO, fallbacks must not break semantics:
  - `rg '{fieldName}\s*\?\?\s*(0|false)|\|\|\s*""' src` → 0 hits required
  - Enforce required fields in Zod (`.nonnegative()` / `.boolean()`); on parse failure, skip the item (no fallback)
  - Exception: only when the field is intentionally optional (state explicitly in Contract)

- [ ] **No dead hooks/methods/factories** (KB: completeness-009) — When adding hooks/factories/components:
  - `rg '{hookName}\(' src --glob '*.tsx' --glob '*.ts'` → ≥ 1 real call site
  - Definition with 0 call sites → Major verdict
  - Contract must specify the call site (component name + invocation condition)

- [ ] **Cross-component exhaustive listing** (KB: completeness-010) — When extending Entity/DTO:
  - Contract §Scope or §Cross-group Integration must enumerate every affected endpoint/path
  - For discriminated union with 3+ variants, trace each variant through the mapper
  - Replace blanket terms ("all", "every", "each") with concrete path lists

### FE typecheck clean

- [ ] `<typecheck command for the FE workspace>` → 0 new errors (existing cascade excluded)
- [ ] When extending route types, exhaustively check every call site

### BE cursor convention

- [ ] `rg '_id:\s*\{\s*\$lt\s*:' <backend-persistence-path>` → 0 new hits (cursor must use `$lte`)
- [ ] Compound cursor uses `(sort_key, _id) <= cursor` form for tie-breaks

### E2E test inclusion check

- [ ] When a new `*.e2e-spec.ts` is added, `<list-e2e-tests command> | grep {spec}` confirms inclusion
- [ ] project.json::test-e2e target + jest-e2e.json::moduleNameMapper present

## Edge Cases to Test

- {edge case 1}: {expected behavior}
- {edge case 2}: {expected behavior}

## Business Rules to Validate

- {rule 1}: {how it should be reflected in code}
- {rule 2}: {how it should be reflected in code}

## Cross-Task Integration Points

- {integration point}: {what to verify}

---

_Evaluator review complete: {date} / {agreement status}_

## Prior Group Lessons (required for follow-up sprints)

> Starting from the second group of a follow-up sprint, the Evaluator must reference
> the prior group's checkpoint "Lessons for Next Group" section, and systematically
> check Round 1 reviews for the same class of issues.

**Reference prior checkpoints**:
- `runs/{prev-sprint-id}/checkpoints/group-{N-1}-summary.md` § Lessons for Next Group
- `runs/{prev-sprint-id}/retrospective/pattern-digest.yaml` § patterns (especially frequency ≥ 2)

## KB Pattern Clauses (auto-injected)

> When the Sprint Lead drafts the Contract, run `zachflow-kb:read` (type=pattern, category=relevant)
> and inject the returned files' `contract_clause` into Done Criteria. KB access only via `zachflow-kb:*` skills.
>
> Format: `- [ ] {clause text} (KB: {pattern-id})`
>
> Injection criteria:
> - `severity: critical` → always inject
> - `severity: major` + `frequency >= 2` → inject
> - `severity: minor` → do not inject

## Evaluator Round 1 Checklist

> Run through this list when reviewing the Contract.

- [ ] Replace blanket terms ("all", "every", "each", "related") with concrete path/endpoint lists
- [ ] New hooks/factories/components have call-site grep gates
- [ ] Entity/DTO extensions have fallback-prohibition grep gates
- [ ] Risk of recurrence from prior sprint retrospective patterns has been assessed
- [ ] When storage primitives are mentioned, the actual codebase wrapper is named (e.g. MMKV vs AsyncStorage)
- [ ] No internal Contract contradictions (e.g. same scenario specifying different UI behavior)
