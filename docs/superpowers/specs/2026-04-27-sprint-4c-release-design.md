# Sprint 4c — create-zachflow + v1.0 Release Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec Section 6 (Distribution) + master spec Sprint 4 split absorption
> Sprint context: Sprint 4 의 3-way split 중 마지막. `v0.6.0-sprint-4b-gallery` 직후. **v1.0 의 final release sprint**.

## Problem

zachflow `v0.6.0-sprint-4b-gallery` 까지 v1.0 의 모든 코어 기능 (sprint workflow, KB embedded, qa-fix, init wizard, recall plugin, gallery package) 이 구현됐지만 **사용자 onboarding entry-point 와 release 인프라 부재**:

- master spec Section 6 의 `npx create-zachflow my-project` 약속 미충족 — 신규 사용자가 zachflow 시작하려면 `git clone` 후 strip 작업 수동
- README.md / CONTRIBUTING.md 가 Sprint 0/3 placeholder 수준 — v1.0 ship message 미반영
- ARCHITECTURE.md / MANUAL.md 가 Sprint 0~3 내용만 — Sprint 4a/4b 의 plugins, gallery 미반영
- GitHub Actions release workflow 부재 — tag push 시 자동 GitHub Release 생성 안 됨
- v1.0.0 final tag 미존재 — ship 선언 미발생

## Solution

`packages/create-zachflow/` Node.js wrapper 신설 (clone-and-strip 패턴), root docs (README/CONTRIBUTING/ARCHITECTURE/MANUAL) 를 v1.0 polish, GitHub Actions release workflow 추가, 최종 `v1.0.0` tag.

검증 가능한 ship gate (Sprint 4c — v1.0 final):

1. `packages/create-zachflow/index.js` Node.js 스크립트 0-deps clone-and-strip 작동
2. 빈 디렉토리에서 `node packages/create-zachflow/index.js my-test --repo=$(pwd)` 실행 → my-test/ 에 stripped zachflow 생성, dev artifacts 제거 확인
3. `cd my-test && bash scripts/init-project.sh --from=init.config.yaml --non-interactive --force` PASS (Sprint 3 wizard 작동 검증)
4. `cd my-test && /sprint test-001 --phase=init` 시나리오 (Claude Code 환경) — 이건 manual smoke
5. README.md v1.0 (badges + quickstart + feature list + architecture diagram + docs links)
6. CONTRIBUTING.md v1.0 (issue/PR 가이드 + coding standards + license sign-off)
7. ARCHITECTURE.md v1.0 polish (plugin/gallery 추가)
8. MANUAL.md v1.0 polish (plugin install + gallery dev/build 추가)
9. `.github/workflows/release.yml` — tag push 시 GitHub Release 생성 (CHANGELOG excerpt 포함)
10. CHANGELOG `[1.0.0]` final entry
11. roadmap.md Sprint 4c checked + v1.0 banner
12. **`v1.0.0` final tag** 🎉

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| `create-zachflow` 동작 | **A: Clone-and-strip** | 단일 source repo (zachflow 자체) 유지. strip 로직 명시적. v1.x 에서 tarball/separate template repo 도입 검토 |
| Wizard 자동 실행 여부 | **수동** — 안내 메시지만 출력 | 12-prompt wizard 는 무거움. 사용자가 자기 페이스로 |
| 언어 | **Node.js 0-deps** | npm 표준, `npx` 환경 자연스러움. child_process / fs / path 만 사용 |
| 기본 zachflow URL | env var / flag override 가능, package.json 의 `config.repo_url` 에 default | 외부 사용자 자유 (zachflow 가 어디 host 됐든) |
| npm publish | **v1.0 미포함** — `private: true` 유지 | 외부 사용자는 `npx --yes github:<user>/zachflow#main` 형식으로 사용 가능. v1.x 에서 npm publish 검토 |
| Release CI 동작 | tag push (`v*`) trigger → GitHub Release 자동 생성 | 사용자가 manual release 안 만들어도 됨 |
| v1.0 tag strategy | **Direct `v1.0.0`** (no rc) | Sprint 4c 끝에 final commit + tag |
| docs/superpowers/ 처리 | **그대로 유지** (zachflow main 에). create-zachflow 가 strip | contributors 가 design history 참조 가능 |
| Sprint 4c 자체의 docs/superpowers/ | **commit** | Sprint 1/2/3/4a/4b 와 일관 |

