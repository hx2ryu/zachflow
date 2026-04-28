# Sprint 4a — Plugins + Recall Port Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec Section 7a (Plugin 시스템) + zachflow `docs/roadmap.md` (Sprint 4 분할 후 첫 단계)
> Sprint context: Sprint 4 의 3-way split 중 첫 번째. `v0.4.0-sprint-3` 직후. Sprint 4b (gallery) 와 Sprint 4c (create-zachflow + v1.0 release) 가 후속.

## Problem

zachflow `v0.4.0-sprint-3` 까지의 상태는 **plugin 시스템이 master spec 에서 약속됐지만 실체 없음**:

- `docs/workflow-authoring.md` 가 plugins/ 디렉토리를 언급하지만 디렉토리 자체 미존재
- `docs/roadmap.md` 가 "Sprint 4 — `plugins/<name>/` pattern + first reference plugin (`plugins/recall/` ported from upstream PR #57)" 약속
- v1.0 ship gate 의 핵심 message ("v1.0 ships with one reference plugin demonstrating the plugin authoring pattern") 미충족

상류(`zach-wrtn/zzem-orchestrator` PR #57)의 `plugins/recall/` 가 OSS-portable 로 설계되어 port 가 비교적 mechanical 하지만:
- ZZEM-specific paths (`./sprint-orchestrator/sprints`, `~/.zzem/kb`, hardcoded domain enum) 가 sanitization 필요
- zachflow 의 새 디렉토리 구조 (`runs/sprint/<id>/`, `runs/qa-fix/<id>/`, `${KB_PATH:-./.zachflow/kb}`) 에 path references 적응 필요
- master spec section 9 (LLM platform coupling) 정책에 따른 platform-agnostic 어휘 적용

## Solution

zzem-orchestrator PR #57 의 `plugins/recall/` 를 zachflow 에 port (sanitization + path adaptation), `plugins/<name>/` 디렉토리 패턴 정식화, `scripts/install-plugins.sh` 신설 (user-explicit opt-in installer), `docs/plugin-authoring.md` 정식 가이드 작성.

검증 가능한 ship gate (Sprint 4a):

1. `plugins/recall/` 가 14 files 로 port 됨, ZZEM literals 0
2. `recall.example.yaml` 이 zachflow embedded KB + runs/{sprint,qa-fix}/ 구조 반영
3. `bash scripts/install-plugins.sh recall` 실행 후 `~/.claude/skills/recall → plugins/recall` symlink 생성 (user-level)
4. `bash plugins/recall/tests/test_config.sh` + `test_session.sh` PASS (총 15 unit tests)
5. `docs/plugin-authoring.md` 가 plugin authoring 의 정식 reference (≥120 lines)
6. CI smoke 에 recall plugin tests 통합
7. v1.0 ship gate 의 "ships with one reference plugin" 약속 충족

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| Plugin install 위치 | **user-level** (`~/.claude/skills/<plugin>`) — workflow 와 다름 | Claude Code 표준 패턴 (system-wide skills). plugin 은 optional/opt-in 이므로 project 안에 강제 install 불필요 |
| Plugin install 트리거 | **explicit** (`bash scripts/install-plugins.sh <name>`) | core vs plugin 의존성 단방향 — init-project.sh 는 plugin 무관 |
| Recall plugin 의 수정 범위 | **OSS-portable 부분 그대로 + ZZEM-specific 부분 sanitize** | 상류가 이미 OSS 친화적으로 설계 — 변경 최소 |
| `recall.example.yaml` schema | **embedded KB + workflow-aware paths** (zachflow 새 구조 반영) | Sprint 1/2 결과물과 정합 |
| Plugin tests CI 통합 | **plugin 의 기존 tests 재사용** | recall plugin 에 이미 15 unit tests — 별도 작성 불필요 |
| Plugin authoring docs | **`docs/plugin-authoring.md` full guide** (workflow-authoring.md 와 같은 quality) | recall 이 reference example 역할 |
| Sprint 4a tag | `v0.5.0-sprint-4a-plugins` | 3-way split 의 점진적 milestone |

## Scope

### v1.0 (Sprint 4a) 포함

- 신규 디렉토리: `plugins/`, `plugins/recall/`, `plugins/recall/{ask,scripts,config,tests}/`
- 14 ported files in `plugins/recall/` (full list in §1)
- 신규 스크립트: `scripts/install-plugins.sh` (~70 lines bash)
- 신규 문서: `docs/plugin-authoring.md` (~150-180 lines, plugin authoring v1.0 reference)
- CI 추가: `.github/workflows/ci.yml` 에 recall plugin tests step
- 수정 파일: `docs/roadmap.md` Sprint 4a checkbox 갱신
- CHANGELOG `[0.5.0-sprint-4a-plugins]` entry
- Tag `v0.5.0-sprint-4a-plugins`

### v1.0 (Sprint 4a) 제외 → Sprint 4b/4c 또는 v1.x

- `zachflow-gallery` 별도 패키지 → Sprint 4b
- `create-zachflow` npm wrapper → Sprint 4c
- README/CONTRIBUTING/v1.0 release polish → Sprint 4c
- 추가 plugins (Notion sync 등) — v1.x roadmap (community PRs)
- Plugin lifecycle hooks → v2.0
- Plugin marketplace / catalog → v1.x+
- Plugin upgrade/version management → v1.x+

### 변경하지 않는 파일

- Sprint 0/1/2/3 산출물 (commits up through `v0.4.0-sprint-3`): 그대로 유지
- workflows/ 디렉토리: plugin 과 orthogonal, 변경 없음
- Sprint 2 의 install-workflows.sh: 변경 없음 (plugin 은 별도 install-plugins.sh)
- init-project.sh: 변경 없음 (plugin 은 wizard 와 무관)
- KB skills, schemas: 변경 없음

## Detailed Design

### 1. Plugin 디렉토리 레이아웃 (Sprint 4a 산출물)

```
~/dev/personal/zachflow/
├── plugins/                              # ← Sprint 4a NEW (top-level)
│   └── recall/                           # ← Sprint 4a NEW (first plugin)
│       ├── README.md                     # plugin overview + install/uninstall
│       ├── ask/
│       │   └── SKILL.md                  # zachflow-recall:ask skill protocol
│       ├── scripts/
│       │   ├── install.sh                # symlinks ~/.claude/skills/recall → plugins/recall
│       │   ├── uninstall.sh              # removes symlink
│       │   ├── load-config.sh            # config resolution helper
│       │   └── session.sh                # session state helper
│       ├── config/
│       │   ├── recall.example.yaml       # annotated example (zachflow paths)
│       │   ├── recall.schema.json        # JSONSchema for config validation
│       │   └── .gitkeep                  # (if recall plugin uses runtime configs)
│       └── tests/
│           ├── smoke.md                  # smoke check protocol
│           ├── test_config.sh            # 4 unit tests
│           ├── test_session.sh           # 11 unit tests
│           └── .gitkeep                  # (if any tests gitkeep needed)
│
├── scripts/
│   └── install-plugins.sh                # ← Sprint 4a NEW (opt-in user installer)
│
├── docs/
│   ├── plugin-authoring.md               # ← Sprint 4a NEW (full guide)
│   └── roadmap.md                        # ← Sprint 4a MODIFIED (Sprint 4a checkbox)
│
├── .github/workflows/ci.yml              # ← Sprint 4a MODIFIED (recall tests step)
└── CHANGELOG.md                          # ← Sprint 4a MODIFIED (0.5.0-sprint-4a-plugins entry)
```

### 2. Recall plugin port — file-by-file

상류 `zach-wrtn/zzem-orchestrator` 의 PR #57 commit (가장 최근 main HEAD) 의 `plugins/recall/` 내 파일들. zachflow 로 port 시 각각의 처리:

| File | Bytes (approx) | Sanitization |
|------|---------------|-------------|
| `plugins/recall/README.md` | 63 lines | path references → zachflow (e.g., `runs/` 대신 `./sprint-orchestrator/sprints`) |
| `plugins/recall/ask/SKILL.md` | 207 lines | 큰 sanitization. KB path → `${KB_PATH:-./.zachflow/kb}`. domain enum → free string. ZZEM-specific examples 제거. workflow path references → `runs/{sprint,qa-fix}/<id>/`. skill name `recall:ask` 그대로 유지 (plugin namespace) |
| `plugins/recall/scripts/install.sh` | 25 lines | OSS-portable 이미 — 그대로 |
| `plugins/recall/scripts/uninstall.sh` | 15 lines | OSS-portable — 그대로 |
| `plugins/recall/scripts/load-config.sh` | 18 lines | config search path 변수에서 ZZEM-specific defaults 제거. `$RECALL_CONFIG → CWD → home → defaults` 그대로 |
| `plugins/recall/scripts/session.sh` | 73 lines | session state file path (`~/.recall/session.yaml`) 그대로. ZZEM 관련 reference 제거 |
| `plugins/recall/config/recall.example.yaml` | 22 lines | **큰 sanitization** — sources schema 변경 (sprints → runs.{sprint,qa-fix}, KB embedded path, free domain) |
| `plugins/recall/config/recall.schema.json` | 45 lines | schema 자체는 generic — `$id` rewrite + ZZEM-specific enum 자유화 |
| `plugins/recall/tests/smoke.md` | 88 lines | smoke 시나리오의 ZZEM examples 제거 |
| `plugins/recall/tests/test_config.sh` | 40 lines | 4 unit tests — fixture path 만 update |
| `plugins/recall/tests/test_session.sh` | 89 lines | 11 unit tests — temp dir patterns 그대로 |
| `plugins/recall/scripts/.gitkeep` | 0 | not needed (scripts/ has files) |
| `plugins/recall/config/.gitkeep` | 0 | not needed |
| `plugins/recall/tests/.gitkeep` | 0 | not needed |

총 11 files (3 .gitkeep 은 unnecessary 로 제외). + `plugins/.gitkeep` (top-level) 추가 (다른 plugins 가 추가될 때까지 빈 dir 유지).

### 3. `recall.example.yaml` 변환

**원본 (zzem-orchestrator)**:
```yaml
sources:
  sprints:
    path: ./sprint-orchestrator/sprints
    artifact_layout:
      always_read: [PRD.md, retrospective]
      conditional_read: [evaluations, contracts, tasks]
      skip_by_default: [prototypes, logs, checkpoints]

  kb:
    path: ~/.zzem/kb
    layout: zzem-kb
    domain_enum: [ai-webtoon, free-tab, ugc-platform, infra]

session:
  state_file: ~/.recall/session.yaml
  idle_timeout_minutes: 30
  stale_days: 7
```

**zachflow 변환**:
```yaml
# plugins/recall/config/recall.example.yaml
# zachflow recall plugin config — copy to repo root as .recall.yaml or set $RECALL_CONFIG.

sources:
  runs:
    # zachflow workflow run instances live here (Sprint 2+ structure)
    path: ./runs
    workflows: [sprint, qa-fix]              # which workflow run-dirs to consider
    artifact_layout:
      always_read: [PRD.md, retrospective]
      conditional_read: [evaluations, contracts, tasks]
      skip_by_default: [prototypes, logs, checkpoints]

  kb:
    # zachflow embedded KB (Sprint 1)
    path: "${KB_PATH:-./.zachflow/kb}"
    layout: zachflow-kb                      # was zzem-kb
    # domain enum is project-specific (no hardcoded enum); recall accepts any
    # string matching ^[a-z][a-z0-9-]*$ (matches reflection schema in
    # schemas/learning/reflection.schema.json)

session:
  state_file: ~/.recall/session.yaml
  idle_timeout_minutes: 30
  stale_days: 7
```

### 4. `recall.schema.json` 변환

`$id` rewrite (`zachflow.dev` domain) + ZZEM-specific 제약 자유화. `domain_enum` array constraint 제거 (free string). `sources.sprints` → `sources.runs` rename + `workflows` 추가.

### 5. `ask/SKILL.md` Sanitization 핵심

Frontmatter `name: recall:ask` (plugin namespace 그대로). description 에서 ZZEM 어휘 제거.

본문 (~207 lines) 의 변환:
- Discovery 단계의 sprint candidate detection: `./sprint-orchestrator/sprints/*/` glob → `./runs/{sprint,qa-fix}/*/`
- Sprint config 참조: `sprint-config.yaml` (path unchanged)
- KB 참조: `${KB_PATH:-./.zachflow/kb}` 사용 (env var fallback)
- 모든 reflection/pattern/rubric path references → zachflow 의 새 KB layout
- ZZEM domain enum 검증 → free string + warning (recall 은 모든 domain 받아들임)
- Sources block 의 ZZEM-specific examples → generic examples
- mcp__wrtn-mcp__* tool names → KEEP (사용자 MCP, master spec section 9 정책)
- 한국어 잔재 → English (Sprint 0 sanitization 패턴 재사용)

### 6. `scripts/install-plugins.sh` (zachflow neue)

```bash
#!/usr/bin/env bash
# install-plugins.sh — opt-in installer for zachflow plugins.
#
# Usage:
#   bash scripts/install-plugins.sh recall              # install one plugin
#   bash scripts/install-plugins.sh recall foo bar      # install multiple
#   bash scripts/install-plugins.sh --list              # list available plugins
#   bash scripts/install-plugins.sh --help
#
# Each plugin must have plugins/<name>/scripts/install.sh which symlinks
# ~/.claude/skills/<name> -> $PROJECT_ROOT/plugins/<name>.
#
# Plugins are user-installable (system-wide via ~/.claude/), separate from
# zachflow workflows (project-bundled via .claude/skills/{sprint,qa-fix}).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -eq 0 ]; then
  echo "Error: specify plugin name(s) or --list" >&2
  exit 1
fi

if [ "$1" = "--list" ]; then
  echo "Available plugins:"
  for d in "$PROJECT_ROOT"/plugins/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    echo "  - $name"
  done
  exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit 0
fi

for plugin in "$@"; do
  PLUGIN_DIR="$PROJECT_ROOT/plugins/$plugin"
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Error: plugin '$plugin' not found at $PLUGIN_DIR" >&2
    exit 1
  fi
  INSTALL_SH="$PLUGIN_DIR/scripts/install.sh"
  if [ ! -x "$INSTALL_SH" ]; then
    echo "Error: $INSTALL_SH not executable" >&2
    exit 1
  fi
  echo "Installing plugin: $plugin"
  bash "$INSTALL_SH"
done

echo
echo "Done. Plugins are now available system-wide via ~/.claude/skills/."
```

### 7. `docs/plugin-authoring.md` 구조

Sprint 2 의 `docs/workflow-authoring.md` 와 같은 quality + 구조:

- Workflow vs Plugin (table — 이미 workflow-authoring.md 에 있음, 여기서 expand)
- Plugin Directory Structure (`plugins/<name>/{ask|<skill>/SKILL.md, scripts/, config/, tests/, README.md}`)
- Required scripts: install.sh, uninstall.sh (other scripts optional)
- Plugin namespacing: skill `name:` frontmatter uses `<plugin>:<op>` (e.g., `recall:ask`)
- Config layer: `$<NAME>_CONFIG → CWD → home → defaults` (recall pattern)
- JSONSchema validation
- Tests pattern (`test_*.sh` shell tests)
- 10-step checklist for adding a new plugin
- Reference: `plugins/recall/` as worked example

### 8. CI Integration

`.github/workflows/ci.yml` 의 smoke job 에 plugin tests step 추가:

```yaml
      - name: recall plugin unit tests
        run: |
          bash plugins/recall/tests/test_config.sh
          bash plugins/recall/tests/test_session.sh
```

(install-plugins.sh 자체의 syntax check 도 포함 — 별도 step.)

### 9. `docs/roadmap.md` 갱신

```diff
- [ ] Sprint 4 — `zachflow-gallery` package + `plugins/<name>/` pattern + first reference plugin (`plugins/recall/` ported from upstream PR #57) + `create-zachflow` npm wrapper + `docs/plugin-authoring.md` + LICENSE/CI/release
+ [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
+ [ ] Sprint 4b — `zachflow-gallery` package
+ [ ] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release
```

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| 상류 PR #57 의 recall plugin 이 sanitization 누락 부분 가짐 | port 후 ZZEM-leak grep + Korean grep 으로 검증. PR 의 부분이 OSS-portable 의도지만 일부 leak 가능. 발견 시 추가 sanitization. |
| `recall:ask` 가 zachflow 의 새 디렉토리 구조 (`runs/sprint/<id>/` etc) 와 호환 안 됨 | `ask/SKILL.md` 의 path discovery 로직 명시적 update. smoke test 가 catch — Sprint 4a Task 의 manual smoke 단계에서 검증. |
| Recall 의 KB layout 가정 이 zachflow embedded KB 와 다름 | `sources.kb.layout: zachflow-kb` 명시 + `${KB_PATH:-./.zachflow/kb}` 변수 사용. recall 의 KB 검증 로직이 generic 한지 확인 필요. |
| 사용자가 `~/.claude/skills/recall` 에 다른 (zzem-orchestrator) symlink 가지고 있음 | install.sh 가 stale symlink detection 함. 충돌 시 명시적 에러 + manual cleanup 안내. |
| Plugin tests 가 macOS-only assumption | 기존 PR #57 가 bash 기반이라 Linux 도 작동해야 함. CI (Ubuntu) 에서 PASS 검증. |
| Plugin namespace `recall:` vs zachflow 의 `zachflow-kb:` 일관성 | recall 은 plugin namespace (자체 prefix), zachflow-kb 는 core skill. 다른 namespace 자연스러움. README 에서 명시. |
| 향후 plugin 가 core 에 의존 안 하도록 보장 | docs/plugin-authoring.md 에 명시 — plugin 은 zachflow core 자산 (workflows/, schemas/) 을 사용 가능, 그 반대는 금지. |

## Success Criteria

Sprint 4a ship 시점:

- [ ] `plugins/recall/` 디렉토리에 11+ files port 됨
- [ ] `plugins/recall/ask/SKILL.md` frontmatter `name: recall:ask` valid
- [ ] `recall.example.yaml` valid YAML + zachflow paths (`runs/`, `${KB_PATH}`)
- [ ] `recall.schema.json` valid JSON + draft 2020-12
- [ ] `bash scripts/install-plugins.sh recall` 실행 → `~/.claude/skills/recall → plugins/recall` symlink 생성
- [ ] `bash plugins/recall/tests/test_config.sh` PASS (4 tests)
- [ ] `bash plugins/recall/tests/test_session.sh` PASS (11 tests)
- [ ] `bash scripts/install-plugins.sh --list` shows `recall`
- [ ] `bash scripts/install-plugins.sh --help` shows usage
- [ ] `docs/plugin-authoring.md` ≥120 lines, references plugins/recall/ as example
- [ ] `docs/roadmap.md` Sprint 4a checkbox checked
- [ ] CI workflow has recall plugin test step + install-plugins.sh syntax check
- [ ] CHANGELOG.md `[0.5.0-sprint-4a-plugins]` entry
- [ ] Tag `v0.5.0-sprint-4a-plugins`
- [ ] No ZZEM-leak in plugins/ (existing scan passes)
- [ ] No Korean residue in plugins/

## Out of Scope (Sprint 4b/4c, v1.x+)

- `zachflow-gallery` 별도 패키지 (Sprint 4b)
- `create-zachflow` npm wrapper (Sprint 4c)
- README/CONTRIBUTING/v1.0 release polish (Sprint 4c)
- v1.0.0 final tag (Sprint 4c)
- Notion sync plugin (community PR, v1.x)
- Slack notification plugin (community PR, v1.x)
- Plugin marketplace / discovery (v1.x+)
- Plugin upgrade/version pinning (v1.x+)
- Plugin lifecycle hooks (v2.0)
- Plugin sandboxing/permissions (v2.0)
- Cross-plugin events (v2.0+)
