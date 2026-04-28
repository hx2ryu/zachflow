# Sprint 1 — KB Embedded Mode Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec (Section 2 — KB strategy)
> Sprint context: zachflow v1.0 의 Sprint 1 — Sprint 0 (bootstrap, `v0.1.0-bootstrap` 태그) 직후

## Problem

Sprint 0 는 KB 의 **placeholder** 만 남겼다:
- `scripts/kb-bootstrap.sh` 가 `.zachflow/kb/{learning/{patterns,rubrics,reflections},products}/` 디렉토리만 생성
- Sprint phase skills 가 `zachflow-kb:read`, `zachflow-kb:write-pattern` 등을 참조하지만 **실제 skill 파일은 존재하지 않음**
- v1.0 ship gate ("Claude Code 기반 sprint runner bootstrap 가능") 를 만족하려면 KB skill 들이 작동해야 함 (Phase 2 spec, Phase 4.1 contract, Phase 6 retro 모두 KB read/write 사용)

기존 reference 자산: `~/.zzem/kb/` 의 8 skills + 3 learning schemas + 4 products schemas + 11 Node validators + tests. 그러나 이 자산은 **외부 git 리포 + Node ecosystem** 전제. zachflow 의 embedded-by-default + zero-deps 정체성과 정합하지 않음.

## Solution

KB skills 를 zachflow 내부에 직접 포팅하되, embedded-mode 첫걸음에 맞게 **최소 viable** 형태로 — 5개 active skill + 1 no-op sync skill, learning axis schemas 만, validation 은 skill-inline + 단일 smoke check.

검증 가능한 ship 게이트:
1. `bash scripts/kb-bootstrap.sh` 실행 후 `zachflow-kb:read type=pattern` 호출 → 빈 결과 반환 (에러 없음)
2. `zachflow-kb:write-pattern` 으로 신규 패턴 1건 등록 → `learning/patterns/{category}-001.yaml` 생성, schema validation 통과
3. `zachflow-kb:update-pattern` 으로 frequency 증가 → 파일 갱신
4. `zachflow-kb:write-reflection` 으로 retrospective 1건 기록 → `learning/reflections/{sprint-id}.md` 생성
5. `zachflow-kb:promote-rubric` 으로 패턴 → rubric clause 승격 → 새 rubric md 생성
6. `zachflow-kb:sync` 호출 → no-op + "embedded mode — nothing to sync" 메시지
7. CI smoke check (`tests/kb-smoke.sh`) 통과

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| 포팅 범위 | **Full minimal port** (5 active + 1 sync no-op skills, learning schemas) | v1.0 ship gate 정직성, retro phase 작동 필요. Notion 2개 제외. |
| Validation 구현 | **Skill-inline + minimal CI smoke** | embedded 모드는 single-project 학습 누적이 본질. zero deps 정체성 유지. |
| Skill 디렉토리 구조 | `.claude/skills/zachflow-kb/{op}/SKILL.md` (nested) | source 패턴 그대로. frontmatter `name: zachflow-kb:{op}`. |
| `$KB_PATH` resolution | env var → `git rev-parse --show-toplevel + /.zachflow/kb` 폴백 | embedded 기본 + remote-mode forward-compat (v1.1). |
| Schemas 위치 | `schemas/learning/{pattern,rubric,reflection}.schema.json` (zachflow 코어 owns) | 사용자 KB 와 분리. CI 가 참조. |
| Notion skills | **완전 제외** | master spec 결정. external integration plugin 영역. |
| `migrate-from-orchestrator.mjs` | 포팅하지 않음 | Sprint 1 시작점이 빈 KB. 마이그레이션 대상 없음. |
| Tests | `tests/kb-smoke.sh` 단일 파일 (Python 또는 bash) | fixture/full 테스트는 v1.x. v1.0 은 schema valid + 파일 파싱 smoke. |

## Scope

### v1.0 (Sprint 1) 포함