## Scope

### v1.0 (Sprint 4c) 포함

- 신규 디렉토리: `packages/create-zachflow/`
- `packages/create-zachflow/index.js` (~150 lines Node.js, 0-deps clone-and-strip)
- `packages/create-zachflow/package.json` (with `bin` entry, `private: true`)
- `packages/create-zachflow/README.md` (~50 lines, user-facing)
- `README.md` v1.0 polish (root, badges + quickstart + features)
- `CONTRIBUTING.md` v1.0 polish (issue/PR + standards + license)
- `ARCHITECTURE.md` v1.0 polish (plugins/gallery 추가)
- `MANUAL.md` v1.0 polish (plugin install + gallery sections)
- `.github/workflows/release.yml` (tag push → GitHub Release)
- root `package.json`: `create-zachflow` 추가 (이미 workspaces 설정됨)
- `CHANGELOG.md` `[1.0.0]` final entry
- `docs/roadmap.md` Sprint 4c checked + v1.0 banner
- **`v1.0.0` final tag** 🎉

### v1.0 (Sprint 4c) 제외 → v1.1+

- npm publish (registry publishing automation) — v1.x
- Tarball release artifact — v1.x (master spec section 6 의 옵션 C)
- Separate `zachflow-template` repo — v1.x 옵션
- Code of Conduct (CoC) — v1.x community establishment
- GitHub issue/PR templates (`.github/ISSUE_TEMPLATE/*.md` 등) — v1.x
- Multi-platform CI matrix (Windows, etc.) — v2.0
- Automated changelog generation — v1.x
- Semantic-release / version bump automation — v1.x
- Pre-release channels (alpha, beta, rc) — v1.x

### 변경하지 않는 파일

- Sprint 0/1/2/3/4a/4b 산출물 (commits up through `v0.6.0-sprint-4b-gallery`): 그대로
- workflows/, plugins/recall/, packages/zachflow-gallery/: 변경 없음
- KB skills, schemas, init-project.sh, install-workflows.sh, install-plugins.sh: 변경 없음
- `tests/`: 변경 없음

## Detailed Design

### 1. 디렉토리 레이아웃 (Sprint 4c 산출물)

```
~/dev/personal/zachflow/
├── packages/
│   ├── zachflow-gallery/                 # (Sprint 4b)
│   └── create-zachflow/                  # ← Sprint 4c NEW
│       ├── index.js                      # ~150 lines, 0-deps Node.js
│       ├── package.json                  # bin entry, private: true
│       └── README.md                     # ~50 lines
│
├── .github/workflows/
│   ├── ci.yml                            # (existing)
│   ├── gallery.yml.example               # (Sprint 4b)
│   └── release.yml                       # ← Sprint 4c NEW
│
├── README.md                             # v1.0 POLISHED
├── CONTRIBUTING.md                       # v1.0 POLISHED
├── ARCHITECTURE.md                       # v1.0 POLISHED (plugins/gallery 추가)
├── MANUAL.md                             # v1.0 POLISHED (plugin/gallery sections)
├── CHANGELOG.md                          # [1.0.0] entry
├── docs/roadmap.md                       # Sprint 4c checked + v1.0 banner
└── package.json                          # workspaces (no change — Sprint 4b 가 이미 설정)
```

Total NEW files: 4 (create-zachflow package + release.yml). Modified: 5 (4 root docs + roadmap + CHANGELOG).

### 2. `packages/create-zachflow/index.js` 동작

