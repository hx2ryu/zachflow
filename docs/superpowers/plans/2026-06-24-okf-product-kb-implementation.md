# OKF Product KB 고도화 구현 계획

> **For agentic workers:** 이 문서는 OKF(Open Knowledge Format) 기준으로 `zachflow`의 KB를 learning memory 중심에서 product/domain memory까지 확장하기 위한 multi-PR 계획이다. 각 단계는 독립 PR로 실행 가능해야 하며, 체크박스(`- [ ]`)는 작업 추적용이다.

**Goal:** `.zachflow/kb/products/`를 OKF-compatible product knowledge bundle로 활성화해서, sprint 회고가 실패 패턴뿐 아니라 확정된 제품 지식(기능, API, 정책, 결정, 용어)을 장기 KB에 반영하게 만든다.

**Architecture:** GoogleCloudPlatform `knowledge-catalog`의 전체 도구체인이나 Google Cloud Knowledge Catalog 서비스를 도입하지 않는다. `zachflow`는 로컬 Git 기반 embedded KB가 핵심이므로, OKF의 포맷 원칙만 subset으로 채택한다: Markdown body, YAML frontmatter, `index.md`, stable resource id, tags, citations/source sprint, cross-links. GCP/BigQuery/Vertex AI 기반 reference agent와 `kcmd pull/push`는 선택 plugin 후보로만 남긴다.

**Source references:**
- OKF upstream: https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf
- OKF spec: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
- zachflow KB docs: `docs/kb-system.md`
- KB integration primitive: `workflows/_shared/kb-integration.md`
- Existing product placeholder: `.zachflow/kb/products/`

**Non-goals:**
- Google Cloud Knowledge Catalog managed service 연동
- BigQuery metadata crawler
- Vertex AI/Gemini enrichment agent
- SQLite/vector DB backend
- 기존 `learning/patterns`, `rubrics`, `reflections` schema의 breaking change

---

## Target Shape

새 product KB는 다음 형태를 목표로 한다.

```text
.zachflow/kb/
├── learning/
│   ├── patterns/
│   ├── rubrics/
│   └── reflections/
└── products/
    └── <product-slug>/
        ├── index.md
        ├── features/
        │   └── <feature-slug>.md
        ├── apis/
        │   └── <api-slug>.md
        ├── decisions/
        │   └── <decision-slug>.md
        ├── policies/
        │   └── <policy-slug>.md
        └── glossary/
            └── <term-slug>.md
```

공통 frontmatter 예:

```yaml
---
schema_version: 1
type: feature
title: Billing CSV export
resource: products/billing/features/csv-export
status: active
tags: [billing, export]
source_sprint: sprint-042
source_files:
  - runs/sprint/sprint-042/PRD.md
  - runs/sprint/sprint-042/api-contract.yaml
updated_at: "2026-06-24T00:00:00Z"
confidence: confirmed
---
```

---

## Implementation Phases

### Phase 0: ADR + Scope Freeze

**Purpose:** OKF adoption scope를 기록하고, GCP service 연동과 local OKF subset을 분리한다.

**Files:**
- Create or update: `docs/adr/NNNN-adopt-okf-compatible-product-kb.md`
- Update: `docs/roadmap.md`

**Tasks:**
- [ ] `docs/adr/` 존재 여부 확인.
- [ ] 없으면 사용자 승인 후 ADR scaffold 생성.
- [ ] 결정 문서에 다음을 명시:
  - Adopt OKF-compatible local product KB subset.
  - Do not adopt Google Cloud Knowledge Catalog as core dependency.
  - Keep external enrichment as optional plugin candidate.
- [ ] `docs/roadmap.md`에 "OKF-compatible Product KB" 항목 추가.

**Verification:**
- [ ] ADR status가 `accepted` 또는 `proposed`로 명확하다.
- [ ] roadmap에서 OKF scope와 non-goals가 한 줄로 구분된다.

**Rollback:** ADR/roadmap 변경만 revert하면 된다.

---

### Phase 1: Product KB Schema 정의

**Purpose:** product knowledge 문서의 최소 구조를 JSON Schema로 검증 가능하게 만든다.

**Files:**
- Create: `schemas/products/product-doc.schema.json`
- Create: `schemas/products/product-index.schema.json`
- Update: `docs/kb-system.md`
- Update: `tests/kb-smoke.sh`

**Schema draft:**
- Common required fields:
  - `schema_version`
  - `type`
  - `title`
  - `resource`
  - `status`
  - `updated_at`
- `type` enum:
  - `product_index`
  - `feature`
  - `api`
  - `decision`
  - `policy`
  - `glossary`
  - `prd`
- `status` enum:
  - `draft`
  - `active`
  - `deprecated`
  - `superseded`
- `confidence` enum:
  - `draft`
  - `inferred`
  - `confirmed`
