# Sprint 3 — Stack Adapter Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec Section 4 (Stack adapter — placeholder + 마법사)
> Sprint context: zachflow v1.0 Sprint 3 — Sprint 2 (workflow split, `v0.3.0-sprint-2`) 직후

## Problem

Sprint 0/1/2 까지의 zachflow 는 placeholder 형태의 teammate 가이드를 가지고 있지만 사용자가 자기 프로젝트에 맞춰 채울 도구가 없다:

- `.claude/teammates/{be,fe,design,evaluator}-engineer.md` (Sprint 0 산출물) 에 `{{STACK_DESCRIPTION}}`, `{{REPO_LAYOUT}}`, `{{BUILD_CMD}}`, `{{CONVENTIONS}}` 같은 markers 가 있지만 — 사용자가 직접 grep + sed 로 채워야 함
- master spec section 4 가 약속한 `templates/teammates/*.template.md` (canonical templates) 디렉토리가 존재하지 않음
- master spec section 4 의 `init-project.sh` interactive wizard 가 존재하지 않음 (Sprint 0 의 placeholder 만 있음)
- 사용자가 처음 zachflow 를 clone 했을 때 "어떻게 시작하는가" 의 명확한 단일 entry-point 가 없음

**ship gate (master spec): "Empty zachflow repo can bootstrap a working sprint runner on Claude Code, verified end-to-end."**
이 ship gate 의 "bootstrap" 단계가 Sprint 3 의 산출물 — `init-project.sh` wizard.

## Solution

`init-project.sh` interactive wizard 를 구현하고 `templates/teammates/*.template.md` 정식 위치를 만든다. Wizard 는 새 사용자가 7-step 인터랙티브 프롬프트로 자기 프로젝트의 stack 을 zachflow 에 통합하게 한다. Non-interactive 모드 (`--from=init.config.yaml`) 도 지원해 CI/scripted setup 에 대응.

검증 가능한 ship gate (Sprint 3):

1. `bash scripts/init-project.sh` 실행 → 7개 prompt 진행 → 사용자 입력 기반 sprint-config.yaml + filled teammates + `.zachflow/kb/` 생성
2. `bash scripts/init-project.sh --from=init.config.yaml --non-interactive` 실행 → 동일 산출물, prompt 없이 자동
3. Wizard 산출물로 `/sprint <id> --phase=init` 실행 가능 (Sprint 1+2 의 sprint runner 가 wizard 의 sprint-config 를 정상 인식)
4. Templates 가 `templates/teammates/*.template.md` 에 정식 위치
5. Sprint 0 placeholders 가 `.claude/teammates/*.md` 에 그대로 잔존 (clone-and-go default)
6. `examples/README.md` 와 MANUAL.md 가 wizard usage 를 안내

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| Wizard 인터랙션 모델 | **Hybrid (interactive default + `--from=` escape hatch)** | OSS 첫 사용 경험이 v1.0 ship gate 의 핵심 — clone-and-go 가 가능해야. CI 사용 사례도 cover. |
| Template 위치 transition | **Copy (양쪽)** — `templates/teammates/*.template.md` (canonical) + `.claude/teammates/*.md` (placeholder defaults) | clone-and-go UX 보존, wizard 는 enhancement |
| Wizard 출력 위치 | sprint-config.yaml (root) + `.claude/teammates/*.md` (overwrites placeholders) + `.zachflow/kb/` (via kb-bootstrap.sh) | Sprint 0/1/2 의 기존 위치 일관성 유지 |
| Skip 처리 | 각 placeholder 단계에서 빈 입력 = "skip, leave `{{...}}` as-is" | 사용자가 일부만 채우고 나중에 직접 편집 가능 |
| Non-interactive 입력 형식 | YAML (`init.config.yaml`) | sprint-config.yaml 과 schema 호환, 사용자 친숙 |
| KB mode 선택 | embedded only (master spec) — remote 는 v1.1 안내만 | Sprint 1 결정 유지 |
| Wizard 검증 | 가벼운 inline (project name lowercase-hyphen, role key 패턴, branch_prefix 패턴) | bash 검증 충분, 별도 schema 검증 불필요 |
| Wizard 재실행 | 기존 sprint-config.yaml 감지 시 사용자 confirm + overwrite 또는 abort | 실수 방지, idempotent 보장 |