```javascript
#!/usr/bin/env node
// create-zachflow — bootstrap a new zachflow project via clone-and-strip.
//
// Usage:
//   npx create-zachflow my-project
//   npx create-zachflow my-project --repo=https://github.com/<owner>/zachflow.git
//   npx create-zachflow my-project --branch=v1.0.0
//
// Env vars:
//   ZACHFLOW_REPO_URL — override default repo URL
//   ZACHFLOW_REF — override default branch/tag (main)

const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_REPO = process.env.ZACHFLOW_REPO_URL ||
  'https://github.com/<your-org>/zachflow.git';  // placeholder — user overrides
const DEFAULT_REF = process.env.ZACHFLOW_REF || 'main';

const STRIP_LIST = [
  '.git',
  'docs/superpowers',     // design history (contributors only)
  '.zachflow',            // per-project state (wizard creates fresh)
  'node_modules',         // npm install creates fresh
  'dist',                 // build output
  'package-lock.json',    // regenerate
];

// Argument parsing
const args = process.argv.slice(2);
let target = null;
let repoUrl = DEFAULT_REPO;
let ref = DEFAULT_REF;

for (const arg of args) {
  if (arg.startsWith('--repo=')) {
    repoUrl = arg.slice('--repo='.length);
  } else if (arg.startsWith('--branch=') || arg.startsWith('--tag=')) {
    ref = arg.slice(arg.indexOf('=') + 1);
  } else if (arg === '--help' || arg === '-h') {
    printHelp();
    process.exit(0);
  } else if (!arg.startsWith('--')) {
    if (target) {
      console.error('Error: multiple target directories specified');
      process.exit(1);
    }
    target = arg;
  } else {
    console.error(`Unknown flag: ${arg}`);
    process.exit(1);
  }
}

if (!target) {
  console.error('Usage: npx create-zachflow <project-name>');
  console.error('Run with --help for more options.');
  process.exit(1);
}

// Validate target doesn't exist
const targetPath = path.resolve(process.cwd(), target);
if (fs.existsSync(targetPath)) {
  const entries = fs.readdirSync(targetPath);
  if (entries.length > 0) {
    console.error(`Error: ${target} already exists and is not empty`);
    process.exit(1);
  }
}

console.log(`Cloning zachflow from ${repoUrl} (${ref})...`);

// 1. Shallow clone
try {
  execSync(`git clone --depth 1 --branch "${ref}" "${repoUrl}" "${targetPath}"`, { stdio: 'inherit' });
} catch (err) {
  console.error(`Error: git clone failed`);
  process.exit(1);
}

// 2. Strip dev artifacts
console.log('Stripping development artifacts...');
for (const item of STRIP_LIST) {
  const itemPath = path.join(targetPath, item);
  if (fs.existsSync(itemPath)) {
    fs.rmSync(itemPath, { recursive: true, force: true });
    console.log(`  removed: ${item}`);
  }
}

// 3. Re-init git
console.log('Initializing fresh git repo...');
execSync('git init -b main', { cwd: targetPath, stdio: 'inherit' });
execSync('git add .', { cwd: targetPath, stdio: 'inherit' });
execSync('git commit -m "chore: initial commit from zachflow template"', { cwd: targetPath, stdio: 'inherit' });

// 4. Print next steps
console.log('');
console.log(`✓ zachflow project created at ${target}/`);
console.log('');
console.log('Next steps:');
console.log(`  cd ${target}`);
console.log('  bash scripts/init-project.sh        # interactive wizard (~5 min)');
console.log('  # or for CI/scripted:');
console.log('  cp templates/init.config.template.yaml init.config.yaml');
console.log('  bash scripts/init-project.sh --from=init.config.yaml --non-interactive');
console.log('');

function printHelp() {
  console.log(`Usage:
  npx create-zachflow <project-name> [options]

Options:
  --repo=<url>       Override default zachflow repo URL
                     (default: ${DEFAULT_REPO})
  --branch=<name>    Clone a specific branch (default: main)
  --tag=<tag>        Clone a specific tag (e.g., v1.0.0)
  --help, -h         Show this message

Env vars:
  ZACHFLOW_REPO_URL  Override default repo URL
  ZACHFLOW_REF       Override default branch/tag

Examples:
  npx create-zachflow my-project
  npx create-zachflow my-project --tag=v1.0.0
  ZACHFLOW_REPO_URL=https://github.com/me/zachflow.git npx create-zachflow my-project
`);
}
```

### 3. `packages/create-zachflow/package.json`