- 6 skill 파일: `.claude/skills/zachflow-kb/{read,write-pattern,update-pattern,write-reflection,promote-rubric,sync}/SKILL.md`
- 3 schemas: `schemas/learning/{pattern,rubric,reflection}.schema.json`
- `scripts/kb-bootstrap.sh` 완성 (Sprint 0 의 minimal 버전을 schemas 인식 + 초기 rubric seed 기능으로 확장 — 단, 여전히 embedded-only)
- `tests/kb-smoke.sh` (single smoke check)
- `.github/workflows/ci.yml` 에 smoke check step 추가
- `docs/kb-system.md` 채우기 (Sprint 0 skeleton → embedded mode 메커니즘 + skill API 문서화)
- `CHANGELOG.md` Sprint 1 entry 추가

### v1.0 (Sprint 1) 제외 → v1.x 유보

- Remote mode 자동화 (env var 명시 시 작동, wizard 는 v1.1)
- Notion sync skills (별도 plugin)
- 11개 Node validators 풀 포팅
- `tests/` 의 fixture-based 검증 (skill protocol 통합 테스트)
- products axis (prd / events / active-prds) — 별 sprint
- 일회성 migration 스크립트

### 변경하지 않는 파일

- Sprint 0 산출물 (commits 1~14): 그대로 유지. Sprint 1 은 추가 빌드.
- `scripts/setup-sprint.sh`, `scripts/sync-repos.sh` 등: KB 와 무관, 그대로.
- Phase skill markdown (`.claude/skills/sprint/*.md`): KB skill 호출은 이미 `zachflow-kb:*` 로 rename 됨. Sprint 1 은 **호출 대상의 실체** 를 만드는 작업.

## Detailed Design

### 1. Skill 디렉토리 레이아웃 (Sprint 1 산출물)

```
~/dev/personal/zachflow/
├── .claude/
│   └── skills/
│       ├── sprint/                      # (Sprint 0 sanitized — unchanged)
│       └── zachflow-kb/                 # ← Sprint 1 NEW
│           ├── read/SKILL.md
│           ├── write-pattern/SKILL.md
│           ├── update-pattern/SKILL.md
│           ├── write-reflection/SKILL.md
│           ├── promote-rubric/SKILL.md
│           └── sync/SKILL.md
│
├── schemas/                             # ← Sprint 1 NEW
│   └── learning/
│       ├── pattern.schema.json
│       ├── rubric.schema.json
│       └── reflection.schema.json
│
├── scripts/
│   └── kb-bootstrap.sh                  # ← Sprint 1 EXPANDED (Sprint 0 placeholder → seed initial rubric, recognize schemas)
│
├── tests/                               # ← Sprint 1 NEW
│   └── kb-smoke.sh                      # single Python or bash smoke check
│
├── .github/workflows/ci.yml             # ← Sprint 1 MODIFIED (add KB smoke step)
├── docs/kb-system.md                    # ← Sprint 1 EXPANDED (Sprint 0 skeleton → full embedded API docs)
└── CHANGELOG.md                         # ← Sprint 1 MODIFIED (Sprint 1 entry)
```

### 2. KB_PATH Resolution (모든 skill 공통)

각 SKILL.md 의 첫 번째 step 이 KB 위치를 결정:

```bash
KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"

if [ ! -d "$KB_PATH" ]; then
  echo "Error: KB not initialized at $KB_PATH. Run 'bash scripts/kb-bootstrap.sh' first." >&2
  exit 1
fi
```

규칙:
- env var `KB_PATH` 가 set → 그 값 사용 (remote mode 호환성용 — v1.1 wizard 가 이걸 set)
- 미 set + git repo → `<git-root>/.zachflow/kb`
- 미 set + non-git → 명시적 에러 (zachflow 는 git repo 가정)

### 3. Skill 별 contract

각 skill 의 input/output/side-effect 요약. 상세 protocol 은 SKILL.md 에 작성.

#### `zachflow-kb:read`