## Scope

### v1.0 (Sprint 3) 포함

- 신규 파일: `scripts/init-project.sh` (interactive + non-interactive wizard, ~250-350 lines bash)
- 신규 디렉토리: `templates/teammates/`
- 신규 파일: `templates/teammates/{be-engineer,fe-engineer,design-engineer,evaluator}.template.md` (4 files, copied from `.claude/teammates/*.md` placeholders + .template.md rename)
- 신규 파일: `templates/init.config.template.yaml` (사용자 채울 init config 템플릿 + JSONSchema 주석)
- 수정 파일: `examples/README.md` — wizard usage 안내 추가 (Sprint 0 stub 보강)
- 수정 파일: `MANUAL.md` — Setup 섹션에 wizard usage 추가 (Sprint 0 placeholder 채우기)
- 수정 파일: `.github/workflows/ci.yml` — wizard syntax check + non-interactive smoke 옵션 추가
- 수정 파일: `CHANGELOG.md` — `[0.4.0-sprint-3]` entry
- 신규 tag: `v0.4.0-sprint-3`

### v1.0 (Sprint 3) 제외 → v1.x 유보

- KB remote mode wizard (`zachflow kb migrate --remote=<url>`) — master spec out-of-scope
- Stack adapter examples 카탈로그 (외부 PR 누적 채널만)
- Wizard 의 advanced features (template inheritance, multi-stack mixing 등)
- Workflow 별 wizard 분기 (qa-fix-only init mode 등) — 현재 wizard 는 sprint+qa-fix 모두 활성화 가능
- 다국어 wizard (영문만)
- Wizard 의 GitHub Actions 통합 (`gh repo create --template` 직후 자동 wizard 실행) — Sprint 4 의 `create-zachflow` npm wrapper 책임

### 변경하지 않는 파일

- Sprint 0/1/2 산출물 (commits up through `v0.3.0-sprint-2`): 그대로 유지. 단 `.claude/teammates/*.md` 는 wizard 가 overwrite 가능 (사용자 옵션 — confirm gate).
- `workflows/sprint/`, `workflows/qa-fix/`, `workflows/_shared/` (Sprint 2): 무관, 변경 없음
- KB skills (`zachflow-kb:*`), schemas (Sprint 1): 무관, 변경 없음
- README.md, ARCHITECTURE.md, LICENSE: 무관
- `.zachflow/kb/` 의 user content: 무관 (init-project.sh 는 fresh `.zachflow/kb/` 생성을 위해 `kb-bootstrap.sh` 호출만)

## Detailed Design

### 1. 디렉토리 레이아웃 (Sprint 3 산출물 후)

```
~/dev/personal/zachflow/
├── scripts/
│   ├── init-project.sh             # ← Sprint 3 NEW
│   └── ... (Sprint 0/1/2 scripts)
│
├── templates/
│   ├── teammates/                  # ← Sprint 3 NEW
│   │   ├── be-engineer.template.md       # ← Sprint 3 NEW (copy from .claude/teammates/)
│   │   ├── fe-engineer.template.md
│   │   ├── design-engineer.template.md
│   │   └── evaluator.template.md
│   ├── init.config.template.yaml   # ← Sprint 3 NEW (non-interactive input template)
│   └── ... (Sprint 0/1 templates: prd, screen-spec, sprint-contract, etc.)
│
├── .claude/
│   ├── settings.json
│   ├── skills/
│   │   ├── sprint -> ../../workflows/sprint        # (Sprint 2 symlink)
│   │   ├── qa-fix -> ../../workflows/qa-fix        # (Sprint 2 symlink)
│   │   └── zachflow-kb/                            # (Sprint 1)
│   └── teammates/                  # MAY BE OVERWRITTEN by wizard
│       ├── be-engineer.md          # ← clone-and-go default (Sprint 0 placeholders) OR wizard output
│       ├── fe-engineer.md
│       ├── design-engineer.md
│       └── evaluator.md
│
├── examples/
│   └── README.md                   # ← Sprint 3 EXPANDED
│
├── MANUAL.md                       # ← Sprint 3 EXPANDED (Setup section)
├── CHANGELOG.md                    # ← Sprint 3 MODIFIED (0.4.0-sprint-3 entry)
└── .github/workflows/ci.yml        # ← Sprint 3 MODIFIED (init-project.sh smoke)
```

