# Sprint 4b — zachflow-gallery Package Design

> Status: design (브레인스토밍 합의 완료, 구현 plan 미작성)
> Predecessor: zachflow OSS master spec Section 5 (Sprint Gallery — 별도 optional 패키지)
> Sprint context: Sprint 4 의 3-way split 중 두 번째. `v0.5.0-sprint-4a-plugins` 직후. Sprint 4c (`create-zachflow` + v1.0 release) 가 후속.

## Problem

zachflow `v0.5.0-sprint-4a-plugins` 까지의 상태에서 갤러리 시스템이 **master spec 에서 약속됐지만 실체 없음**:

- Sprint phase skills (Sprint 0/2 sanitized) 에 prototype 생성 pipeline 이 있지만, 결과물을 시각화할 도구 없음
- master spec Section 5 가 "별도 optional 패키지 (`zachflow-gallery`)" + "Astro 사이트 코드 + 빈 콘텐츠 슬롯" + "auto-index `runs/sprint/**/prototypes/`" 약속
- v1.0 ship gate 의 "ships with one reference plugin (`recall:ask`)" 가 충족됐지만, 갤러리는 미충족 — 외부 사용자가 zachflow 의 prototype-driven 워크플로우 산출물을 시각적으로 보지 못함
- `docs/roadmap.md` 의 Sprint 4b 가 "`zachflow-gallery` package" 약속

상류 `zzem-orchestrator` 의 `sprint-gallery/` 가 substantial (30+ files, Astro + 11 scripts + tests) 하지만 대부분 ZZEM-specific (design system tokens, exemplars, dogfood verification, 7 archetype taxonomy 등). 전부 port 는 master spec out-of-scope.

## Solution

Astro 기반 minimum viable shell 을 `packages/zachflow-gallery/` 에 신설. 사용자 프로젝트의 `runs/sprint/<id>/prototypes/*.html` 을 자동 index + render 만 — 다른 ZZEM-specific 기능 (token validation, exemplar management, archetype taxonomy) 일체 포함하지 않음. 사용자가 자기 design system 으로 확장 가능하도록 component slot 만 제공.

검증 가능한 ship gate (Sprint 4b):

1. `packages/zachflow-gallery/` 에 ~10 files (Astro app + components + pages + 1 script)
2. `cd packages/zachflow-gallery && npm install && npm run dev` 작동 (Astro dev server 시작)
3. Sample 시나리오: `runs/sprint/example/prototypes/screen-001.html` 가 있으면 home 페이지가 자동 index, detail 페이지가 iframe 으로 render
4. `npm run build` 작동 (정적 빌드, dist/ 출력)
5. `package.json workspaces` 에 추가, root `npm install` 시 zachflow-gallery 도 link
6. `.github/workflows/gallery.yml.example` 사용자가 GH Pages 배포 시 활용 가능한 template
7. `docs/roadmap.md` Sprint 4b checkbox checked
8. ZZEM 콘텐츠 0 (exemplars, foundations, design tokens 등 일체 미포함)

### Strategic Choices (브레인스토밍 합의)

| 항목 | 선택 | 사유 |
|------|------|-----|
| Port scope | **B (minimum viable shell)** — Astro app skeleton + auto-index home + prototype detail page | master spec 정신: "Astro + 빈 콘텐츠 슬롯". ZZEM-specific scripts (token validation, exemplar mgmt, dogfood) 미port |
| Source from upstream | **Mostly write from scratch + small references** | sprint-gallery 의 components 가 ZZEM-styled. 처음부터 minimal 작성이 sanitization 보다 빠름 |
| Package manager | **npm** | 사용자 친숙, OSS 표준 |
| Monorepo workspace | **root `package.json` workspaces** (`packages/*`) | Sprint 4c 의 create-zachflow 도 같은 monorepo |
| `copy-prototypes` 언어 | **bash** (`scripts/copy-prototypes.sh`) | TypeScript 대비 dependency 0, 다른 zachflow scripts 와 일관 |
| Sample prototype HTML | **`.gitkeep` 만** + README 안내 | 가짜 sample 은 confusing. 사용자의 진짜 sprint 결과물이 첫 콘텐츠 |
| GH Pages workflow | **template provided as `.example`** (사용자 opt-in rename) | 사용자 자유 — Vercel/Netlify 등 다른 호스팅 가능 |
| Main CI 통합 | **No (v1.0 제외)** | gallery 빌드는 npm install 필요 (heavy). v1.x 에서 별도 CI matrix |
| Sprint 4b tag | `v0.6.0-sprint-4b-gallery` | 3-way split 의 점진적 milestone |