```json
{
  "name": "create-zachflow",
  "version": "1.0.0",
  "private": true,
  "description": "Bootstrap a new zachflow project (clone-and-strip).",
  "license": "MIT",
  "bin": {
    "create-zachflow": "./index.js"
  },
  "config": {
    "repo_url": "https://github.com/<your-org>/zachflow.git"
  },
  "engines": {
    "node": ">=18"
  }
}
```

(`private: true` — npm publish 는 v1.x. 사용자는 `npx --yes github:<user>/zachflow#main packages/create-zachflow my-project` 로 우회 사용 가능.)

### 4. `packages/create-zachflow/README.md`

```markdown
# create-zachflow

Bootstrap a new zachflow project.

## Usage

```bash
npx create-zachflow my-project
```

This:
1. Shallow-clones the zachflow repo to `my-project/`
2. Strips development artifacts (`.git/`, `docs/superpowers/`, etc.)
3. Re-initializes git with a fresh first commit
4. Prints next steps (run the wizard)

After completion:

```bash
cd my-project
bash scripts/init-project.sh
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--repo=<url>` | github.com/<your-org>/zachflow.git | Repo URL |
| `--branch=<name>` | `main` | Branch to clone |
| `--tag=<tag>` | (none) | Tag to clone (e.g., `v1.0.0`) |
| `--help`, `-h` | | Show help |

Env vars: `ZACHFLOW_REPO_URL`, `ZACHFLOW_REF`.

## What gets stripped

The following are removed from the cloned repo:
- `.git/` (replaced with fresh git init)
- `docs/superpowers/` (zachflow design history — for contributors)
- `.zachflow/` (per-project state — wizard creates fresh)
- `node_modules/`, `dist/`, `package-lock.json` (regenerated)

What stays: `workflows/`, `plugins/`, `scripts/`, `templates/`, `.claude/`, `schemas/`, `tests/`, `packages/`, all root docs (README, MANUAL, ARCHITECTURE, CONTRIBUTING, CHANGELOG, LICENSE).

## v1.0 limitations

- Not yet on npm registry (you can install via `npx github:<user>/zachflow#main packages/create-zachflow`).
- v1.x will add npm publish + tarball release artifact for faster install.

## License

MIT
```

### 5. Root `README.md` v1.0 Polish

Sprint 0 의 README 는 v0.1 placeholder. Sprint 4c 가 v1.0 정식화:

```markdown
# zachflow

Harness-driven sprint orchestration for AI coding agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)]()

zachflow is a workflow harness that brings explicit phase gates, file-based handoff, and contract-first development to long-running coding sessions on Claude Code's Agent Teams. It implements the **Planner–Generator–Evaluator** pattern with cross-session knowledge accumulation.

## Quick start

```bash
npx create-zachflow my-project
cd my-project
bash scripts/init-project.sh
```

The interactive wizard takes ~5 minutes. After completion, you have a working sprint runner ready to run `/sprint <run-id>` in Claude Code.

For non-interactive setup (CI):

```bash
npx create-zachflow my-project
cd my-project
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

## Features

- **Two first-class workflows**: `/sprint` (PRD → Spec → Prototype → Build → PR → Retro) and `/qa-fix` (Jira ticket triage and fix orchestration)
- **Build Loop primitive** (Contract → Implement → Evaluate → Fix) shared across workflows
- **Embedded Knowledge Base** (`zachflow-kb:*` skills) — patterns/rubrics/reflections in `.zachflow/kb/`, no external repo required
- **Stack-agnostic teammate templates** — placeholder-based BE/FE/Design/Evaluator role guides, filled by interactive wizard
- **Plugin system** — optional, user-installable extensions (v1.0 ships `recall:ask` for interactive sprint/KB recall)
- **Auto-indexed gallery** — Astro shell that renders `runs/sprint/<id>/prototypes/` outputs (`packages/zachflow-gallery/`)
- **Worktree-isolated sprints** — each sprint runs in dedicated git worktrees, no cross-sprint contamination
- **Active Evaluation** — independent Evaluator agent traces logic + probes edge cases (not just static checks)

## Architecture

```
.claude/skills/         # Claude Code workflow + KB skill registration
workflows/              # platform-agnostic workflow content
  ├── sprint/           # 6-phase sprint pipeline
  ├── qa-fix/           # 5-stage QA fix pipeline
  └── _shared/          # Build Loop, agent dispatch, worktree, KB integration primitives