### 2. Wizard Interaction Model (Hybrid)

#### Default mode: Interactive

```bash
$ bash scripts/init-project.sh
zachflow init wizard v1.0
─────────────────────────

[1/7] Project name (lowercase-hyphen): my-app
[2/7] Activate workflows (sprint/qa-fix/both) [both]: both
[3/7] Branch prefix [run]: sprint
[4/7] Role definitions
      Add role? (y/n) [y]: y
      Role key (e.g., backend, app): backend
      Source repo path (~/dev/...): ~/dev/work/my-app-backend
      Base branch [main]: main
      Mode (worktree/symlink) [worktree]: worktree
      Add another role? (y/n) [y]: y
      ... (loop)
      Add another role? (y/n) [y]: n
[5/7] Fill teammate placeholders? (y/n) [y]: y
      For role 'backend' (BE Engineer):
        Stack description (1-2 sentences): NestJS 10 with Prisma + PostgreSQL...
        Repository layout (3-5 lines): apps/api/...
        Build & test commands (3-5 lines): pnpm install\npnpm tsc...
        Conventions (3-5 bullets): Use Zod for...
      For role 'app' (FE Engineer):
        ... (similar)
[6/7] KB mode (embedded only in v1.0; remote coming v1.1): embedded
[7/7] Initialize KB at .zachflow/kb/? (y/n) [y]: y

─────────────────────────
Summary:
  - sprint-config.yaml: my-app, branch_prefix=sprint, 2 roles
  - .claude/teammates/: 2 filled (backend BE, app FE), 2 left as placeholders (design, evaluator)
  - .zachflow/kb/: initialized (embedded mode)

Confirm and write? (y/n) [y]: y

Done. Next:
  /sprint <run-id>          to start a sprint
  /qa-fix <run-id> --jql=   to run QA fix loop
```

각 prompt 는 `read -p` + default 표시 + 빈 입력 처리.

#### Non-interactive mode: `--from=<config>`

```bash
$ bash scripts/init-project.sh --from=init.config.yaml --non-interactive
zachflow init: loading from init.config.yaml
[1/7] project_name: my-app
[2/7] workflows: both
... (no prompts, just confirms each loaded value)
Confirm and write? (auto-yes due to --non-interactive)
Done.
```

`init.config.yaml` schema:

```yaml
# init.config.yaml — non-interactive zachflow init input
# (template at templates/init.config.template.yaml)

project_name: my-app
workflows: both                     # sprint | qa-fix | both
branch_prefix: sprint               # default 'run' if both, 'sprint' if sprint-only, 'qa' if qa-fix-only
roles:
  - key: backend
    source: ~/dev/work/my-app-backend
    base: main
    mode: worktree                  # worktree | symlink
    teammate: be-engineer           # which template to fill (be-engineer | fe-engineer | design-engineer | evaluator)
    fill:
      stack_description: |
        NestJS 10 with Prisma + PostgreSQL...
      repo_layout: |
        apps/api/...
      build_cmd: |
        pnpm install
        pnpm tsc --noEmit
        pnpm test
      conventions: |
        - Use Zod for validation
        - ...
  - key: app
    source: ~/dev/work/my-app-app
    base: main
    mode: worktree
    teammate: fe-engineer
    fill:
      stack_description: ...
      ...
kb:
  mode: embedded                    # only 'embedded' supported in v1.0
init_kb: true                       # run kb-bootstrap.sh after wizard
```

#### Skip behavior (interactive mode)

빈 입력 = leave as default 또는 placeholder.

| Prompt | Empty input behavior |
|--------|---------------------|
| `[1/7] Project name` | required, prompt loops |
| `[2/7] Workflows` | uses default `both` |
| `[3/7] Branch prefix` | uses workflow-aware default |
| `[4/7] Role definitions` | "Add role?" defaulting to `y`; loop until user says `n`; require ≥1 role overall |
| `[5/7] Fill teammate placeholders` | `n` skips entirely (leave .claude/teammates/ as Sprint 0 placeholders) |
| `[5/7] Per-placeholder fill` | empty input → leave `{{NAME}}` as-is in output |
| `[6/7] KB mode` | uses default `embedded` |
| `[7/7] Init KB` | default `y` |