## Scope

### v1.0 (Sprint 4b) 포함

- 신규 디렉토리: `packages/`, `packages/zachflow-gallery/`, 그 하위 구조
- ~10 files in `packages/zachflow-gallery/` (full list in §1)
- root `package.json` 신설 (workspaces 정의) — 또는 기존 root package.json 에 workspaces 추가
- `.github/workflows/gallery.yml.example` (사용자 opt-in GH Pages template)
- `docs/roadmap.md` Sprint 4b checkbox checked
- `CHANGELOG.md` `[0.6.0-sprint-4b-gallery]` entry
- Tag `v0.6.0-sprint-4b-gallery`

### v1.0 (Sprint 4b) 제외 → Sprint 4c 또는 v1.x

- `npx zachflow-gallery init` (gallery scaffold into existing project) — Sprint 4c (create-zachflow 패턴과 같이)
- Token validation / sync system → 사용자 design system 책임 (v1.x community)
- Exemplar management — ZZEM 개념, v1.x 도입 검토
- Archetype taxonomy — ZZEM design system specific
- Screenshot capture / visual baseline / dogfood verification — heavy deps (playwright)
- Search palette / filters / clusters / explore pages — feature-rich UI, v1.x
- Theme toggle (dark mode) — v1.x community contribution
- Mobile story stack — v1.x
- Tests (vitest + playwright) — gallery 자체 CI matrix 가 없으므로 v1.x

### 변경하지 않는 파일

- Sprint 0/1/2/3/4a 산출물 (commits up through `v0.5.0-sprint-4a-plugins`): 그대로
- workflows/, plugins/recall/, scripts/, docs/* (gallery 와 무관)
- KB skills, schemas, init-project.sh, install-workflows.sh, install-plugins.sh
- CHANGELOG.md (Sprint 4b entry 추가만)
- roadmap.md (Sprint 4b checkbox 갱신만)

## Detailed Design

### 1. 디렉토리 레이아웃 (Sprint 4b 산출물)

```
~/dev/personal/zachflow/
├── package.json                          # MODIFIED or NEW (root, workspaces)
├── packages/                             # NEW
│   └── zachflow-gallery/                 # NEW
│       ├── package.json                  # Astro app deps
│       ├── astro.config.mjs              # Astro build config
│       ├── tsconfig.json                 # TS config (Astro strict)
│       ├── .gitignore                    # node_modules, dist
│       ├── README.md                     # user-facing onboarding (~80 lines)
│       ├── public/
│       │   └── favicon.svg               # zachflow neutral favicon
│       ├── src/
│       │   ├── components/
│       │   │   ├── Layout.astro          # base layout (~50 lines)
│       │   │   └── PrototypeCard.astro   # prototype thumbnail card (~40 lines)
│       │   └── pages/
│       │       ├── index.astro           # home — auto-index runs (~80 lines)
│       │       └── [run]/[prototype].astro  # detail page (~50 lines)
│       └── scripts/
│           └── copy-prototypes.sh        # build-time: runs/sprint/**/*.html → dist/ (~60 lines bash)
│
├── runs/
│   └── sprint/
│       └── .gitkeep                       # (Sprint 2's gitkeep, no example added)
│
├── .github/workflows/
│   ├── ci.yml                             # (existing, unchanged)
│   └── gallery.yml.example                # NEW (GH Pages template, 사용자 opt-in)
│
├── docs/roadmap.md                        # MODIFIED (Sprint 4b checkbox)
└── CHANGELOG.md                           # MODIFIED ([0.6.0-sprint-4b-gallery])
```

Total NEW files: 11 (root package.json possibly modify or new) + 1 GH Pages template + 2 doc updates.

### 2. Root `package.json` (workspaces 정의)

zachflow Sprint 0 가 이미 root `package.json` 작성했음 (스타텁 stub). Sprint 4b 가 `workspaces` 필드 추가. 기존 형식:

```json
{
  "name": "zachflow",
  "version": "0.1.0",
  "description": "Harness-driven sprint orchestration for AI coding agents.",
  "license": "MIT",
  "private": true,
  "engines": { "node": ">=18" },
  "keywords": ["agentic","claude-code","ai-coding","sprint","harness"]
}
```

Sprint 4b 추가:

```json
{
  "name": "zachflow",
  "version": "0.1.0",
  ...
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "gallery:dev": "npm run dev --workspace=packages/zachflow-gallery",
    "gallery:build": "npm run build --workspace=packages/zachflow-gallery"
  }
}
```

(version bumps to `0.6.0-sprint-4b-gallery` 시점은 release tag 단계 — Sprint 4c v1.0 에서 `1.0.0` 으로 jump.)

### 3. `packages/zachflow-gallery/package.json`

```json
{
  "name": "zachflow-gallery",
  "version": "0.1.0",
  "type": "module",
  "private": true,
  "description": "Auto-indexed gallery for zachflow sprint prototype outputs (Astro shell).",
  "license": "MIT",
  "scripts": {
    "dev": "astro dev",
    "build": "bash scripts/copy-prototypes.sh && astro build",
    "preview": "astro preview"
  },
  "dependencies": {
    "astro": "^4.16.0"
  },
  "engines": { "node": ">=18" }
}
```

Minimal deps — 단일 astro. React/MDX/etc 미포함 (v1.x 사용자 확장).

### 4. `astro.config.mjs`

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  // No site URL — user sets when deploying.
  // Output: static (default).
  // Auto-discovers src/pages/.
});
```