plugins/                # optional user-installable extensions
  └── recall/           # interactive sprint/KB recall (reference plugin)
packages/               # monorepo workspaces
  ├── zachflow-gallery/ # Astro auto-indexed prototype gallery
  └── create-zachflow/  # npm bootstrap wrapper
templates/              # init wizard templates + sprint artifact templates
schemas/                # JSON Schema for KB content (pattern, rubric, reflection)
runs/                   # sprint instance directories (sprint/, qa-fix/)
.zachflow/kb/           # embedded Knowledge Base (per-project)
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for principles + Build Loop detail, [`MANUAL.md`](MANUAL.md) for operations, [`docs/`](docs/) for KB system, plugin authoring, workflow authoring, and roadmap.

## Status

**v1.0.0** — released. Runs on Claude Code Agent Teams. Multi-LLM platform support is on the v1.x roadmap (see [`docs/llm-platform-coupling.md`](docs/llm-platform-coupling.md)).

Track v1.x progress in [`docs/roadmap.md`](docs/roadmap.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for issue reporting, PR conventions, and coding standards.

## License

MIT — see [`LICENSE`](LICENSE).
```

### 6. `CONTRIBUTING.md` v1.0 Polish

```markdown
# Contributing to zachflow

Thanks for considering a contribution! zachflow is an opinionated harness — most contributions land best as plugins or stack adapter examples rather than core changes.

## Reporting Issues

Open a GitHub issue with:
- zachflow version (`v1.0.0` etc, see CHANGELOG.md)
- macOS/Linux + bash version (`bash --version`)
- Reproduction steps
- Expected vs actual behavior

For Claude Code-related issues (subagent dispatch, skill discovery), include the relevant SKILL.md path and frontmatter.

## Submitting Pull Requests

1. **Open an issue first** for non-trivial changes — discuss scope before implementing
2. Fork + branch from `main`
3. Make your changes following the coding standards below
4. Add CHANGELOG entry under `## [Unreleased]`
5. Run smoke tests locally: `bash tests/kb-smoke.sh && bash tests/init-project-smoke.sh && bash plugins/recall/tests/test_config.sh && bash plugins/recall/tests/test_session.sh`
6. Open PR with description: what changed, why, how tested

## Coding Standards

### Bash scripts (`scripts/`, `tests/`, `packages/*/scripts/`)
- Bash 3.2+ compatible (no `declare -A` associative arrays — macOS default `/bin/bash` is 3.2.57)
- Always `set -euo pipefail`
- Use `${KB_PATH:-./.zachflow/kb}` style env-var fallback
- Validate with `bash -n` before commit
- For new scripts: include header comment block with usage + flags

### Markdown content (workflows/, plugins/, docs/)
- English only
- No ZZEM literals (zachflow inherited a sanitization commitment from upstream zzem-orchestrator — see `docs/llm-platform-coupling.md`)
- Code fences balanced
- Cross-references use relative paths

### Skill protocols (`.claude/skills/*/SKILL.md`, `plugins/*/<skill>/SKILL.md`)
- Frontmatter with `name: <skill-name>` (or `<plugin>:<skill>` for plugins)
- Sections: Inputs, Preconditions, Steps, Failure handling, Verification
- Reference shared primitives (`workflows/_shared/build-loop.md`) instead of inline duplication

### Adding a new plugin

See `docs/plugin-authoring.md` for the 10-step checklist. Plugins live under `plugins/<name>/` and are user-installable via `bash scripts/install-plugins.sh <name>`.

### Adding a new workflow

See `docs/workflow-authoring.md`. Workflows live under `workflows/<name>/` and auto-install via `scripts/install-workflows.sh`.

## License Sign-off

By submitting a PR, you agree your contribution is licensed under MIT (the project license). Add a `Signed-off-by: Your Name <email>` line to commit messages for significant contributions.

## Code of Conduct

(v1.x will add a formal CoC. For v1.0, the rule is simple: be respectful, focus on the work, no harassment.)
```

### 7. `ARCHITECTURE.md` v1.0 Polish

Sprint 0 의 ARCHITECTURE.md (~80 lines) 가 sprint pipeline + Build Loop 만 다룸. Sprint 4c 가 plugins + gallery section 추가:

```markdown
# zachflow Architecture

(... existing Sprint 0 sections preserved: Design Principles, Sprint Pipeline, Build Loop, QA-Fix Workflow, Knowledge Base ...)

## Plugin System (Sprint 4a)

Plugins live under `plugins/<name>/` and provide optional, user-installable extensions to zachflow. Distinct from workflows:

- **Workflows** (sprint, qa-fix) are core — auto-installed via `scripts/install-workflows.sh`, project-bundled
- **Plugins** (recall, future: notion-sync, slack-notify) are optional — user-installed via `bash scripts/install-plugins.sh <name>`, system-wide via `~/.claude/skills/`

v1.0 ships `plugins/recall/` as the reference plugin (`recall:ask` skill — interactive sprint/KB recall). See [`docs/plugin-authoring.md`](docs/plugin-authoring.md) for the 10-step checklist to author a new plugin.

The plugin-core boundary is one-way: plugins MAY depend on core (workflows/_shared/, schemas/, KB), core MUST NOT depend on plugins.

## Gallery Package (Sprint 4b)

`packages/zachflow-gallery/` is an Astro-based shell that auto-indexes `runs/sprint/<run-id>/prototypes/**/*.html` from a zachflow project. Build-time discovery via Astro's `getStaticPaths` — no runtime indexing.

Live at `packages/*` monorepo workspace. Run via:

```bash
cd packages/zachflow-gallery
npm install
npm run dev      # Astro dev server
npm run build    # static site to dist/
```

Gallery is **shell only** — design system content (foundations, components, exemplars) stays in user projects. v1.0 ships an empty content layer; users layer their own design.

Optional GitHub Pages deployment via `.github/workflows/gallery.yml.example` (rename to enable). Other hosts (Vercel, Netlify, Cloudflare Pages) work via native Astro integrations.

## LLM Platform Coupling (Section 9)

(... existing Sprint 0 section unchanged ...)
```

### 8. `MANUAL.md` v1.0 Polish

Sprint 3 가 Setup section 정식화. Sprint 4c 가 plugin install + gallery sections 추가:

```markdown
# zachflow Manual

(... existing Setup, Running a Sprint, Running QA-Fix sections from Sprint 0/3 preserved ...)

## Installing Plugins

zachflow ships one reference plugin (`recall`). To install:

```bash
bash scripts/install-plugins.sh recall
```

This symlinks `~/.claude/skills/recall → plugins/recall/`. Restart Claude Code to pick up the new skill.

To list available plugins:

```bash
bash scripts/install-plugins.sh --list
```

After install, invoke the plugin's skill (recall's `ask`) via Claude Code's Skill tool or `/recall:ask`.