- Optional:
  - `source_sprint`
  - `source_files`
  - `tags`
  - `superseded_by`
  - `related_resources`

**Tasks:**
- [ ] Define schemas under `schemas/products/`.
- [ ] Extend `tests/kb-smoke.sh` to validate `.zachflow/kb/products/**/*.md` frontmatter when present.
- [ ] Keep product validation skipped when `products/` is empty.
- [ ] Document schema in `docs/kb-system.md`.

**Verification:**

```bash
bash tests/kb-smoke.sh
python3 -c "import json; json.load(open('schemas/products/product-doc.schema.json'))"
python3 -c "import json; json.load(open('schemas/products/product-index.schema.json'))"
```

**Exit criteria:**
- Existing learning KB validation still passes.
- Empty `products/` remains valid.
- A sample product doc with valid frontmatter passes.
- A sample product doc missing `resource` fails in a focused test fixture.

**Rollback:** Remove `schemas/products/` and product validation branch from `tests/kb-smoke.sh`.

---

### Phase 2: Bootstrap Product Bundle Skeleton

**Purpose:** new project initialization이 OKF-compatible product KB를 만들 수 있게 한다.

**Files:**
- Update: `scripts/kb-bootstrap.sh`
- Update: `templates/init.config.template.yaml` if product slug is configurable
- Update: `MANUAL.md`
- Update: `docs/kb-system.md`
- Update or add tests around bootstrap

**Tasks:**
- [ ] `scripts/kb-bootstrap.sh`가 `.zachflow/kb/products/` root marker 또는 README를 생성하게 한다.
- [ ] 선택적으로 default product slug를 받는 방식을 결정한다.
  - Conservative default: only create `.zachflow/kb/products/.gitkeep` or `README.md`.
  - Rich default: create `.zachflow/kb/products/<project-slug>/index.md`.
- [ ] `--demo` mode에서는 demo product bundle을 생성한다.
- [ ] initialization docs에 product KB가 optional이며 비어 있어도 정상임을 설명한다.

**Verification:**

```bash
bash scripts/kb-bootstrap.sh
bash tests/kb-smoke.sh
bash tests/init-project-smoke.sh
```

**Exit criteria:**
- 기존 사용자 KB를 덮어쓰지 않는다.
- 반복 실행이 idempotent하다.
- product KB가 없는 프로젝트도 계속 정상 작동한다.

**Rollback:** `kb-bootstrap.sh` product branch와 관련 docs/tests만 revert.

---

### Phase 3: `zachflow-kb:read` Product Query 확장

**Purpose:** workflows와 plugins가 product KB를 직접 filesystem scan하지 않고 기존 KB skill 경로로 읽게 한다.

**Files:**
- Update: `.claude/skills/zachflow-kb/read/SKILL.md`
- Update: `workflows/_shared/kb-integration.md`
- Update: `docs/kb-system.md`
- Update: `tests/kb-smoke.sh` or add focused read skill smoke if available

**Supported queries:**
- `type=product`
- `type=feature`
- `type=api`
- `type=decision`
- `type=policy`
- `type=glossary`
- Filters:
  - `product=<slug>`
  - `tag=<tag>`
  - `status=active|draft|deprecated`
  - `limit=<N>`

**Tasks:**
- [ ] Define read protocol for product docs.
- [ ] Return file paths only, matching current `zachflow-kb:read` style.
- [ ] Sort active docs first, then newest `updated_at`.
- [ ] Reject unknown product type with explicit error.
- [ ] Update KB integration docs so Phase 2 can load product context.

**Verification:**
- [ ] Manual fixture: create temporary valid product docs, run the skill protocol steps, confirm expected paths.
- [ ] `bash tests/kb-smoke.sh`

**Exit criteria:**
- Learning queries behave exactly as before.
- Product queries never require direct filesystem reads from workflows.

**Rollback:** Remove product cases from read skill and docs.

---

### Phase 4: Product KB Write Protocol

**Purpose:** 회고 단계에서 "확정된 제품 사실"을 저장/갱신할 수 있는 안전한 write path를 만든다.

**Files:**
- Create: `.claude/skills/zachflow-kb/write-product-doc/SKILL.md`
- Create: `.claude/skills/zachflow-kb/update-product-doc/SKILL.md` or combine into one upsert skill
- Update: `docs/kb-system.md`
- Update: `tests/kb-smoke.sh`
- Update: `scripts/install-workflows.sh` only if workflow skill installation list requires it

**Write rules:**
- Product docs are Markdown with YAML frontmatter.
- `resource` is stable and path-like.
- `source_files` must point to sprint artifacts when created by Retro.
- `confidence` defaults to `inferred`; human-confirmed docs can be `confirmed`.
- Existing active docs are updated, not duplicated.
- Deprecated docs must use `superseded_by` when replacement exists.