Minimal. 사용자가 GH Pages / Vercel / Netlify 배포 시 site URL 추가.

### 5. `tsconfig.json`

```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"]
}
```

Astro strict 권장 설정.

### 6. `src/components/Layout.astro` (~50 lines)

```astro
---
interface Props {
  title?: string;
}
const { title = 'zachflow gallery' } = Astro.props;
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <title>{title}</title>
    <style is:global>
      :root {
        --bg: #0a0a0f;
        --fg: #e8e8ea;
        --muted: #8a8a92;
        --accent: #6366f1;
        --card-bg: #14141c;
        --card-border: #24242c;
        --radius: 8px;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: system-ui, -apple-system, sans-serif;
        background: var(--bg);
        color: var(--fg);
        line-height: 1.5;
      }
      a { color: var(--accent); text-decoration: none; }
      a:hover { text-decoration: underline; }
      header {
        padding: 1rem 2rem;
        border-bottom: 1px solid var(--card-border);
      }
      main { padding: 2rem; max-width: 1200px; margin: 0 auto; }
      h1 { margin: 0 0 1rem; font-size: 1.5rem; font-weight: 600; }
    </style>
  </head>
  <body>
    <header>
      <strong>zachflow gallery</strong>
    </header>
    <main>
      <slot />
    </main>
  </body>
</html>
```

기본 dark theme. 사용자가 자기 design system 으로 override 가능 (style is:global 만 minimal 시작).

### 7. `src/components/PrototypeCard.astro` (~40 lines)

```astro
---
interface Props {
  run: string;
  prototype: string;
  title?: string;
}
const { run, prototype, title } = Astro.props;
const href = `/${run}/${prototype}/`;
---

<a href={href} class="card">
  <div class="thumb">
    <iframe src={`/prototypes/${run}/${prototype}.html`} sandbox="allow-same-origin" loading="lazy" />
  </div>
  <div class="meta">
    <strong>{title ?? prototype}</strong>
    <span class="run">{run}</span>
  </div>
</a>

<style>
  .card {
    display: block;
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: var(--radius);
    overflow: hidden;
    transition: transform 0.15s ease;
  }
  .card:hover { transform: translateY(-2px); }
  .thumb {
    height: 240px;
    overflow: hidden;
    pointer-events: none;
    position: relative;
  }
  .thumb iframe {
    width: 100%;
    height: 100%;
    border: 0;
    transform: scale(0.5);
    transform-origin: top left;
    width: 200%;
    height: 200%;
  }
  .meta {
    padding: 0.75rem 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .run {
    font-size: 0.85rem;
    color: var(--muted);
  }
</style>
```

iframe-based thumbnail (zoom out 50% 해서 card 안에 fit). 사용자가 `<style>` 변경 가능.

### 8. `src/pages/index.astro` (~80 lines)