To uninstall:

```bash
bash plugins/recall/scripts/uninstall.sh
```

See [`docs/plugin-authoring.md`](docs/plugin-authoring.md) for adding new plugins.

## Running the Gallery

To preview your sprint's prototype outputs locally:

```bash
npm run gallery:dev
# or:
cd packages/zachflow-gallery && npm install && npm run dev
```

Open http://localhost:4321. The gallery scans `runs/sprint/<run-id>/prototypes/**/*.html`.

To build a static site for deployment:

```bash
npm run gallery:build
```

Output: `packages/zachflow-gallery/dist/`. Deploy to GitHub Pages (rename `.github/workflows/gallery.yml.example` to `gallery.yml`), Vercel, Netlify, or any static host.

See [`packages/zachflow-gallery/README.md`](packages/zachflow-gallery/README.md) for customization.
```

### 9. `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract changelog section
        id: changelog
        run: |
          tag="${GITHUB_REF#refs/tags/}"
          version="${tag#v}"
          # Extract section from CHANGELOG.md between "## [<version>]" and the next "## ["
          awk -v v="\\[$version" '
            $0 ~ "^## " v { found=1; next }
            found && /^## \[/ { exit }
            found { print }
          ' CHANGELOG.md > /tmp/release_notes.md
          echo "tag=$tag" >> $GITHUB_OUTPUT

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.changelog.outputs.tag }}
          name: zachflow ${{ steps.changelog.outputs.tag }}
          body_path: /tmp/release_notes.md
          draft: false
          prerelease: false