### 3. Templates Location Transition

#### Step 1: Copy current placeholders

`.claude/teammates/{be,fe,design,evaluator}-engineer.md` (Sprint 0 산출물 — placeholder form 유지) 를 `templates/teammates/{be,fe,design,evaluator}-engineer.template.md` 로 **copy** (move 가 아님 — `.claude/teammates/` 도 그대로 유지).

#### Step 2: Wizard reads from `templates/`

Wizard 가 fill 단계에서:
1. `templates/teammates/<role-teammate-name>.template.md` 읽음
2. `{{STACK_DESCRIPTION}}` 등 markers 를 사용자 입력으로 치환
3. `.claude/teammates/<teammate-name>.md` 로 write (overwrite 가능, confirm gate)

#### Why dual location?

- **`templates/teammates/`** = single source of truth for default placeholders. Future Sprint 4 의 `create-zachflow` npm wrapper 가 새 프로젝트 생성 시 이 위치를 reference.
- **`.claude/teammates/`** = "현재 적용된" teammate guides. Claude Code 가 직접 인식하는 위치. Sprint 0 의 placeholders 가 default, wizard 가 customize.

Drift 방지: Sprint 3 시작 시점에 두 위치 콘텐츠 동일. 이후 wizard 만 `.claude/teammates/` 수정. `templates/teammates/` 는 향후 zachflow 메인테너만 갱신 (e.g., placeholder marker 추가/제거).

### 4. Wizard 7 Steps (Detail)

#### Step 1: Project name

```bash
read -p "[1/7] Project name (lowercase-hyphen): " PROJECT_NAME
# Validate: matches ^[a-z][a-z0-9-]*$, 3+ chars
```

빈 입력 → reprompt. 유효하지 않으면 `Error: project name must be lowercase-hyphen, 3+ chars` + reprompt.

#### Step 2: Workflows

```bash
read -p "[2/7] Activate workflows (sprint/qa-fix/both) [both]: " WORKFLOWS
WORKFLOWS=${WORKFLOWS:-both}
# Validate: in {sprint, qa-fix, both}
```

#### Step 3: Branch prefix

```bash
DEFAULT_PREFIX="run"
[ "$WORKFLOWS" = "sprint" ] && DEFAULT_PREFIX="sprint"
[ "$WORKFLOWS" = "qa-fix" ] && DEFAULT_PREFIX="qa"

read -p "[3/7] Branch prefix [$DEFAULT_PREFIX]: " BRANCH_PREFIX
BRANCH_PREFIX=${BRANCH_PREFIX:-$DEFAULT_PREFIX}
# Validate: ^[a-z][a-z0-9-]*$
```

#### Step 4: Role definitions (loop)

```bash
ROLES=()  # array of "key|source|base|mode|teammate"

while true; do
  read -p "Add role? (y/n) [y]: " ADD
  ADD=${ADD:-y}
  [ "$ADD" != "y" ] && break

  read -p "  Role key: " ROLE_KEY
  read -p "  Source repo path: " ROLE_SOURCE
  read -p "  Base branch [main]: " ROLE_BASE
  ROLE_BASE=${ROLE_BASE:-main}
  read -p "  Mode (worktree/symlink) [worktree]: " ROLE_MODE
  ROLE_MODE=${ROLE_MODE:-worktree}
  read -p "  Teammate template (be-engineer/fe-engineer/design-engineer/evaluator) [be-engineer]: " ROLE_TEAMMATE
  ROLE_TEAMMATE=${ROLE_TEAMMATE:-be-engineer}

  ROLES+=("$ROLE_KEY|$ROLE_SOURCE|$ROLE_BASE|$ROLE_MODE|$ROLE_TEAMMATE")
done

# Require at least 1 role
[ ${#ROLES[@]} -eq 0 ] && { echo "Error: at least 1 role required"; exit 1; }
```

#### Step 5: Teammate placeholder fill

