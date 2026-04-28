# Sprint 2 — Workflow Split Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec Section 3 (Workflow 1급화) + Section 4.4 (light split + Build Loop primitive 추출)
> Sprint context: zachflow v1.0 Sprint 2 — Sprint 1 (KB embedded, `v0.2.0-sprint-1`) 직후

## Problem

Sprint 0/1 까지의 zachflow 는 다음과 같은 구조:

- `.claude/skills/sprint/{SKILL.md,phase-init.md,phase-spec.md,phase-prototype.md,phase-build.md,phase-pr.md,phase-retro.md,phase-qa-fix.md,phase-modes.md,knowledge-base.md}` — sprint workflow + qa-fix 가 한 디렉토리에 섞여 있음
- `qa-fix` 진입점이 `/sprint <id> --type=qa-fix --jql=...` — sprint 의 부속 모드로 보임
- Build Loop (Contract → Implement → Evaluate → Fix) 가 `phase-build.md` 에만 정의되고 `phase-qa-fix.md` (Stage 3~4) 가 동일 로직을 inline 참조 — 사실상 중복
- `runs/` 디렉토리는 flat 구조 (`.gitkeep` 만)

**문제**:
1. **워크플로우 정체성 모호** — `qa-fix` 가 sprint runner 의 옵션 모드로 위치해서 sprint 워크플로우 안 쓰는 사용자도 명목상 `/sprint` 를 통과해야 함. 인지 부조화.
2. **Build Loop 의 진짜 공유 자산이 코드에 표현 안 됨** — 두 워크플로우의 공통 primitive 가 markdown 으로 분리되어 있지 않아, Sprint 추가 시 또 inline 복사 위험.
3. **Phase/Stage 파일 위치가 platform-specific 디렉토리(`.claude/skills/`) 에 있음** — Section 9 LLM platform coupling 정책에 따르면 platform-agnostic 콘텐츠는 platform 폴더 밖에 있어야 함. workflow markdown 은 platform-agnostic.
4. **`phase-qa-fix.md` 가 ~260 lines monolith** — 5 stage 가 한 파일이라 stage 간 boundary 가 마크다운 헤딩에만 의존.

## Solution

`workflows/{sprint,qa-fix,_shared}/` 디렉토리를 신설해 platform-agnostic workflow 콘텐츠를 옮기고, `.claude/skills/{sprint,qa-fix}/` 는 symlink 로 Claude Code 호환을 유지한다. `qa-fix` 를 1급 진입점으로 격상하고, 두 워크플로우가 공유하는 Build Loop / agent dispatch / worktree protocol 을 `workflows/_shared/` 로 추출한다.