```

(tag push 시 trigger. CHANGELOG 의 해당 섹션을 release notes 로 사용. 사용자가 자동 release 받음.)

### 10. CHANGELOG `[1.0.0]` final entry

```markdown
## [1.0.0] — 2026-04-29 🎉

**zachflow v1.0.0 — initial release.**

This is the first stable release of zachflow, a harness-driven sprint orchestration tool for AI coding agents on Claude Code Agent Teams. Built from `zzem-orchestrator` reference patterns, sanitized to be project-agnostic and OSS-portable.

### Highlights (v1.0)

- **Two first-class workflows**: `/sprint` (6-phase pipeline) and `/qa-fix` (5-stage Jira-driven pipeline)
- **Build Loop primitive** (Contract → Implement → Evaluate → Fix) shared across workflows
- **Embedded Knowledge Base** (`zachflow-kb:*` skills, 6 skills, JSON Schema validation) — no external repo required
- **Stack-agnostic teammate templates** — placeholder-based BE/FE/Design/Evaluator role guides
- **Interactive init wizard** (`scripts/init-project.sh`) — 7-step prompt-driven project setup, ~5 minutes
- **Plugin system** with `recall:ask` reference plugin (interactive sprint/KB recall, 15 unit tests)
- **Auto-indexed gallery** (`packages/zachflow-gallery/`) — Astro shell, GitHub Pages deployment template
- **`npx create-zachflow`** wrapper — clone-and-strip bootstrap, 0 deps
- **Worktree-isolated runs**, **Active Evaluation** (independent Evaluator agent), **Cross-session knowledge accumulation**
- **bash 3.2+ compatibility** verified (macOS default `/bin/bash`)
- **CI smoke tests**: KB schemas, init-project non-interactive smoke, plugin unit tests, ZZEM-leak scan

### Sprint Build History

v1.0 was built across 7 sprints (5 logical, 4 with sub-splits):

- `v0.1.0-bootstrap` — Sprint 0: directory structure + sanitized core
- `v0.2.0-sprint-1` — Sprint 1: KB embedded mode + skill rename
- `v0.3.0-sprint-2` — Sprint 2: workflow split (`workflows/{sprint,qa-fix,_shared}/`)
- `v0.4.0-sprint-3` — Sprint 3: stack adapter + init-project.sh wizard
- `v0.5.0-sprint-4a-plugins` — Sprint 4a: plugin pattern + recall plugin port
- `v0.6.0-sprint-4b-gallery` — Sprint 4b: zachflow-gallery package
- **`v1.0.0`** — Sprint 4c: create-zachflow + docs polish + release CI 🎉

### Roadmap

See [`docs/roadmap.md`](docs/roadmap.md) for v1.x and v2.0+ plans:

- v1.x: KB remote mode, multi-LLM platform support, additional plugins (Notion sync etc.), npm publish, qa-fix gallery rendering, theme toggle
- v2.0: Workflow yaml DSL, plugin lifecycle hooks, plugin sandboxing
```

### 11. `docs/roadmap.md` 갱신

```markdown
# Roadmap

## v1.0 ✓ shipped 2026-04-29

- [x] Sprint 0 — Bootstrap: clean repo + sanitized core
- [x] Sprint 1 — KB embedded mode + skill rename
- [x] Sprint 2 — Workflow split: `workflows/{sprint,qa-fix,_shared}/` + `/qa-fix` first-class
- [x] Sprint 3 — Stack adapter: placeholder templates + `init-project.sh` wizard
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [x] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release