**Tasks:**
- [ ] Decide write API shape:
  - Option A: one `write-product-doc` create-only skill plus `update-product-doc`.
  - Option B: one `upsert-product-doc` skill.
- [ ] Implement protocol with schema validation.
- [ ] Add examples for feature/API/decision/glossary docs.
- [ ] Add conflict guidance: if two docs claim same `resource`, update existing.

**Verification:**
- [ ] Create feature fixture and validate with `bash tests/kb-smoke.sh`.
- [ ] Update existing fixture and confirm `updated_at` changes without duplicate file.
- [ ] Invalid frontmatter fails schema validation.

**Exit criteria:**
- Agents have a sanctioned write path.
- Direct writes to `.zachflow/kb/products/` are documented as forbidden except manual human edits.

**Rollback:** Remove new write/update skills; product docs remain readable as static files.

---

### Phase 5: Sprint Phase 2 Product Context Injection

**Purpose:** Spec 단계에서 product KB를 읽어 PRD/task/API 설계에 반영한다.

**Files:**
- Update: `workflows/sprint/phase-spec.md`
- Update: `workflows/_shared/kb-integration.md`
- Update: `templates/sprint-contract.template.md` if product constraints should appear in contract

**Tasks:**
- [ ] At Phase 2 start, load product context:
  - active `feature`
  - active `api`
  - active `policy`
  - relevant `glossary`
- [ ] Define relevance selection:
  - product slug from sprint config or PRD path
  - tags from PRD title/sections
  - fallback to product index only
- [ ] Add "Product Context Used" section to spec outputs.
- [ ] Prevent over-injection: cap docs read per type.

**Verification:**
- [ ] Dry-run with sample product docs and a sample PRD.
- [ ] Confirm generated spec cites product resource ids.
- [ ] Confirm no product docs means Phase 2 continues normally.

**Exit criteria:**
- Product facts influence spec, but do not replace PRD acceptance criteria.
- Source resource ids are visible in generated spec artifacts.

**Rollback:** Remove Phase 2 product context block.

---

### Phase 6: Sprint Phase 6 Product Knowledge Update

**Purpose:** 회고가 learning KB뿐 아니라 product KB를 갱신하게 만든다.

**Files:**
- Update: `workflows/sprint/phase-retro.md`
- Create or update: `templates/product-kb-candidate.template.yaml`
- Update: `docs/kb-system.md`

**New Retro artifact:**

```text
runs/sprint/<sprint-id>/retrospective/product-kb-candidates.yaml
```

Candidate shape:

```yaml
items:
  - type: feature
    title: Billing CSV export
    resource: products/billing/features/csv-export
    status: active
    confidence: inferred
    source_files:
      - runs/sprint/<id>/PRD.md
      - runs/sprint/<id>/api-contract.yaml
    summary: Users with finance access can export billing history as CSV.
    action: create
```

**Tasks:**
- [ ] Add Phase 6 step after pattern digest and before final report finalization.
- [ ] Extract product facts from:
  - PRD
  - spec/task outputs
  - API contract
  - prototype amendments
  - evaluation reports
  - deferred items
- [ ] Classify candidate types: feature/api/decision/policy/glossary.
- [ ] Match candidates against existing product docs by `resource`.
- [ ] Apply write/update only when confidence threshold is met.
- [ ] Keep inferred candidates in retrospective artifact if not written.

**Verification:**
- [ ] Fixture sprint with new API creates an `api` candidate.
- [ ] Fixture sprint with changed permission policy creates a `policy` or `decision` candidate.
- [ ] Existing doc update does not create duplicate.
- [ ] `bash tests/kb-smoke.sh`

**Exit criteria:**
- Every product KB write has `source_sprint` and `source_files`.
- Uncertain inferred facts are visible but not silently promoted to active confirmed knowledge.

**Rollback:** Remove Phase 6 product candidate/write step; retrospective artifacts remain harmless.

---

### Phase 7: Recall Plugin Product KB Search

**Purpose:** `/recall:ask`가 sprint artifacts와 learning KB뿐 아니라 product KB도 sources로 사용할 수 있게 한다.

**Files:**
- Update: `plugins/recall/ask/SKILL.md`
- Update: `plugins/recall/config/recall.example.yaml`
- Update: `plugins/recall/config/recall.schema.json`
- Update: `plugins/recall/README.md`
- Update: `plugins/recall/tests/test_config.sh`

**Tasks:**
- [ ] Add config:

```yaml
sources:
  products:
    path: ${KB_PATH:-./.zachflow/kb}/products
    layout: okf-product-kb
```

- [ ] Teach recall to search product docs by title/tags/resource.
- [ ] Sources block must include product doc paths.
- [ ] Keep product KB optional.

**Verification:**