**Inputs**:
- `type` (required) — `pattern | rubric | reflection`
- 필터:
  - `pattern`: `category` (enum: 7가지 from source), `severity` (enum: critical/major/minor), `min_frequency` (int)
  - `rubric`: `status` (default `active`)
  - `reflection`: `domain` (string — embedded 모드에선 자유 enum), `limit` (int, default 3, by `completed_at`)

**Output**: 매칭되는 파일의 절대 경로 list (caller 가 Read tool 로 본문 로드).

**Side effects**: 없음 (read-only).

**Embedded 모드 차이**: `zzem-kb:read` 의 `prd`/`events` type 은 v1.0 에서 미지원 (products axis 미포함). type=prd/events 호출 시 명시적 에러 + plugin 안내.

#### `zachflow-kb:write-pattern`

**Inputs**:
- `category` (required, enum)
- `title` (required, string)
- `severity` (required, enum)
- `description`, `repro`, `fix`, `contract_clause`, `evaluation_check` 등 schema 필수 필드

**Output**: 생성된 파일 경로 (`learning/patterns/{category}-{NNN}.yaml`)

**Side effects**:
1. 같은 category 의 기존 max ID 조회 → `{category}-{NNN+1}` 결정
2. `frequency: 1`, `last_seen: <current-sprint-id>` 자동 설정
3. YAML 파일 작성 + skill-inline schema validation
4. **embedded 모드는 git push 안 함** (caller 가 commit 결정)

#### `zachflow-kb:update-pattern`

**Inputs**: `id` (required), 갱신할 필드 (frequency, last_seen, severity, status 등)

**Output**: 갱신된 파일 경로

**Side effects**: 파일 read → field 갱신 → write. retry-on-conflict 없음 (embedded 모드에선 동시 수정 시나리오 거의 없음 — single-user single-machine).

#### `zachflow-kb:write-reflection`

**Inputs**: `sprint_id`, `domain`, frontmatter fields (`completed_at`, `outcome`, `key_learnings` 등) + 본문

**Output**: `learning/reflections/{sprint_id}.md`

**Side effects**: markdown 파일 작성 (frontmatter + body). 같은 sprint_id 가 이미 있으면 명시적 에러 (overwrite 안 함; 사용자가 update 의도면 Edit tool 직접 사용).

#### `zachflow-kb:promote-rubric`

**Inputs**: `pattern_id`, `clause_text`, optional `rubric_version` (default: latest active)

**Output**: 갱신/생성된 rubric 파일 경로

**Side effects**:
- 가장 최신 active rubric 의 promotion log 에 한 줄 추가 (`yyyy-mm-dd | {pattern_id} | {clause_summary}`)
- rubric body 의 적절한 섹션에 clause 추가 (skill protocol 이 섹션 결정 logic 명시)

#### `zachflow-kb:sync`

**Inputs**: 없음

**Output**: status 메시지

**Side effects (embedded mode)**: 없음. 메시지 출력:
```
zachflow KB: embedded mode at /path/to/.zachflow/kb — nothing to sync.
```

**Future (v1.1+ remote mode)**: `KB_PATH` 가 외부 git repo 를 가리키면 `git fetch && git pull --ff-only` 수행. v1.0 SKILL.md 에 stub 코드만 작성, 실제 로직 v1.1.

### 4. Schemas

Source `~/.zzem/kb/schemas/learning/` 의 3개 JSON Schema 를 포팅:

- `pattern.schema.json` — category enum, severity enum, frequency int ≥ 1, last_seen string, contract_clause optional, evaluation_check optional, status enum (active/archived/superseded)
- `rubric.schema.json` — version int, status enum (active/draft/superseded), clauses array, promotion_log array
- `reflection.schema.json` — frontmatter (sprint_id, domain, completed_at, outcome enum) + body markdown