```astro
---
import Layout from '../components/Layout.astro';
import PrototypeCard from '../components/PrototypeCard.astro';
import fs from 'node:fs';
import path from 'node:path';

// Discover prototypes from ../runs/sprint/<run-id>/prototypes/*.html
// (relative to this Astro app at packages/zachflow-gallery/)
const projectRoot = path.resolve('../..');
const runsDir = path.join(projectRoot, 'runs', 'sprint');

let prototypes: { run: string; prototype: string }[] = [];

if (fs.existsSync(runsDir)) {
  const runs = fs.readdirSync(runsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);

  for (const run of runs) {
    const protoDir = path.join(runsDir, run, 'prototypes');
    if (!fs.existsSync(protoDir)) continue;

    const walk = (dir: string, prefix = '') => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
        if (entry.isDirectory()) {
          walk(full, rel);
        } else if (entry.name.endsWith('.html')) {
          const proto = rel.replace(/\.html$/, '');
          prototypes.push({ run, prototype: proto });
        }
      }
    };
    walk(protoDir);
  }
}
---

<Layout title="zachflow gallery">
  <h1>Prototypes</h1>
  {prototypes.length === 0 ? (
    <p>
      No prototypes found in <code>runs/sprint/*/prototypes/*.html</code>.
      Once your sprint produces prototype HTML files, they'll appear here.
    </p>
  ) : (
    <div class="grid">
      {prototypes.map(({ run, prototype }) => (
        <PrototypeCard run={run} prototype={prototype} />
      ))}
    </div>
  )}
</Layout>

<style>
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1.5rem;
  }
</style>
```

Build-time discovery (Astro SSG). 결과: 사용자가 `npm run build` 시 모든 prototype index 한 정적 사이트.

### 9. `src/pages/[run]/[prototype].astro` (~50 lines, dynamic route)

```astro
---
import Layout from '../../components/Layout.astro';
import fs from 'node:fs';
import path from 'node:path';

export function getStaticPaths() {
  const projectRoot = path.resolve('../..');
  const runsDir = path.join(projectRoot, 'runs', 'sprint');
  const paths: any[] = [];

  if (fs.existsSync(runsDir)) {
    const runs = fs.readdirSync(runsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);

    for (const run of runs) {
      const protoDir = path.join(runsDir, run, 'prototypes');
      if (!fs.existsSync(protoDir)) continue;

      const walk = (dir: string, prefix = '') => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const full = path.join(dir, entry.name);
          const rel = prefix ? `${prefix}/${entry.name}` : entry.name;
          if (entry.isDirectory()) walk(full, rel);
          else if (entry.name.endsWith('.html')) {
            const proto = rel.replace(/\.html$/, '');
            paths.push({ params: { run, prototype: proto } });
          }
        }
      };
      walk(protoDir);
    }
  }
  return paths;
}

const { run, prototype } = Astro.params;
---

<Layout title={`${prototype} — ${run}`}>
  <h1>{prototype}</h1>
  <p><a href="/">← Back to gallery</a> · <small>{run}</small></p>
  <iframe src={`/prototypes/${run}/${prototype}.html`} class="full" />
</Layout>

<style>
  .full {
    width: 100%;
    height: 80vh;
    border: 1px solid var(--card-border);
    border-radius: var(--radius);
  }
</style>
```

Astro 의 `getStaticPaths` 로 모든 prototype 에 대해 static page 생성. 사용자가 `runs/sprint/<id>/prototypes/<file>.html` 추가하면 다음 build 에 자동 반영.

### 10. `scripts/copy-prototypes.sh` (~60 lines)

build 전에 실행. `runs/sprint/**/prototypes/*.html` 을 `public/prototypes/<run>/<prototype>.html` 로 copy 해서 Astro 가 정적 자산으로 처리하게 함.

```bash
#!/usr/bin/env bash
# copy-prototypes.sh — copy runs/sprint/**/prototypes/*.html into Astro public/.
# Runs as part of `npm run build` (gallery package).

set -euo pipefail

GALLERY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$GALLERY_ROOT/../.." && pwd)"

RUNS_DIR="$PROJECT_ROOT/runs/sprint"
DEST_DIR="$GALLERY_ROOT/public/prototypes"

# Clean dest
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

if [ ! -d "$RUNS_DIR" ]; then
  echo "No runs/sprint/ directory at $RUNS_DIR; nothing to copy."
  exit 0
fi

count=0
for run_dir in "$RUNS_DIR"/*/; do
  [ -d "$run_dir" ] || continue
  run_name=$(basename "$run_dir")
  proto_dir="${run_dir}prototypes"
  [ -d "$proto_dir" ] || continue

  while IFS= read -r -d '' html_file; do
    rel_path="${html_file#$proto_dir/}"
    dest="$DEST_DIR/$run_name/$rel_path"
    mkdir -p "$(dirname "$dest")"
    cp "$html_file" "$dest"
    count=$((count + 1))
  done < <(find "$proto_dir" -type f -name '*.html' -print0)
done

echo "Copied $count prototype file(s) to $DEST_DIR."
```