```bash
read -p "[5/7] Fill teammate placeholders? (y/n) [y]: " FILL
FILL=${FILL:-y}

if [ "$FILL" = "y" ]; then
  for role_entry in "${ROLES[@]}"; do
    IFS='|' read -ra parts <<< "$role_entry"
    ROLE_KEY="${parts[0]}"
    TEAMMATE="${parts[4]}"

    echo "  For role '$ROLE_KEY' ($TEAMMATE):"
    read -p "    Stack description (1-2 sentences, blank to skip): " STACK_DESC
    read -p "    Repository layout (3-5 lines, end with empty line; blank to skip): " REPO_LAYOUT
    read -p "    Build & test commands (3-5 lines, end with empty line; blank to skip): " BUILD_CMD
    read -p "    Conventions (3-5 bullets, end with empty line; blank to skip): " CONVENTIONS

    # Apply substitutions to templates/teammates/<TEAMMATE>.template.md
    # Write output to .claude/teammates/<TEAMMATE>.md
    # If multi-role with same teammate type, last wins (warn user)
  done
fi
```

#### Step 6: KB mode

```bash
echo "[6/7] KB mode (embedded only in v1.0; remote coming v1.1):"
read -p "  Mode [embedded]: " KB_MODE
KB_MODE=${KB_MODE:-embedded}

[ "$KB_MODE" != "embedded" ] && {
  echo "Warning: only 'embedded' is supported in v1.0; setting to 'embedded'"
  KB_MODE="embedded"
}
```

#### Step 7: Init KB + summary + confirm

```bash
read -p "[7/7] Initialize KB at .zachflow/kb/? (y/n) [y]: " INIT_KB
INIT_KB=${INIT_KB:-y}

# Print summary
echo "─────────────────────────"
echo "Summary:"
echo "  - sprint-config.yaml: $PROJECT_NAME, branch_prefix=$BRANCH_PREFIX, ${#ROLES[@]} roles"
echo "  - .claude/teammates/: $FILLED_COUNT filled, $UNFILLED_COUNT placeholders remain"
echo "  - .zachflow/kb/: $([ "$INIT_KB" = "y" ] && echo "initialized" || echo "skipped")"
echo "─────────────────────────"

read -p "Confirm and write? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}
[ "$CONFIRM" != "y" ] && { echo "Aborted."; exit 1; }

# Write sprint-config.yaml
# Write filled .claude/teammates/*.md
# Run kb-bootstrap.sh if INIT_KB=y
# Run install-workflows.sh (idempotent)
```

### 5. Re-run Detection (Idempotency)

```bash
if [ -f sprint-config.yaml ]; then
  echo "Warning: sprint-config.yaml already exists."
  read -p "Overwrite? (y/n) [n]: " OVERWRITE
  OVERWRITE=${OVERWRITE:-n}
  [ "$OVERWRITE" != "y" ] && { echo "Aborted."; exit 1; }
fi

# Same check for .claude/teammates/<name>.md if any will be filled
# (only warn if existing file has been wizard-filled previously — detect via marker)
```

Wizard 가 fill 한 teammate 파일은 frontmatter (또는 inline comment) 로 marker 추가:

```markdown
<!-- zachflow init-project.sh wizard fill — 2026-04-27T... -->
# BE Engineer
...
```

Re-run 시 marker 감지 → "이 파일은 wizard 가 채운 거예요. overwrite OK?" prompt.

### 6. `init.config.template.yaml` Content

```yaml
# templates/init.config.template.yaml
# Copy this file to your project root, edit, then run:
#   bash scripts/init-project.sh --from=init.config.yaml --non-interactive

# Project metadata
project_name: my-project           # required, lowercase-hyphen
workflows: both                    # sprint | qa-fix | both
branch_prefix: sprint              # default branch prefix for runs

# Role definitions (1+ required)
roles:
  - key: backend                   # role key (used in directory names)
    source: ~/dev/work/<your-be-repo>   # absolute path or ~ to your repo
    base: main                     # base branch
    mode: worktree                 # worktree | symlink
    teammate: be-engineer          # which teammate template to fill
    fill:                          # placeholder fills (omit to leave as-is)
      stack_description: |
        Describe your backend stack here (1-2 sentences).
      repo_layout: |
        Brief description of top-level directory structure.
      build_cmd: |
        # commands to verify implementation
        npm install
        npm run typecheck
        npm test
      conventions: |
        - Convention 1
        - Convention 2
        - Convention 3

  # - key: app
  #   source: ~/dev/work/<your-fe-repo>
  #   base: main
  #   mode: worktree
  #   teammate: fe-engineer
  #   fill:
  #     ...

# KB configuration
kb:
  mode: embedded                   # only 'embedded' in v1.0
init_kb: true                      # run kb-bootstrap.sh
```