ZZEM-specific enum 값들은 sanitize:
- `domain` enum 은 source 가 `ai-webtoon | free-tab | ugc-platform | infra` — zachflow 는 **자유 string** 으로 변경 (사용자 프로젝트별 domain 자유). schema 에 `pattern: "^[a-z][a-z0-9-]*$"` 만 강제.
- `category` enum 은 source 의 7개 (`correctness | completeness | integration | edge_case | code_quality | design_proto | design_spec`) 그대로 유지 — 일반적 sprint 패턴 카테고리라 stack-agnostic.
- `severity` 3-enum 은 그대로.

### 5. `kb-bootstrap.sh` 확장

Sprint 0 의 minimal 버전 (디렉토리 생성만) 을 다음과 같이 확장:

```bash
#!/usr/bin/env bash
set -euo pipefail

# zachflow KB bootstrap — Sprint 1 embedded mode
# v1.x will add remote-mode support (clone external git repo when KB_PATH points to remote URL).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB_DIR="${PROJECT_ROOT}/.zachflow/kb"
SCHEMAS_DIR="${PROJECT_ROOT}/schemas/learning"

mkdir -p "${KB_DIR}/learning/patterns"
mkdir -p "${KB_DIR}/learning/rubrics"
mkdir -p "${KB_DIR}/learning/reflections"
mkdir -p "${KB_DIR}/products"

# Sprint 1: seed initial rubric v1 if absent
if [ ! -f "${KB_DIR}/learning/rubrics/v1.md" ] && [ -f "${SCHEMAS_DIR}/rubric.schema.json" ]; then
  cat > "${KB_DIR}/learning/rubrics/v1.md" <<'EOF'
---
version: 1
status: active
created_at: <auto-set on first kb-bootstrap run>
EOF
  # ... initial rubric body with empty Promotion Log
fi

if [ ! -f "${KB_DIR}/.initialized" ]; then
  touch "${KB_DIR}/.initialized"
  echo "zachflow KB initialized at ${KB_DIR} (embedded mode)"
else
  echo "zachflow KB already initialized at ${KB_DIR}"
fi
```

(상세 rubric template body 는 plan 단계에서 구체화.)

### 6. CI smoke check (`tests/kb-smoke.sh`)

CI 에서 KB 의 schemas + 가능한 한 fixture 의 minimum sanity check.

```bash
#!/usr/bin/env bash
# tests/kb-smoke.sh — minimal CI smoke check for zachflow KB
# Validates that schemas/ files are valid JSON Schema and parse cleanly.
# Does NOT validate user KB content (.zachflow/kb/) — that's embedded-mode user space.

set -euo pipefail

# 1. All schema files are valid JSON
for f in schemas/learning/*.json; do
  python3 -c "import json; json.load(open('$f'))" || { echo "FAIL: $f is not valid JSON"; exit 1; }
done

# 2. All schema files declare $schema (draft-2020-12 expected)
for f in schemas/learning/*.json; do
  python3 -c "
import json
data = json.load(open('$f'))
assert '\$schema' in data, '\$schema missing'
assert 'draft' in data['\$schema'], 'unexpected schema dialect'
" || { echo "FAIL: $f schema dialect check"; exit 1; }
done

# 3. SKILL.md frontmatter parses for all KB skills
for f in .claude/skills/zachflow-kb/*/SKILL.md; do
  python3 -c "
import sys
content = open('$f').read()
assert content.startswith('---'), 'no frontmatter'
end = content.find('---', 3)
assert end > 0, 'unterminated frontmatter'
import yaml
fm = yaml.safe_load(content[3:end])
assert 'name' in fm, 'missing name'
assert fm['name'].startswith('zachflow-kb:'), 'wrong name prefix'
" || { echo "FAIL: $f frontmatter check"; exit 1; }
done

echo "PASS: KB smoke check"
```

CI workflow `ci.yml` 에 step 추가:
```yaml
      - name: KB smoke check
        run: bash tests/kb-smoke.sh
```

### 7. `docs/kb-system.md` 확장