### 11. `.gitignore` (gallery package)

```
node_modules/
dist/
public/prototypes/    # generated by copy-prototypes.sh
.astro/
```

### 12. `README.md` (gallery package, ~80 lines)

```markdown
# zachflow-gallery

Auto-indexed Astro shell for zachflow sprint prototype outputs.

## Quick start

```bash
cd packages/zachflow-gallery
npm install
npm run dev
```

Open http://localhost:4321 to see your prototypes.

## What it does

The gallery scans `runs/sprint/<run-id>/prototypes/**/*.html` from your zachflow project root and renders:

- **Home page** (`/`) — grid of all prototype cards
- **Detail page** (`/<run>/<prototype>/`) — full-size iframe view of each prototype

## Build for production

```bash
npm run build      # outputs static site to dist/
npm run preview    # preview the build locally
```

The build runs `scripts/copy-prototypes.sh` first to copy prototype HTML into `public/prototypes/`, then `astro build`.

## Deploy to GitHub Pages (optional)

`zachflow` ships a workflow template at `.github/workflows/gallery.yml.example`. To enable:

1. Rename to `.github/workflows/gallery.yml`
2. Set the `site` field in `astro.config.mjs` to your GitHub Pages URL
3. Commit + push — the workflow builds + deploys on each push to `main`

Other platforms (Vercel, Netlify, Cloudflare Pages): use their native Astro integrations. Set the build command to `npm run build --workspace=packages/zachflow-gallery` and output to `packages/zachflow-gallery/dist/`.

## Customization

The gallery is intentionally minimal. To extend:

- **Theme**: edit `src/components/Layout.astro` style block
- **Card style**: edit `src/components/PrototypeCard.astro`
- **Add filters / search / archetypes**: extend `src/pages/index.astro` or add new page components
- **Per-run metadata**: parse your `sprint-config.yaml` or run-level docs in the page's frontmatter

The shell stays out of design opinions so you can layer your project's identity without fighting framework defaults.

## Limitations (v1.0)

- No qa-fix run rendering (only `runs/sprint/`). v1.x will add `runs/qa-fix/<id>/` browsing.
- No screenshot capture / visual baseline / test integration.
- No exemplar/archetype taxonomy.
- No theme toggle / mobile-optimized navigation.

These are intentional v1.0 boundaries — the shell is meant to be extended, not all-in-one.
```

### 13. `public/favicon.svg`

zachflow-neutral SVG. 32x32 dark accent square with subtle "z" or simple geometric mark. Sprint 4b 산출 — minimal placeholder.

### 14. `.github/workflows/gallery.yml.example`