### 7. `examples/README.md` Update

Sprint 0 stub 가 단순 메시지였음. Sprint 3 에서 wizard usage 추가:

```markdown
# Examples

This directory is for **stack adapter examples** — concrete configurations showing how to set up zachflow for specific tech stacks.

## Quick start (using the wizard)

```bash
git clone https://github.com/<org>/zachflow.git my-project
cd my-project
bash scripts/init-project.sh
```

The wizard prompts for project name, workflows, role definitions, and teammate stack details. After completion, your sprint-config.yaml and `.claude/teammates/` are filled and ready.

For CI / scripted setup, use non-interactive mode:

```bash
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml with your project specifics
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

## Stack adapter examples

v1.0 ships with the directory empty. External contributions welcome — see [`CONTRIBUTING.md`](../CONTRIBUTING.md).

(Sprint 4 lands `plugins/recall/` as the first reference plugin example.)

## What an example contains

```
examples/<your-stack>/
├── README.md                     # what stack this targets, who maintains
├── init.config.yaml              # filled non-interactive config
├── sprint-config.example.yaml    # generated sprint config (verify wizard output)
└── teammates/
    ├── be-engineer.md             # filled BE Engineer guide for this stack
    ├── fe-engineer.md
    ├── design-engineer.md
    └── evaluator.md
```
```

### 8. `MANUAL.md` Setup Section Update

Sprint 0 의 Setup section 이 wizard 미구현 상태에서 placeholder. Sprint 3 가 채움:

```markdown
## Setup

### First-time setup

```bash
git clone https://github.com/<org>/zachflow.git my-project
cd my-project
bash scripts/init-project.sh
```

The wizard takes ~5 minutes. After completion:
- `sprint-config.yaml` defines your project's roles and base branches
- `.claude/teammates/*.md` are filled with your stack specifics
- `.zachflow/kb/` is initialized (embedded mode)

### Non-interactive setup (for CI)