검증 가능한 ship gate:
1. `bash scripts/install-workflows.sh` 실행 후 `~/dev/personal/zachflow/.claude/skills/sprint` 가 `../../workflows/sprint` 를 가리키는 symlink, `qa-fix` 도 동일.
2. Claude Code session 에서 `/sprint <id>` 와 `/qa-fix <id>` 가 모두 invokable (frontmatter `name:` 매칭).
3. `workflows/_shared/build-loop.md` 가 primitive 로 추출되고 phase-build.md, stage-3-contract.md, stage-4-implement-eval.md 가 모두 reference.
4. `phase-qa-fix.md` 를 5개 stage 파일로 분할 + `workflows/qa-fix/SKILL.md` 가 entry/dispatch 역할.
5. `runs/sprint/<id>/`, `runs/qa-fix/<id>/` subdirectory 구조 모든 phase/stage 파일에 반영.
6. `/sprint <id> --type=qa-fix` 호출 시 deprecation warn → `/qa-fix` 로 위임하는 alias 동작.

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| Skill discovery | **Symlink 패턴** (`.claude/skills/{sprint,qa-fix}` → `workflows/{sprint,qa-fix}`) | recall plugin (PR #57) 과 일관, platform-agnostic/specific 경계 명확화 |
| `phase-qa-fix.md` 처리 | **5 stage 파일로 분할** + `workflows/qa-fix/SKILL.md` (entry) | Build Loop primitive reference 시점 명확화, stage 별 boundary 강화 |
| `workflows/_shared/` 내용 | `build-loop.md` + `agent-team.md` + `worktree.md` (3 파일) | 두 워크플로우의 진짜 공통 primitive |
| `runs/` 하위 구조 | `runs/sprint/<id>/` + `runs/qa-fix/<id>/` | workflow-type subdirectory, master spec Section 3 명시 |
| 레거시 alias | `/sprint <id> --type=qa-fix` deprecated 유지, v2.0 제거 | 하위 호환 + 점진적 마이그레이션 |
| `knowledge-base.md` 위치 | `workflows/_shared/kb-integration.md` 로 이동 | phase 가 read 시점 참조하는 "어떻게 KB 호출하는가" 지식. `docs/kb-system.md` (사용자 reference) 와 역할 분리. |
| `branch_prefix` | sprint-config.yaml 그대로 사용 (Sprint 0 결정 유지) | 이미 변수화 완료, 추가 작업 불필요 |

## Scope

### v1.0 (Sprint 2) 포함

- 신규 디렉토리: `workflows/{sprint,qa-fix,_shared}/`
- `workflows/sprint/` 콘텐츠 (Sprint 1 의 `.claude/skills/sprint/` 에서 이동):
  - `SKILL.md`, `phase-init.md`, `phase-spec.md`, `phase-prototype.md`, `phase-build.md`, `phase-pr.md`, `phase-retro.md`, `phase-modes.md` (8 파일)
- `workflows/qa-fix/` 콘텐츠 (phase-qa-fix.md 를 5 stage 로 분할):
  - `SKILL.md` (entry + dispatcher), `stage-1-triage.md`, `stage-2-grouping.md`, `stage-3-contract.md`, `stage-4-implement-eval.md`, `stage-5-close.md` (6 파일)
- `workflows/_shared/` 콘텐츠 (신규 추출):
  - `build-loop.md` — Contract → Implement → Eval → Fix primitive
  - `agent-team.md` — Sprint Lead / BE Engineer / FE Engineer / Design Engineer / Evaluator 역할 정의 + dispatch protocol
  - `worktree.md` — worktree 격리 + 브랜치 명명 규약
  - `kb-integration.md` — phase 별 KB 호출 시점 + 사용 패턴 (구 `.claude/skills/sprint/knowledge-base.md` 이전)
- Symlinks: `.claude/skills/sprint -> ../../workflows/sprint`, `.claude/skills/qa-fix -> ../../workflows/qa-fix`
- 신규 스크립트 `scripts/install-workflows.sh` — workflow symlink 생성/검증
- `.claude/skills/sprint/` 의 기존 콘텐츠 제거 (symlink 으로 대체)
- 모든 phase/stage 파일에서 `runs/<id>/...` 경로 참조를 `runs/sprint/<id>/...` 또는 `runs/qa-fix/<id>/...` 로 업데이트
- 모든 phase/stage 파일에서 Build Loop / agent / worktree 인라인 정의를 `workflows/_shared/<file>.md` reference 로 교체
- `runs/.gitkeep` 제거, 대신 `runs/sprint/.gitkeep` + `runs/qa-fix/.gitkeep`
- `kb-bootstrap.sh`, `setup-sprint.sh` 등 스크립트의 `runs/` 경로 참조 업데이트
- `tests/kb-smoke.sh` — symlink 추가 후에도 동작 확인 (기존 `*/SKILL.md` glob 이 symlink 너머 파일 인식)
- `.github/workflows/ci.yml` — `install-workflows.sh` 실행 step 추가 (CI 환경에서 symlink 자동 생성)
- `docs/workflow-authoring.md` 채우기 (Sprint 0 의 stub → 정식 가이드)
- `CHANGELOG.md` Sprint 2 entry 추가

### v1.0 (Sprint 2) 제외 → v1.x 유보

- Workflow yaml DSL / 선언적 workflow 정의 (master spec: B+ 수준에서 정지, C 옵션은 v2.0)
- Plugin lifecycle hooks (workflow 가 plugin 호출하는 인터페이스)
- 3번째 workflow 추가 (예: document-release, security-audit) — 추상화 검증 후
- Build Loop primitive 의 추가 변형 (예: 서로 다른 fix loop limit)
- Cross-workflow event passing (workflow 간 trigger)

### 변경하지 않는 파일

- Sprint 0/1 산출물 (commits up through `v0.2.0-sprint-1`): 그대로 유지. Sprint 2 는 추가 빌드 + 일부 이동/수정.
- KB 관련 (Sprint 1 산출물): `.claude/skills/zachflow-kb/`, `schemas/learning/`, `docs/kb-system.md` — 위치 변경 없음. KB skills 는 workflow 와 orthogonal.
- README.md, ARCHITECTURE.md, MANUAL.md, LICENSE 등: 별 사유 없으면 미수정 (CHANGELOG 만 update).

## Detailed Design

### 1. 디렉토리 레이아웃 (Sprint 2 산출물 후)

```
~/dev/personal/zachflow/
├── .claude/
│   ├── settings.json              # (Sprint 0)
│   └── skills/
│       ├── zachflow-kb/...        # (Sprint 1) — KB skills 그대로
│       ├── sprint -> ../../workflows/sprint     # ← Sprint 2 NEW (symlink)
│       └── qa-fix -> ../../workflows/qa-fix     # ← Sprint 2 NEW (symlink)
│
├── workflows/                      # ← Sprint 2 NEW
│   ├── sprint/
│   │   ├── SKILL.md                # frontmatter name: sprint
│   │   ├── phase-init.md
│   │   ├── phase-spec.md
│   │   ├── phase-prototype.md
│   │   ├── phase-build.md          # → references _shared/build-loop.md
│   │   ├── phase-pr.md
│   │   ├── phase-retro.md
│   │   └── phase-modes.md
│   ├── qa-fix/
│   │   ├── SKILL.md                # frontmatter name: qa-fix (entry + dispatcher)
│   │   ├── stage-1-triage.md
│   │   ├── stage-2-grouping.md
│   │   ├── stage-3-contract.md     # → references _shared/build-loop.md
│   │   ├── stage-4-implement-eval.md  # → references _shared/build-loop.md
│   │   └── stage-5-close.md
│   └── _shared/
│       ├── build-loop.md           # Contract → Implement → Eval → Fix primitive
│       ├── agent-team.md           # role definitions + dispatch protocol
│       ├── worktree.md             # worktree isolation + branch naming
│       └── kb-integration.md       # phase-by-phase KB invocation patterns
│
├── runs/                           # ← Sprint 2 RESTRUCTURED
│   ├── sprint/
│   │   └── .gitkeep
│   └── qa-fix/
│       └── .gitkeep
│
├── scripts/
│   ├── (Sprint 0/1 scripts)
│   └── install-workflows.sh        # ← Sprint 2 NEW
│
├── tests/
│   └── kb-smoke.sh                 # (Sprint 1) — verify symlinks don't break it
│
├── docs/
│   ├── workflow-authoring.md       # ← Sprint 2 EXPANDED (Sprint 0 stub → full guide)
│   └── (other Sprint 0/1 docs unchanged)
│
└── .github/workflows/ci.yml        # ← Sprint 2 MODIFIED (add install-workflows step)
```

### 2. Symlink 메커니즘

#### Why symlinks?

Claude Code 의 skill 시스템은 `.claude/skills/<name>/SKILL.md` 만 인식. 만약 `workflows/sprint/SKILL.md` 에 직접 두면 Claude Code 는 발견 못 함.

대안 (path reference 방식) 도 가능하지만 — `.claude/skills/sprint/SKILL.md` 가 thin wrapper 로서 `workflows/sprint/phase-*.md` 들을 path 로 참조 — symlink 보다 복잡 (두 디렉토리 콘텐츠 동기화 부담).

Symlink: `workflows/<name>/` 가 source-of-truth, `.claude/skills/<name>/` 는 platform-compatibility shim.

#### `scripts/install-workflows.sh`

```bash
#!/usr/bin/env bash
# install-workflows.sh — create symlinks from .claude/skills/ to workflows/
# Idempotent: skip if symlink already correct, error if non-symlink exists.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for workflow in sprint qa-fix; do
  TARGET="${PROJECT_ROOT}/.claude/skills/${workflow}"
  SOURCE_REL="../../workflows/${workflow}"
  SOURCE_ABS="${PROJECT_ROOT}/workflows/${workflow}"

  if [ ! -d "$SOURCE_ABS" ]; then
    echo "Error: source ${SOURCE_ABS} does not exist" >&2
    exit 1
  fi

  if [ -L "$TARGET" ]; then
    current=$(readlink "$TARGET")
    if [ "$current" = "$SOURCE_REL" ]; then
      echo "already linked: $TARGET -> $current"
      continue
    fi
    echo "removing stale symlink: $TARGET -> $current"
    rm "$TARGET"
  elif [ -e "$TARGET" ]; then
    echo "ERROR: $TARGET exists and is not a symlink. Aborting." >&2
    exit 1
  fi

  mkdir -p "${PROJECT_ROOT}/.claude/skills"
  ln -s "$SOURCE_REL" "$TARGET"
  echo "linked: $TARGET -> $SOURCE_REL"
done

echo "workflow symlinks installed."
```

(상세 코드는 plan 단계에서 확정.)

#### Symlink 의 git 추적

git 은 symlink 자체를 mode 120000 entry 로 추적함. `.claude/skills/sprint` 가 git 에 commit 되면 symlink target (`../../workflows/sprint`) 이 보존됨. 사용자 clone 직후 symlink 가 작동.

`install-workflows.sh` 는 fresh clone 에서는 no-op (이미 올바른 symlink 존재). 만약 사용자가 실수로 symlink 를 깼거나 콘텐츠 디렉토리 위치가 변하면 idempotent re-install.

CI 환경에서는 git 이 symlink 보존하므로 추가 step 불필요. 그러나 *방어적으로* `.github/workflows/ci.yml` 에 `bash scripts/install-workflows.sh` step 을 추가해 환경 차이 (Windows runner 등) 회피.

### 3. Build Loop primitive — `workflows/_shared/build-loop.md`

Sprint 1 까지 `phase-build.md` (Section 4.1~4.5) + `phase-qa-fix.md` (Stage 3~4 안에 inline) 두 곳에 중복 정의된 4-step primitive 를 단일 파일로 추출.

**`workflows/_shared/build-loop.md` 구조**:

```markdown
# Build Loop Primitive

shared by `workflows/sprint/phase-build.md` (Sprint Phase 4) and
`workflows/qa-fix/{stage-3-contract.md, stage-4-implement-eval.md}` (QA-Fix Stages 3~4).

## The Loop

```
For each group:
  1. Contract     — Sprint Lead drafts → Evaluator reviews → consensus on done criteria
  2. Implement    — BE/FE Engineers in parallel worktrees
  3. Merge        — Sprint branch with --no-ff (sprint workflow only) or fix branch
  4. Evaluate     — Evaluator: Active Evaluation
  5. Verdict      — PASS → next group | ISSUES/FAIL → up to 2 fix iterations
```

## Severity Classification

| Severity | 정의 | 예시 |
|----------|------|------|
| Critical | 기능 불가 / 데이터 손상 위험 | API 500, 무한 루프, injection |
| Major    | AC 미충족 / 비즈니스 룰 위반 | 카운트 미감소, 차단 유저 노출 |
| Minor    | 동작 무관 코드 품질 | unused import, 비효율적 쿼리 |

## Verdict Rules

| 판정 | 조건 | 후속 |
|------|------|------|
| PASS   | Critical 0, Major 0 | 다음 그룹 |
| ISSUES | Critical 0, Major 1+ | Fix Loop |
| FAIL   | Critical 1+, Major 3+ | Fix Loop 또는 재구현 |

## Budget Pressure Protocol

(Sprint 1 phase-build.md 와 동일. Normal/Caution/Urgent 3-level.)

## Frozen Snapshot Protocol

(Teammate spawn 시 참조 데이터 인라인 — Sprint 1 phase-build.md 와 동일.)
```

**phase-build.md 의 변경**: Section 4.1~4.5 의 inline 정의 → "See `workflows/_shared/build-loop.md`" 한 줄로 교체. Sprint workflow 고유 부분 (group 정의, sprint 브랜치 머지 정책 등) 만 phase-build.md 에 유지.

**stage-3-contract.md, stage-4-implement-eval.md 의 변경**: 각각 build-loop.md reference + qa-fix-specific 차이 (ticket repro steps inline, jira comment 작성 등) 만 명시.

### 4. `agent-team.md` — `workflows/_shared/agent-team.md`

현재 `phase-init.md`, `phase-spec.md`, `phase-build.md` 등에 흩어진 agent 역할 정의 (Sprint Lead / BE Engineer / FE Engineer / Design Engineer / Evaluator) + TaskCreate 디스패치 패턴을 단일 파일로 추출.

내용:
- 각 역할의 책임 (planner / generator / evaluator / dispatcher)
- TaskCreate 호출 패턴 (subject naming convention, description 구조)
- Frozen Snapshot 인라인 protocol
- Read-only constraint (Evaluator 는 코드 수정 불가)
- Cross-task communication via 파일 (chat memory 비신뢰)

`.claude/teammates/{be-engineer,fe-engineer,design-engineer,evaluator}.md` (Sprint 0 결과물) 과 다름:
- `agent-team.md` = workflow 가 호출하는 dispatch protocol (HOW to dispatch)
- `.claude/teammates/*.md` = 각 agent 가 수행하는 role guide (WHAT the agent does)

phase 파일들이 `agent-team.md` reference, teammate 파일은 변경 없음.

### 5. `worktree.md` — `workflows/_shared/worktree.md`

worktree 격리 + 브랜치 명명 + cleanup 규약. 현재 `phase-build.md` 와 `phase-pr.md` 에 분산된 worktree 관련 규칙 통합.

내용:
- `setup-sprint.sh` / `cleanup-sprint.sh` 호출 시점
- `{branch_prefix}/{run-id}` 브랜치 네이밍
- `{branch_prefix}/{run-id}/{task-id}` task 브랜치
- `--no-ff` 머지 정책
- worktree dirty 시 처리 (cleanup --force 옵션)

### 6. `kb-integration.md` — `workflows/_shared/kb-integration.md`

구 `.claude/skills/sprint/knowledge-base.md` (Sprint 0 sanitize) 를 `workflows/_shared/` 로 이동 + workflow-perspective 로 재정리.

내용:
- Phase 별 KB 호출 시점 (Phase 2 read pattern, Phase 4.1 contract auto-inject, Phase 6 retro write)
- Stage 별 KB 호출 (qa-fix Stage 5 close 시 KB candidate 추출)
- `${KB_PATH}` resolution 참조 (Sprint 1 결정)
- Skill 별 호출 패턴 (read filter args, write-pattern field 요구사항 등)

`docs/kb-system.md` 와의 역할 분담:
- `docs/kb-system.md` (Sprint 1) = 사용자/contributor 향 reference. KB system 전반 설명.
- `workflows/_shared/kb-integration.md` = workflow 내부 protocol. phase/stage 가 read 시점 참조.

### 7. `phase-qa-fix.md` 분할 (5 stages + SKILL.md)

현재 `phase-qa-fix.md` (~260 lines) 를:

- `workflows/qa-fix/SKILL.md` — frontmatter `name: qa-fix`, body 는 invocation + 5-stage 개요 + dispatcher 로직
- `workflows/qa-fix/stage-1-triage.md` — Jira fetch + auto-classification + user approval gate
- `workflows/qa-fix/stage-2-grouping.md` — in-scope ticket 을 fix unit 으로 묶기
- `workflows/qa-fix/stage-3-contract.md` — Sprint Contract (Build Loop 4.1 reference)
- `workflows/qa-fix/stage-4-implement-eval.md` — BE/FE implement + Evaluator (Build Loop 4.2~4.5 reference)
- `workflows/qa-fix/stage-5-close.md` — Jira comment post + transition + KB candidate 추출

### 8. `runs/` Subdirectory 구조

Sprint 0/1 의 `runs/` flat → `runs/sprint/<id>/` + `runs/qa-fix/<id>/`.

영향:
- `runs/.gitkeep` 제거, `runs/sprint/.gitkeep` + `runs/qa-fix/.gitkeep` 추가
- 모든 phase/stage 파일의 path reference 업데이트 (예: `runs/<id>/PRD.md` → `runs/sprint/<id>/PRD.md`)
- `setup-sprint.sh` / `cleanup-sprint.sh` 의 worktree 디렉토리 경로 인자도 sprint-config.yaml 의 workflow type 에 따라 분기. Sprint 0/1 에서 이미 작성된 스크립트는 workflow type 모름 — sprint-config.yaml 에 `workflow: sprint | qa-fix` 필드 추가.

### 9. Legacy `/sprint <id> --type=qa-fix` Alias

기존 호출 방식 유지 (사용자 muscle memory + zzem-orchestrator 로부터의 마이그레이션 경로). `workflows/sprint/SKILL.md` 의 invocation 섹션에서 `--type=qa-fix` 인자 감지 시:

1. Deprecation warning 출력: `⚠ /sprint --type=qa-fix is deprecated; use /qa-fix <id> directly. Will be removed in v2.0.`
2. 자동으로 `/qa-fix <id>` 로 위임 (workflows/qa-fix/SKILL.md 호출).

deprecation 시점: v2.0 (master spec 의 "v2.0 검토" 정책과 정합).

### 10. `docs/workflow-authoring.md` 정식화

Sprint 0 stub:
> Sprint 2 fills this in (after the workflows/ directory split).

Sprint 2 에서 작성:
- workflow 디렉토리 구조 (`workflows/<name>/{SKILL.md, ...}`)
- `workflows/_shared/` 의 4 primitive 사용법
- 새 workflow 추가 시 체크리스트 (예: 6단계 phase 또는 stage 분할 결정, agent dispatch 정의, KB integration 결정, runs/ subdirectory 결정)
- symlink 등록 (`scripts/install-workflows.sh` 수정)
- `runs/<workflow>/` 디렉토리 신설
- 미래 workflow 예시 (security-audit, document-release 등 — 추정)

플러그인과의 차이도 명시:
- workflow = 코어, 모든 사용자에게 공통, sprint runner 의 일부
- plugin (Sprint 4 도입 예정) = optional, 사용자가 install.sh 로 활성화

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| Symlink 가 git clone 직후 작동하지 않는 환경 (Windows native, 일부 cloud editor) | `install-workflows.sh` 가 idempotent re-install 가능. README 에 macOS/Linux 우선 명시 (Windows 는 WSL 권장). v1.x 에서 Windows native fallback 검토. |
| Symlink 추적이 일부 git 도구에서 잘못 처리 | git 표준 mode 120000 사용. `git config core.symlinks true` 가 default. 문제 발견 시 `install-workflows.sh` 가 idempotent fix. |
| Phase/stage 파일이 `_shared/build-loop.md` 를 reference 하면서 inline 사본도 남기는 drift 위험 | Phase/stage 파일에는 inline 정의 절대 금지. 모든 build-loop 정의는 `_shared/build-loop.md` 만. CI 가 phase/stage 파일에서 "Severity Classification" 같은 build-loop-only heading 이 발견되면 fail. |
| `phase-qa-fix.md` 분할 시 stage 간 cross-reference 가 깨질 가능성 | 분할 task 가 Sprint 2 plan 의 single subagent 에서 일괄 처리. 분할 후 모든 stage 파일에 prev/next link 추가 (예: stage-2 끝에 `→ stage-3-contract.md`). |
| Legacy `/sprint --type=qa-fix` alias 경로가 동작 안 함 | Sprint 2 plan 에 alias 동작 시나리오 명시적 smoke test. user-facing dep warning 메시지 정확히 표현. |
| `runs/` 구조 변경이 Sprint 0/1 (이미 commit 된) 에 영향 | Sprint 0/1 은 `runs/` flat 만 사용했고 실제 instance 데이터 commit 없음 (.gitkeep 만). 단순 디렉토리 reshape 으로 영향 0. |
| `kb-integration.md` 와 `docs/kb-system.md` 의 콘텐츠 중복 가능성 | 각 파일 첫 단락에 명시적 boundary statement: 어느 audience 향, 어느 정보 다룸. 중복 발견 시 kb-integration.md 가 docs/kb-system.md 를 reference (DRY). |
| `agent-team.md` (workflow 디스패치 protocol) 가 `.claude/teammates/*.md` (각 agent role guide) 와 혼동 | 각 파일 첫 단락에 boundary 설명. workflow 파일은 agent-team.md reference 만 하고 teammate 파일은 직접 참조 안 함 (스킬 시스템 분리). |

## Success Criteria

Sprint 2 ship 시점:

- [ ] `workflows/sprint/`, `workflows/qa-fix/`, `workflows/_shared/` 3 디렉토리 존재
- [ ] `workflows/sprint/` 에 `SKILL.md` + 7 phase markdown 파일 (`phase-{init,spec,prototype,build,pr,retro,modes}.md`)
- [ ] `workflows/qa-fix/` 에 `SKILL.md` + 5 stage markdown 파일 (`stage-{1-triage,2-grouping,3-contract,4-implement-eval,5-close}.md`)
- [ ] `workflows/_shared/` 에 4 파일 (`build-loop.md`, `agent-team.md`, `worktree.md`, `kb-integration.md`)
- [ ] `.claude/skills/sprint` symlink → `../../workflows/sprint`
- [ ] `.claude/skills/qa-fix` symlink → `../../workflows/qa-fix`
- [ ] `scripts/install-workflows.sh` idempotent + valid bash syntax
- [ ] `phase-build.md` + `stage-3-contract.md` + `stage-4-implement-eval.md` 가 `_shared/build-loop.md` reference + 자체에 Build Loop primitive inline 정의 없음
- [ ] `runs/sprint/.gitkeep` + `runs/qa-fix/.gitkeep` 존재, `runs/.gitkeep` 제거됨
- [ ] 모든 phase/stage 파일의 `runs/<id>/...` 경로가 `runs/sprint/<id>/...` 또는 `runs/qa-fix/<id>/...` 로 업데이트됨
- [ ] `/sprint <id> --type=qa-fix` 호출이 deprecation warn + `/qa-fix` 로 위임 (manual smoke test)
- [ ] `docs/workflow-authoring.md` 가 정식 가이드 (≥80 lines)
- [ ] `tests/kb-smoke.sh` 가 symlink 환경에서 PASS (KB skill 들은 변경 없으니 그대로 통과해야 함)
- [ ] `.github/workflows/ci.yml` 에 `install-workflows.sh` step 추가 + 전체 CI PASS
- [ ] CHANGELOG.md `[0.3.0-sprint-2]` entry 추가
- [ ] No ZZEM-leak (기존 scan 통과)
- [ ] working tree clean

## Out of Scope (v1.x+)

- Workflow yaml DSL / 선언적 정의 (master spec 의 옵션 B 거부 — v2.0 검토)
- Plugin lifecycle hook system (workflow 가 plugin 호출하는 인터페이스 — v2.0)
- 3번째 workflow 추가 (예: `document-release`, `security-audit`) — 추상화는 N=3 까지 검증 후
- Workflow 간 trigger / event passing
- Build Loop primitive 의 변형 (서로 다른 fix loop limit, severity 정의 등)
- Cross-workflow KB schema (예: qa-fix 가 sprint reflection 에 영향)
- Windows native symlink 호환성 (v1.0 = macOS/Linux + WSL)
- Workflow 별 CI matrix (현재는 단일 smoke step 으로 충분)