```bash
bash plugins/recall/tests/test_config.sh
bash plugins/recall/tests/test_session.sh
bash tests/kb-smoke.sh
```

**Exit criteria:**
- Recall can answer "what is the current billing export policy?" from product KB.
- Existing recall sessions without product KB still pass.

**Rollback:** Revert recall config/schema/SKILL changes.

---

### Phase 8: Gallery / Docs Surface

**Purpose:** product KB를 사람이 검토하기 쉬운 문서/카탈로그로 노출한다.

**Files:**
- Update: `packages/zachflow-gallery/src/pages/index.astro`
- Add: `packages/zachflow-gallery/src/pages/kb/[product]/[...resource].astro` or equivalent
- Add components as needed under `packages/zachflow-gallery/src/components/`
- Update: `packages/zachflow-gallery/README.md`

**Tasks:**
- [ ] Add product KB index page.
- [ ] Render product docs grouped by type.
- [ ] Show resource id, status, tags, source sprint.
- [ ] Link related resources.
- [ ] Avoid making gallery required for KB usage.

**Verification:**

```bash
npm run gallery:build
```

**Exit criteria:**
- Gallery builds with no product docs.
- Gallery builds with sample product docs.
- Broken frontmatter is caught by KB smoke before gallery render.

**Rollback:** Remove gallery product routes/components.

---

### Phase 9: Optional OKF Import/Export Plugin

**Purpose:** 외부 OKF bundle과 `zachflow` product KB 간 상호운용을 plugin으로 제공한다.

**Files:**
- Create: `plugins/okf/README.md`
- Create: `plugins/okf/import/SKILL.md`
- Create: `plugins/okf/export/SKILL.md`
- Create: `plugins/okf/scripts/install.sh`
- Create: `plugins/okf/scripts/uninstall.sh`
- Create: `plugins/okf/config/okf.schema.json`
- Create tests under `plugins/okf/tests/`

**Tasks:**
- [ ] Follow `docs/plugin-authoring.md` structure.
- [ ] Import external OKF bundle into `.zachflow/kb/products/<slug>/`.
- [ ] Export product KB as OKF-compatible directory.
- [ ] Validate before import and after export.
- [ ] Keep GCP service sync out of scope.

**Verification:**

```bash
bash scripts/install-plugins.sh --list
bash plugins/okf/tests/test_import.sh
bash plugins/okf/tests/test_export.sh
bash tests/kb-smoke.sh
```

**Exit criteria:**
- Users can exchange local OKF bundles without installing cloud dependencies.
- Plugin is optional and core does not depend on it.

**Rollback:** Remove `plugins/okf/` and CI references.

---

## Parallelization

Recommended dependency graph:

```text
Phase 0
  -> Phase 1
      -> Phase 2
      -> Phase 3
          -> Phase 5
          -> Phase 7
      -> Phase 4
          -> Phase 6
              -> Phase 8
Phase 9 can start after Phase 1, but should merge after Phase 4.
```

Parallel-safe work:
- Phase 2 and Phase 3 can proceed after schemas land.
- Phase 7 can proceed after read semantics are stable.
- Phase 8 can proceed with fixture docs after schemas land.
- Phase 9 should wait until product write semantics settle.

---

## Acceptance Criteria

- [ ] `.zachflow/kb/products/` has a documented, schema-validated OKF-compatible structure.
- [ ] Existing learning KB behavior is unchanged.
- [ ] Product docs are optional; empty product KB never breaks sprint/qa-fix.
- [ ] `zachflow-kb:read` can return product document paths by type/product/tag/status.
- [ ] Retro can produce product KB candidates and write/update confirmed docs through KB skills.
- [ ] Phase 2 can consume product docs as context with source resource ids.
- [ ] `recall:ask` can answer product knowledge questions with Sources.
- [ ] Gallery can render product KB docs when present.
- [ ] No core dependency on Google Cloud Knowledge Catalog, BigQuery, Vertex AI, or external network.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Product KB becomes noisy with inferred facts | Use `confidence`, require source files, keep uncertain items as candidates |
| Product docs duplicate each other | Stable `resource` id, update-before-create rule |
| Agents over-read product KB and waste context | Use index-first search and per-type limits |
| OKF upstream spec changes | Call this `OKF-compatible subset`, not full compliance |
| Workflow docs diverge from implementation | Add KB smoke checks and docs examples in the same PR as schema changes |
| Core gets cloud-coupled | Keep GCP sync/enrichment in optional plugin only |

---

## Suggested First PR

Start with Phase 1 only:

1. Add product schemas.
2. Extend `tests/kb-smoke.sh` for product frontmatter when present.
3. Update `docs/kb-system.md` to define product KB layout.
4. Add one fixture-based validation path if the test suite has a suitable pattern.

This creates the foundation without changing runtime workflow behavior.