```bash
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

### Re-running the wizard

If you re-run `init-project.sh` and `sprint-config.yaml` exists, the wizard prompts before overwriting. Use `--force` to skip the prompt (with care — overwrites your customizations).

### Skipping placeholder fills

In step 5/7, answer `n` to skip teammate filling entirely; or per-placeholder, leave blank to keep the `{{...}}` marker. You can edit `.claude/teammates/*.md` directly later.
```

### 9. CI Smoke Update

`.github/workflows/ci.yml` 에 wizard syntax + non-interactive smoke step 추가:

```yaml
      - name: init-project.sh syntax check
        run: bash -n scripts/init-project.sh

      - name: init-project.sh non-interactive smoke (using fixture)
        run: |
          # Create a fixture init.config.yaml and run wizard non-interactively in a temp dir
          # Verify outputs match expectations
          bash tests/init-project-smoke.sh
```

신규 `tests/init-project-smoke.sh` 가 wizard 의 non-interactive 모드를 fixture 로 검증.

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| Bash wizard 가 길어져 (~250-350 lines) 유지보수 어려움 | 단일 파일 안에 함수로 단계별 분리 (step1_project_name, step2_workflows, ...). 각 함수는 50 lines 미만 목표. |
| `read -p` multi-line input (여러 줄 placeholders) 처리 어려움 | 다행히도 placeholder fills (stack_description, repo_layout, build_cmd, conventions) 는 single string 으로 처리해도 충분 (나중에 사용자가 직접 편집 가능). multi-line input 은 \n 으로 separator. |
| Templates/teammates 와 .claude/teammates 콘텐츠 drift | Sprint 3 시작 시점에 동일하도록 commit 조정. 이후 wizard 만 .claude/teammates 수정. CI smoke 가 templates/teammates/<file>.template.md 과 .claude/teammates/<file>.md 의 placeholder marker 들이 일치하는지 검증 (선택). |
| Wizard re-run 시 사용자 customization overwrite | 명시적 confirm gate + zachflow wizard fill marker 감지 + `--force` flag 만 silent overwrite. |
| 빈 placeholder (`{{NAME}}`) 가 sprint runner 에서 작동하지 않을까 우려 | 작동함. Sprint 0/1/2 가 placeholder 형태로 검증됐고, sprint runner 는 teammate description 의 placeholder 를 기능적 콘텐츠로 받지 않음 (그냥 markdown context). 빈 placeholder 는 단순히 "사용자가 채울 부분" 표시. |
| Non-interactive mode 의 init.config.yaml 형식 사용자가 어려워함 | `templates/init.config.template.yaml` 에 풍부한 주석 + examples/README.md 에 sample init.config.yaml |
| Wizard 가 sprint-config.yaml 형식을 wrong 으로 생성 → sprint runner 작동 불가 | CI smoke 에서 wizard non-interactive 실행 후 결과 sprint-config.yaml 을 actual schema (기존 templates/sprint-config.template.yaml) 와 비교. |
| 사용자가 wizard 를 zachflow 가 아닌 별도 디렉토리에서 실행 | wizard 첫 단계에서 `[ -f scripts/install-workflows.sh ]` 체크 → 없으면 "Run from zachflow project root" 에러. |

## Success Criteria

Sprint 3 ship 시점:

- [ ] `scripts/init-project.sh` 존재 + 실행 가능 (`chmod +x`)
- [ ] `bash -n scripts/init-project.sh` syntax OK
- [ ] Interactive mode: 7 prompts 정상 진행, 빈 입력 처리, validation 작동
- [ ] Non-interactive mode (`--from=init.config.yaml --non-interactive`): YAML 입력 파싱 + 동일 산출물
- [ ] `templates/teammates/{be,fe,design,evaluator}-engineer.template.md` 존재 + 콘텐츠가 `.claude/teammates/<same>.md` 와 동일 (Sprint 3 시작 시점)
- [ ] `templates/init.config.template.yaml` 존재 + 사용자 채울 만한 주석/예시 포함
- [ ] Wizard 산출 sprint-config.yaml 이 `workflows/sprint/SKILL.md` invocation 에서 정상 인식 (smoke test)
- [ ] Wizard 산출 `.claude/teammates/<name>.md` 가 fill marker (HTML comment) + 사용자 입력으로 채워진 placeholders
- [ ] Re-run 시 sprint-config.yaml 존재 → confirm prompt + abort/overwrite 옵션
- [ ] `--force` flag 가 confirm gate skip
- [ ] `tests/init-project-smoke.sh` PASS (CI에서)
- [ ] `examples/README.md` wizard usage 안내 추가
- [ ] `MANUAL.md` Setup section 채워짐
- [ ] `.github/workflows/ci.yml` 에 init-project syntax check + non-interactive smoke step
- [ ] `CHANGELOG.md` `[0.4.0-sprint-3]` entry
- [ ] Tag `v0.4.0-sprint-3`
- [ ] No ZZEM-leak (기존 scan 통과)
- [ ] Working tree clean

## Out of Scope (v1.x+)

- KB remote mode wizard (`zachflow kb migrate --remote=<url>`)
- Stack adapter examples (외부 PR 채널만 — 첫 PR 은 zachflow community 가 contribute)
- Multi-stack mixing (한 wizard 실행에서 여러 stack 정의 — 현재는 role-by-role 만)
- Template inheritance (예: `extends: be-engineer-typescript`)
- Wizard 의 GitHub Actions 통합 (Sprint 4 의 `create-zachflow` 책임)
- 다국어 wizard
- Wizard 의 GUI/web 버전
- `init.config.yaml` 의 JSONSchema 검증 (현재는 bash inline 검증으로 충분)
- 사용자 customize 후 `templates/teammates/*.template.md` 자동 갱신 (드물고 보통 사용자가 따로 관리하길 원함)
- KB 에서 patterns 자동 import (사용자가 다른 zachflow 프로젝트에서 가져오는 사례)
- workflows 추가 (security-audit, document-release 등 — N=3 검증 후 v1.x 도입)