(... v1.x and v2.0 sections preserved ...)
```

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| `create-zachflow` 의 hardcoded repo URL 이 외부 사용자 OOTB 작동 안 함 | env var + flag 둘 다 override 가능. README 에 명시. v1.x 에서 npm publish 시 npm registry 가 default URL 보유. |
| Strip list 가 새 sprint 추가 시 update 필요 | CONTRIBUTING.md 에 "새 sprint 후 STRIP_LIST 검토" 명시. CI smoke (v1.x) 에서 strip 결과 검증 옵션. |
| `release.yml` 이 CHANGELOG 형식 변경 시 broken | awk pattern 이 `## [<version>]` 형식 가정. CHANGELOG 형식 변경 시 release.yml 도 같이 업데이트. CONTRIBUTING.md 에 명시. |
| `git clone --depth 1 --branch v1.0.0` 가 첫 시도에 작동 안 할 수 있음 | tag 가 push 후 실제 GitHub 에 visible 되어야 함. 사용자가 v1.0.0 tag 사용 시 GitHub 에 push 필수. README 에 default `main` clone + 안정성 위해 tag 사용 권장 |
| README 의 architecture diagram 이 ASCII 라 mobile 에서 깨짐 | code block 안에 두면 horizontal scroll 가능. v1.x 에서 SVG diagram 검토 |
| ARCHITECTURE.md / MANUAL.md polish 가 기존 콘텐츠 깨뜨림 | append-only 방식 — 기존 sections 유지, 새 sections 추가만. diff 가 명확. |
| v1.0.0 tag 가 prematurely 만들어지면 hot-fix 어려움 | Sprint 4c 의 final smoke 에서 모든 quality gate 검증 후 tag. 문제 발견 시 v1.0.1 patch release |

## Success Criteria

Sprint 4c (v1.0 final) ship 시점:

- [ ] `packages/create-zachflow/index.js` 0-deps Node.js 작동 + `--help` 동작
- [ ] `packages/create-zachflow/package.json` valid + bin entry
- [ ] `packages/create-zachflow/README.md` ~50 lines
- [ ] `node packages/create-zachflow/index.js test-target --repo=<local zachflow path>` 시나리오 manual smoke (clone-and-strip 작동 검증)
- [ ] root `README.md` v1.0 polished (badges + quickstart + features + architecture)
- [ ] `CONTRIBUTING.md` v1.0 polished (issue/PR + standards + license)
- [ ] `ARCHITECTURE.md` v1.0 polished (plugins + gallery sections 추가)
- [ ] `MANUAL.md` v1.0 polished (plugin install + gallery sections 추가)
- [ ] `.github/workflows/release.yml` 작성 + valid YAML + tag push trigger 정의
- [ ] CHANGELOG `[1.0.0]` final entry 추가 (release date + highlights + sprint history + roadmap link)
- [ ] `docs/roadmap.md` Sprint 4c checked + v1.0 banner ("✓ shipped 2026-04-29")
- [ ] root `package.json` 변경 없음 (workspaces 이미 Sprint 4b 에서 설정)
- [ ] **Tag `v1.0.0`** 🎉
- [ ] No ZZEM-leak in `packages/create-zachflow/`
- [ ] All bash scripts syntax OK (no new scripts in this sprint, but regression check)
- [ ] All existing CI smokes still pass (KB, init-project, recall, gallery script syntax)
- [ ] Working tree clean

## Out of Scope (v1.x+)

- npm publish (registry publishing automation) — v1.x
- Tarball release artifact — v1.x (master spec section 6 옵션 C)
- Separate `zachflow-template` repo — v1.x 옵션
- Code of Conduct — v1.x community establishment
- GitHub issue/PR templates (`.github/ISSUE_TEMPLATE/*.md`) — v1.x
- Multi-platform CI matrix (Windows native, Alpine, etc.) — v2.0
- Automated changelog generation — v1.x
- Semantic-release / version bump automation — v1.x
- Pre-release channels (alpha/beta/rc) — v1.x
- npm publish workflow with secrets — v1.x
- Documentation site (Docusaurus, Astro Starlight 등) — v1.x
- Telemetry / opt-in usage analytics — v2.0
- Multi-language docs (Korean, Japanese 등) — v2.0