Sprint 0 의 skeleton 을 v1.0 의 정식 KB documentation 으로 확장. 섹션:
- Modes (embedded default + remote v1.1+ stub)
- Layout (`.zachflow/kb/` 트리)
- Skills (각 skill 의 input/output/side-effect 요약)
- KB_PATH resolution (위 §2)
- Schemas reference (각 schema 핵심 필드)
- Validation (skill-inline + CI smoke)
- 외부 도구 통합 (Notion 등은 plugin 안내)

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| Skill protocol 의 KB_PATH resolution 일관성 — 6개 skill 모두 같은 로직 | 1개 reference snippet 을 모든 SKILL.md 에 동일 인용. drift 방지를 위해 smoke check 가 매 skill 의 첫 step 을 grep 으로 확인 (옵션). |
| `git rev-parse --show-toplevel` 가 fail 하는 케이스 (non-git, submodule, worktree 등) | skill 이 명시적 에러 + 안내. zachflow 는 git repo 사용을 권장 가이드 추가 (README 에 한 줄 명시). |
| Source schemas 의 ZZEM-specific enum (`domain`) 처리 | 자유 string 으로 변경 (제약 완화). v1.x 에서 사용자 프로젝트별 enum 정의 가능하게 확장. |
| sync skill 의 v1.1 forward-compat 부담 | v1.0 SKILL.md 는 embedded 모드 only 명시 + remote 분기는 "TODO v1.1" 주석. v1.1 spec 에서 본격 설계. |
| skill-inline validation 이 잘못된 KB 파일 누수 가능 | smoke check 가 schema 파일 자체만 검증, 사용자 KB 콘텐츠는 검증 안 함. v1.x 에서 사용자 KB validation 옵션 도입 검토. |
| KB seed (initial rubric) 가 실제 sprint 에서 의미 있는 출발점인지 | rubric body 는 minimal — promotion_log 만 비어있음. 실제 clauses 는 Sprint 라이프사이클에서 누적. v1.0 ship 시점에 빈 KB 가 자연스러움. |

## Success Criteria

Sprint 1 ship 시점:

- [ ] 6 skill 디렉토리 (`zachflow-kb/{read,write-pattern,update-pattern,write-reflection,promote-rubric,sync}`) 가 모두 valid SKILL.md 보유
- [ ] 각 SKILL.md frontmatter `name: zachflow-kb:{op}` 형식 일치
- [ ] 3 schemas (`pattern,rubric,reflection`) 가 valid JSON Schema (`$schema: draft-2020-12`)
- [ ] `bash scripts/kb-bootstrap.sh` 실행 → `.zachflow/kb/` + initial rubric v1 생성
- [ ] `bash tests/kb-smoke.sh` PASS
- [ ] CI workflow 가 smoke step 포함
- [ ] `docs/kb-system.md` 가 6 skills 의 contract + KB_PATH resolution 문서화
- [ ] 6개 skill 의 manual smoke (사용자가 각 skill 을 1회씩 실행 → 의도된 결과 확인)
- [ ] Sprint 0 phase skill 들의 `zachflow-kb:*` 참조가 dead reference 가 아님 (실제 invokable)
- [ ] CHANGELOG.md Sprint 1 entry 추가

## Out of Scope (v1.x)

- Remote mode wizard (`zachflow kb migrate --remote=<url>`)
- products axis (prd, events, active-prds)
- Notion sync skills (`sync-prds-from-notion`, `sync-active-prds`)
- 11개 Node validator 풀 포팅 (filename-id 매칭, unique IDs, backwards-compat 등 깊은 검증)
- fixture-based skill 통합 테스트
- 사용자 KB 콘텐츠 schema validation (`.zachflow/kb/` 안의 user-written 파일)
- 다중 rubric 버전 simultaneous 관리 (현재는 single active)
- `migrate-from-orchestrator.mjs` 류의 일회성 마이그레이션
- KB diff/merge tooling (multi-user collaboration)