```yaml
# .github/workflows/gallery.yml.example
# Optional: deploy zachflow-gallery to GitHub Pages.
# To enable, rename to gallery.yml and adjust site URL in
# packages/zachflow-gallery/astro.config.mjs.

name: Deploy gallery to GitHub Pages

on:
  push:
    branches: [main]
    paths:
      - 'runs/sprint/**'
      - 'packages/zachflow-gallery/**'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm install
      - run: npm run build --workspace=packages/zachflow-gallery
      - uses: actions/upload-pages-artifact@v3
        with: { path: packages/zachflow-gallery/dist }

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

(사용자가 enable 할 때 `gallery.yml` 으로 rename + site URL 설정.)

### 15. `docs/roadmap.md` 업데이트

Sprint 4b 의 [ ] 를 [x] 로 변경. (Sprint 4a 가 이미 split 한 상태에서 4b 만 check.)

```markdown
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [ ] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release
```

## Risks & Mitigations

| 리스크 | 완화 |
|--------|------|
| Astro 의존성이 root `npm install` 시 커짐 (~100MB+ node_modules) | gallery 가 optional. 사용자가 root install 안 하면 영향 없음. workspace 설정으로 isolated. |
| 사용자가 `runs/sprint/<id>/prototypes/` 에 prototype 없을 때 home 페이지가 빈 상태 | empty state UI 명시 ("No prototypes found in...") + README 안내. |
| Iframe sandbox 가 일부 prototype 렌더링 깨뜨림 | `sandbox="allow-same-origin"` 만 — script 차단. prototype 의 inline JS 동작 안 할 수 있음. README 에 명시 + 사용자가 `Layout.astro` 수정 가능. |
| `getStaticPaths` 가 build 시 많은 prototype 가 있을 때 느림 | 일반적 sprint 당 수십 prototype — Astro SSG 처리 가능 범위. 1000+ 면 v1.x optimization 검토. |
| `npm run build` 가 `npm install` 안 하면 `astro` not found | README 의 `cd packages/zachflow-gallery && npm install` 명시. 첫 사용 friction 있음 — Sprint 4c 의 `create-zachflow` 가 자동화. |
| GH Pages workflow 의 path filter 가 prototype 추가 시 build trigger 안 함 | workflow 의 `paths:` 가 `runs/sprint/**` + `packages/zachflow-gallery/**` 둘 다 포함 — runs 변경 시도 빌드. |
| 사용자가 다른 host (Vercel) 로 배포 시 호환성 | astro build output 표준 — 어떤 정적 호스팅도 작동. README 에 Vercel/Netlify 안내. |
| zachflow main CI 에 gallery 빌드 추가 안 함 | 의도적 (v1.x). gallery package 는 별도 lifecycle. |

## Success Criteria

Sprint 4b ship 시점:

- [ ] `packages/zachflow-gallery/` 디렉토리에 11+ files
- [ ] `package.json`, `astro.config.mjs`, `tsconfig.json`, `.gitignore`, `README.md` 모두 존재
- [ ] `src/components/{Layout,PrototypeCard}.astro` 존재
- [ ] `src/pages/index.astro` + `src/pages/[run]/[prototype].astro` 존재
- [ ] `scripts/copy-prototypes.sh` 존재 + 실행 가능 + bash syntax OK
- [ ] root `package.json` 에 `workspaces: ["packages/*"]` 추가됨
- [ ] root `package.json` 에 `gallery:dev` + `gallery:build` 스크립트 추가됨
- [ ] `cd packages/zachflow-gallery && npm install` 작동 (CI 외 manual smoke)
- [ ] `npm run dev --workspace=packages/zachflow-gallery` Astro dev server 시작
- [ ] `npm run build --workspace=packages/zachflow-gallery` 정적 빌드 성공
- [ ] empty `runs/sprint/` 상태에서 home 이 "No prototypes found" 메시지 표시
- [ ] `.github/workflows/gallery.yml.example` 존재 + valid YAML
- [ ] `public/favicon.svg` 존재
- [ ] `docs/roadmap.md` Sprint 4b checked
- [ ] CHANGELOG.md `[0.6.0-sprint-4b-gallery]` entry
- [ ] Tag `v0.6.0-sprint-4b-gallery`
- [ ] No ZZEM-leak in `packages/zachflow-gallery/`
- [ ] No Korean residue in `packages/zachflow-gallery/`
- [ ] Working tree clean

## Out of Scope (Sprint 4c, v1.x+)

- `npx zachflow-gallery init` (gallery scaffold into existing project) — Sprint 4c 의 create-zachflow 패턴
- Token validation / sync — 사용자 design system 책임 (v1.x community)
- Exemplar management — v1.x feature
- Archetype taxonomy — v1.x design system extension
- Screenshot capture / visual baseline — v1.x (heavy playwright dep)
- Search palette / clusters / explore pages — v1.x
- Theme toggle (dark/light mode) — v1.x community
- Mobile story stack / mobile-optimized navigation — v1.x
- qa-fix run rendering — v1.x (`runs/qa-fix/<id>/` browsing)
- Tests (vitest + playwright) — v1.x dedicated CI matrix
- Per-prototype rich metadata (PRD link, screen-spec, etc.) — v1.x
- Prototype diff viewer / version comparison — v1.x+
- Performance optimizations (lazy loading, virtual scroll) — v1.x at scale
- Accessibility audit / a11y enhancements — v1.x
- i18n (multi-language gallery UI) — v2.0
