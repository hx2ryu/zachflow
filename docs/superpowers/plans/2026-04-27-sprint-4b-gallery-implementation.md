# Sprint 4b — zachflow-gallery Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `packages/zachflow-gallery/` Astro shell that auto-indexes `runs/sprint/<id>/prototypes/*.html` from a zachflow project, ship as monorepo workspace, no ZZEM content, ~10 files.

**Architecture:** Astro static-site generator with build-time discovery — `getStaticPaths` scans `runs/sprint/<id>/prototypes/**/*.html` and produces a home page + per-prototype detail page. Dark-themed minimal Layout. iframe-based prototype rendering. Build pipeline: `bash scripts/copy-prototypes.sh` (copies HTML to `public/prototypes/`) → `astro build`. Root `package.json` declares `workspaces: ["packages/*"]` so `npm install` from project root links the gallery. GH Pages workflow shipped as `.example` template (user opt-in).

**Tech Stack:** Astro 4.x (static-site, no React/MDX in v1.0), Node.js 18+, npm workspaces, bash 3.2+ (copy-prototypes), TypeScript (Astro strict tsconfig — files are .astro, no separate .ts to maintain).

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-4b-gallery-design.md` (commit `5e79fbc`). Read sections 1 (directory layout), 2-3 (package.json's), 4 (astro config), 6-7 (components), 8-9 (pages), 10 (copy script), 12 (README), 14 (GH Pages template) before starting.

---

## File Structure (Sprint 4b output additions/changes)

```
~/dev/personal/zachflow/
├── package.json                              # MODIFIED (add workspaces + gallery scripts)
├── packages/                                 # NEW
│   └── zachflow-gallery/                     # NEW
│       ├── package.json                      # NEW (Astro + minimal deps)
│       ├── astro.config.mjs                  # NEW
│       ├── tsconfig.json                     # NEW
│       ├── .gitignore                        # NEW
│       ├── README.md                         # NEW (~80 lines)
│       ├── public/
│       │   └── favicon.svg                   # NEW (zachflow-neutral SVG)
│       ├── src/
│       │   ├── components/
│       │   │   ├── Layout.astro              # NEW
│       │   │   └── PrototypeCard.astro       # NEW
│       │   └── pages/
│       │       ├── index.astro               # NEW (auto-index home)
│       │       └── [run]/[prototype].astro   # NEW (dynamic detail)
│       └── scripts/
│           └── copy-prototypes.sh            # NEW (bash, ~60 lines)
│
├── .github/workflows/
│   └── gallery.yml.example                   # NEW (GH Pages template)
│
├── docs/roadmap.md                           # MODIFIED (Sprint 4b checkbox)
└── CHANGELOG.md                              # MODIFIED ([0.6.0-sprint-4b-gallery])
```

Total NEW files: 12 (gallery package) + 1 GH Pages template = 13 new + 3 modified.

---

## Task 1: Skeleton — directories, package.json files, configs

**Files:**
- Modify: `~/dev/personal/zachflow/package.json` (add workspaces)
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/package.json`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/astro.config.mjs`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/tsconfig.json`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/.gitignore`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/public/favicon.svg`

- [ ] **Step 1.1: Create directory tree**

```bash
mkdir -p ~/dev/personal/zachflow/packages/zachflow-gallery/{public,src/components,src/pages,scripts}
mkdir -p ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages
```

(Astro's dynamic route `[run]/[prototype].astro` lives directly in `src/pages/[run]/[prototype].astro` — created by Task 3.)

- [ ] **Step 1.2: Modify root `package.json`**

Read `~/dev/personal/zachflow/package.json`. Current content (Sprint 0 stub):

```json
{
  "name": "zachflow",
  "version": "0.1.0",
  "description": "Harness-driven sprint orchestration for AI coding agents.",
  "license": "MIT",
  "private": true,
  "engines": {
    "node": ">=18"
  },
  "keywords": [
    "agentic",
    "claude-code",
    "ai-coding",
    "sprint",
    "harness"
  ]
}
```

Use Write tool to overwrite with the workspaces-enabled version (preserves all existing fields, adds workspaces + scripts):

```json
{
  "name": "zachflow",
  "version": "0.1.0",
  "description": "Harness-driven sprint orchestration for AI coding agents.",
  "license": "MIT",
  "private": true,
  "engines": {
    "node": ">=18"
  },
  "keywords": [
    "agentic",
    "claude-code",
    "ai-coding",
    "sprint",
    "harness"
  ],
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "gallery:dev": "npm run dev --workspace=packages/zachflow-gallery",
    "gallery:build": "npm run build --workspace=packages/zachflow-gallery",
    "gallery:preview": "npm run preview --workspace=packages/zachflow-gallery"
  }
}
```

- [ ] **Step 1.3: Write `packages/zachflow-gallery/package.json`**

Use Write tool to create with this EXACT content:

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
  "engines": {
    "node": ">=18"
  }
}
```

- [ ] **Step 1.4: Write `astro.config.mjs`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/astro.config.mjs` with this EXACT content:

```js
import { defineConfig } from 'astro/config';

// Minimal Astro config. Set `site` when deploying to a host (GH Pages,
// Vercel, Netlify, etc.) — required for absolute URLs in some adapters.
//
// Example:
//   site: 'https://<user>.github.io/<repo>/',
//
// Output mode: static (default — generates HTML at build time).

export default defineConfig({
  // site: 'https://example.com/',
});
```

- [ ] **Step 1.5: Write `tsconfig.json`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/tsconfig.json` with this EXACT content:

```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"]
}
```

- [ ] **Step 1.6: Write `.gitignore`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/.gitignore` with this EXACT content:

```
# Astro / npm
node_modules/
dist/
.astro/

# Generated by scripts/copy-prototypes.sh during build
public/prototypes/

# Editor
.DS_Store
*.swp
```

- [ ] **Step 1.7: Write `public/favicon.svg`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/public/favicon.svg` with this EXACT content:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
  <rect width="32" height="32" rx="6" fill="#0a0a0f"/>
  <path d="M9 9h14l-9 14h9" stroke="#6366f1" stroke-width="2.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

(Geometric "z" mark in indigo on dark background. Generic — no ZZEM identity.)

- [ ] **Step 1.8: Verify files exist + JSONs valid**

```bash
# Files exist
[ -f ~/dev/personal/zachflow/package.json ] && echo "root package.json"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/package.json ] && echo "gallery package.json"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/astro.config.mjs ] && echo "astro.config.mjs"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/tsconfig.json ] && echo "tsconfig.json"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/.gitignore ] && echo ".gitignore"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/public/favicon.svg ] && echo "favicon.svg"

# JSONs valid
python3 -c "import json; json.load(open('/Users/zachryu/dev/personal/zachflow/package.json'))" && echo "root package.json valid"
python3 -c "import json; json.load(open('/Users/zachryu/dev/personal/zachflow/packages/zachflow-gallery/package.json'))" && echo "gallery package.json valid"
python3 -c "import json; json.load(open('/Users/zachryu/dev/personal/zachflow/packages/zachflow-gallery/tsconfig.json'))" && echo "tsconfig.json valid"

# Workspaces field present
python3 -c "
import json
data = json.load(open('/Users/zachryu/dev/personal/zachflow/package.json'))
assert data['workspaces'] == ['packages/*']
assert 'gallery:dev' in data['scripts']
print('root workspaces OK')
"
```

Expected: 6 file existence + 3 JSON valid + workspaces OK lines.

- [ ] **Step 1.9: Commit**

```bash
cd ~/dev/personal/zachflow
git add package.json packages/zachflow-gallery/
git commit -m "feat(gallery): scaffold packages/zachflow-gallery + add root workspaces"
```

---

## Task 2: Astro components (Layout.astro + PrototypeCard.astro)

**Files:**
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/src/components/Layout.astro`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/src/components/PrototypeCard.astro`

- [ ] **Step 2.1: Write `Layout.astro`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/src/components/Layout.astro` with this EXACT content:

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
    <meta name="viewport" content="width=device-width, initial-scale=1" />
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
      code {
        background: var(--card-bg);
        padding: 0.1em 0.4em;
        border-radius: 3px;
        font-size: 0.9em;
      }
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

- [ ] **Step 2.2: Write `PrototypeCard.astro`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/src/components/PrototypeCard.astro` with this EXACT content:

```astro
---
interface Props {
  run: string;
  prototype: string;
  title?: string;
}
const { run, prototype, title } = Astro.props;
const href = `/${run}/${prototype}/`;
const iframeSrc = `/prototypes/${run}/${prototype}.html`;
---

<a href={href} class="card">
  <div class="thumb">
    <iframe src={iframeSrc} sandbox="allow-same-origin" loading="lazy" tabindex="-1" />
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
    transition: transform 0.15s ease, border-color 0.15s ease;
    color: inherit;
  }
  .card:hover {
    transform: translateY(-2px);
    border-color: var(--accent);
    text-decoration: none;
  }
  .thumb {
    height: 240px;
    overflow: hidden;
    pointer-events: none;
    position: relative;
    background: #050508;
  }
  .thumb iframe {
    border: 0;
    width: 200%;
    height: 200%;
    transform: scale(0.5);
    transform-origin: top left;
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

- [ ] **Step 2.3: Verify components exist**

```bash
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/src/components/Layout.astro ] && echo "Layout.astro"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/src/components/PrototypeCard.astro ] && echo "PrototypeCard.astro"

# Spot-check first lines
head -3 ~/dev/personal/zachflow/packages/zachflow-gallery/src/components/Layout.astro
head -3 ~/dev/personal/zachflow/packages/zachflow-gallery/src/components/PrototypeCard.astro
```

Expected: 2 file confirmations + each starts with `---` (Astro frontmatter).

- [ ] **Step 2.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add packages/zachflow-gallery/src/components/
git commit -m "feat(gallery): add Layout + PrototypeCard Astro components"
```

---

## Task 3: Astro pages (index + dynamic detail route)

**Files:**
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/index.astro`
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/[run]/[prototype].astro`

- [ ] **Step 3.1: Write `src/pages/index.astro`**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/index.astro` with this EXACT content:

```astro
---
import Layout from '../components/Layout.astro';
import PrototypeCard from '../components/PrototypeCard.astro';
import fs from 'node:fs';
import path from 'node:path';

// Discover prototypes from <project-root>/runs/sprint/<run-id>/prototypes/**/*.html
// (this Astro app lives at packages/zachflow-gallery/, so project root is ../..)
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

prototypes.sort((a, b) => {
  if (a.run !== b.run) return a.run.localeCompare(b.run);
  return a.prototype.localeCompare(b.prototype);
});
---

<Layout title="zachflow gallery">
  <h1>Prototypes</h1>
  {prototypes.length === 0 ? (
    <p>
      No prototypes found in <code>runs/sprint/&lt;run-id&gt;/prototypes/*.html</code>.
      Once your sprint produces prototype HTML files, they'll appear here automatically on the next build.
    </p>
  ) : (
    <>
      <p class="count">{prototypes.length} prototype{prototypes.length === 1 ? '' : 's'} across {new Set(prototypes.map((p) => p.run)).size} run{new Set(prototypes.map((p) => p.run)).size === 1 ? '' : 's'}.</p>
      <div class="grid">
        {prototypes.map(({ run, prototype }) => (
          <PrototypeCard run={run} prototype={prototype} />
        ))}
      </div>
    </>
  )}
</Layout>

<style>
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1.5rem;
  }
  .count {
    color: var(--muted);
    margin-bottom: 1.5rem;
  }
</style>
```

- [ ] **Step 3.2: Write `src/pages/[run]/[prototype].astro` (dynamic route)**

First create the `[run]` subdirectory:

```bash
mkdir -p ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/\[run\]
```

Then use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/[run]/[prototype].astro` with this EXACT content:

```astro
---
import Layout from '../../components/Layout.astro';
import fs from 'node:fs';
import path from 'node:path';

export function getStaticPaths() {
  const projectRoot = path.resolve('../..');
  const runsDir = path.join(projectRoot, 'runs', 'sprint');
  const paths: { params: { run: string; prototype: string } }[] = [];

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
const iframeSrc = `/prototypes/${run}/${prototype}.html`;
---

<Layout title={`${prototype} — ${run}`}>
  <p class="back"><a href="/">← Back to gallery</a></p>
  <h1>{prototype}</h1>
  <p class="run-label"><code>{run}</code></p>
  <iframe src={iframeSrc} class="full" sandbox="allow-same-origin" />
</Layout>

<style>
  .back {
    margin-bottom: 1rem;
  }
  .run-label {
    color: var(--muted);
    margin-bottom: 1.5rem;
  }
  .full {
    display: block;
    width: 100%;
    height: 80vh;
    border: 1px solid var(--card-border);
    border-radius: var(--radius);
    background: #050508;
  }
</style>
```

- [ ] **Step 3.3: Verify pages exist**

```bash
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/index.astro ] && echo "index.astro"
[ -f ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/\[run\]/\[prototype\].astro ] && echo "[run]/[prototype].astro"

ls ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/
ls ~/dev/personal/zachflow/packages/zachflow-gallery/src/pages/\[run\]/
```

Expected: 2 file confirmations + listing shows `index.astro` + `[run]/` directory containing `[prototype].astro`.

- [ ] **Step 3.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add packages/zachflow-gallery/src/pages/
git commit -m "feat(gallery): add index + dynamic prototype detail pages with auto-discovery"
```

---

## Task 4: copy-prototypes.sh script

**Files:**
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/scripts/copy-prototypes.sh`

- [ ] **Step 4.1: Write the script**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/scripts/copy-prototypes.sh` with this EXACT content:

```bash
#!/usr/bin/env bash
# copy-prototypes.sh — copy runs/sprint/**/prototypes/*.html into Astro public/.
#
# Runs as part of `npm run build` (gallery package). The destination
# (public/prototypes/) is gitignored — generated each build.

set -euo pipefail

GALLERY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$GALLERY_ROOT/../.." && pwd)"

RUNS_DIR="$PROJECT_ROOT/runs/sprint"
DEST_DIR="$GALLERY_ROOT/public/prototypes"

# Always start clean — stale copies confuse the build.
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

if [ ! -d "$RUNS_DIR" ]; then
  echo "copy-prototypes: no runs/sprint/ directory at $RUNS_DIR; nothing to copy."
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

echo "copy-prototypes: copied $count file(s) to $DEST_DIR."
```

- [ ] **Step 4.2: Make executable + verify syntax**

```bash
chmod +x ~/dev/personal/zachflow/packages/zachflow-gallery/scripts/copy-prototypes.sh
bash -n ~/dev/personal/zachflow/packages/zachflow-gallery/scripts/copy-prototypes.sh && echo "syntax OK"

# bash 3.2 syntax check (macOS default)
[ -x /bin/bash ] && /bin/bash -n ~/dev/personal/zachflow/packages/zachflow-gallery/scripts/copy-prototypes.sh && echo "bash 3.2 syntax OK"
```

Expected: both `OK` lines.

- [ ] **Step 4.3: Run script in empty-runs scenario**

```bash
cd ~/dev/personal/zachflow
bash packages/zachflow-gallery/scripts/copy-prototypes.sh
```

Expected: `copy-prototypes: no runs/sprint/ directory at .../runs/sprint; nothing to copy.` OR `copy-prototypes: copied 0 file(s) to .../public/prototypes.` (if `runs/sprint/` exists but has no prototypes — Sprint 2's `runs/sprint/.gitkeep` makes the directory present).

The script exits 0 in either case.

- [ ] **Step 4.4: Run script with a fixture prototype**

Create a temporary fixture and verify the script copies it:

```bash
cd ~/dev/personal/zachflow

# Setup fixture
mkdir -p runs/sprint/example-run/prototypes
echo '<!doctype html><html><body><h1>Smoke prototype</h1></body></html>' > runs/sprint/example-run/prototypes/smoke.html

# Run script
bash packages/zachflow-gallery/scripts/copy-prototypes.sh

# Verify
[ -f packages/zachflow-gallery/public/prototypes/example-run/smoke.html ] && echo "smoke.html copied"
cat packages/zachflow-gallery/public/prototypes/example-run/smoke.html | head -1

# Cleanup fixture
rm -rf runs/sprint/example-run
rm -rf packages/zachflow-gallery/public/prototypes
```

Expected: `copy-prototypes: copied 1 file(s) ...` + `smoke.html copied` + first line of HTML.

- [ ] **Step 4.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add packages/zachflow-gallery/scripts/
git commit -m "feat(gallery): add copy-prototypes.sh build-time HTML copy script"
```

---

## Task 5: README (gallery package)

**Files:**
- Create: `~/dev/personal/zachflow/packages/zachflow-gallery/README.md`

- [ ] **Step 5.1: Write README.md**

Use Write tool to create `~/dev/personal/zachflow/packages/zachflow-gallery/README.md` with this EXACT content:

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

(From the project root, you can also run `npm run gallery:dev`.)

## What it does

The gallery scans `runs/sprint/<run-id>/prototypes/**/*.html` from your zachflow project root and renders:

- **Home page** (`/`) — grid of all prototype cards
- **Detail page** (`/<run>/<prototype>/`) — full-size iframe view of each prototype

Discovery happens at build time via Astro's `getStaticPaths` — no runtime indexing, no database. Add a prototype HTML file to `runs/sprint/<id>/prototypes/`, rebuild, and it appears.

## Build for production

```bash
npm run build      # outputs static site to dist/
npm run preview    # preview the build locally
```

The build runs `bash scripts/copy-prototypes.sh` first to copy prototype HTML into `public/prototypes/`, then `astro build`.

`public/prototypes/` is gitignored — it's regenerated from `runs/sprint/` on every build.

## Deploy to GitHub Pages (optional)

zachflow ships a workflow template at `.github/workflows/gallery.yml.example`. To enable:

1. Rename to `.github/workflows/gallery.yml`
2. Set the `site` field in `astro.config.mjs` to your GitHub Pages URL (e.g., `https://<user>.github.io/<repo>/`)
3. Commit + push — the workflow builds + deploys on each push to `main` that touches `runs/sprint/**` or `packages/zachflow-gallery/**`

Other platforms (Vercel, Netlify, Cloudflare Pages): use their native Astro integrations. Set the build command to `npm run build --workspace=packages/zachflow-gallery` and the output directory to `packages/zachflow-gallery/dist/`.

## Customization

The gallery is intentionally minimal. To extend:

- **Theme**: edit `src/components/Layout.astro` style block (CSS variables in `:root`)
- **Card style**: edit `src/components/PrototypeCard.astro`
- **Add filters / search / archetypes**: extend `src/pages/index.astro` or add new page components
- **Per-run metadata**: parse your `sprint-config.yaml` or run-level docs in the page's frontmatter

The shell stays out of design opinions so you can layer your project's identity without fighting framework defaults.

## Iframe sandbox

Prototype iframes use `sandbox="allow-same-origin"` — this blocks JavaScript execution inside prototype HTML. If your prototypes need JS (interactive demos), edit the `sandbox` attribute in `src/components/PrototypeCard.astro` and `src/pages/[run]/[prototype].astro` (e.g., add `allow-scripts`).

## Limitations (v1.0)

- No `qa-fix` run rendering (only `runs/sprint/`). v1.x will add `runs/qa-fix/<id>/` browsing.
- No screenshot capture / visual baseline / test integration.
- No exemplar/archetype taxonomy.
- No theme toggle / mobile-optimized navigation.
- Iframe thumbnail uses CSS `transform: scale(0.5)` — visual artifacts possible in some browsers; trade-off for zero-JS thumbnails.

These are intentional v1.0 boundaries — the shell is meant to be extended, not all-in-one. See zachflow's main `docs/roadmap.md` for v1.x plans.
```

- [ ] **Step 5.2: Verify**

```bash
[ -s ~/dev/personal/zachflow/packages/zachflow-gallery/README.md ] && echo "exists, non-empty"
lc=$(wc -l < ~/dev/personal/zachflow/packages/zachflow-gallery/README.md)
echo "lines: $lc"
[ $lc -ge 60 ] && echo "size OK"

# Code fences balanced
fc=$(grep -c '^```' ~/dev/personal/zachflow/packages/zachflow-gallery/README.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"
```

Expected: 4 OK lines.

- [ ] **Step 5.3: Commit**

```bash
cd ~/dev/personal/zachflow
git add packages/zachflow-gallery/README.md
git commit -m "docs(gallery): add zachflow-gallery README with quick start + customization guide"
```

---

## Task 6: GH Pages workflow template

**Files:**
- Create: `~/dev/personal/zachflow/.github/workflows/gallery.yml.example`

- [ ] **Step 6.1: Write the workflow template**

Use Write tool to create `~/dev/personal/zachflow/.github/workflows/gallery.yml.example` with this EXACT content:

```yaml
# .github/workflows/gallery.yml.example
# Optional: deploy zachflow-gallery to GitHub Pages.
#
# To enable:
#   1. Rename this file to gallery.yml
#   2. Set the `site` field in packages/zachflow-gallery/astro.config.mjs
#      to your GitHub Pages URL (e.g., https://<user>.github.io/<repo>/)
#   3. Enable GitHub Pages in repo settings → Pages → Source: GitHub Actions
#   4. Commit + push — the workflow builds + deploys on each main push
#      that touches runs/sprint/** or packages/zachflow-gallery/**

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

# Allow only one concurrent deployment.
concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install dependencies
        run: npm install

      - name: Build gallery
        run: npm run build --workspace=packages/zachflow-gallery

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: packages/zachflow-gallery/dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 6.2: Verify YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/gallery.yml.example')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 6.3: Verify file is the `.example` version (not active)**

```bash
[ -f ~/dev/personal/zachflow/.github/workflows/gallery.yml.example ] && echo ".example exists"
[ ! -f ~/dev/personal/zachflow/.github/workflows/gallery.yml ] && echo "no active gallery.yml (correct — user opt-in)"
```

Expected: 2 OK lines.

- [ ] **Step 6.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add .github/workflows/gallery.yml.example
git commit -m "feat(ci): add gallery.yml.example GitHub Pages workflow template (user opt-in)"
```

---

## Task 7: roadmap update + CHANGELOG + final smoke + v0.6.0-sprint-4b-gallery tag

**Files:**
- Modify: `~/dev/personal/zachflow/docs/roadmap.md`
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`

- [ ] **Step 7.1: Update roadmap.md**

Read `~/dev/personal/zachflow/docs/roadmap.md`. Find this exact line:

```markdown
- [ ] Sprint 4b — `zachflow-gallery` package
```

Use Edit tool to change `[ ]` to `[x]`:

```markdown
- [x] Sprint 4b — `zachflow-gallery` package
```

- [ ] **Step 7.2: Add Sprint 4b entry to CHANGELOG**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Find this exact line:

```markdown
## [0.5.0-sprint-4a-plugins] — 2026-04-27
```

Use Edit tool to insert a new section ABOVE that line:

```markdown
## [0.6.0-sprint-4b-gallery] — 2026-04-27

### Added
- `packages/zachflow-gallery/` — Astro-based minimum viable gallery shell that auto-indexes `runs/sprint/<run-id>/prototypes/**/*.html`.
- Astro components: `Layout.astro` (dark theme with CSS variables), `PrototypeCard.astro` (iframe-based thumbnail).
- Astro pages: `index.astro` (auto-discovery home), `[run]/[prototype].astro` (dynamic detail route via `getStaticPaths`).
- `packages/zachflow-gallery/scripts/copy-prototypes.sh` — bash build-time HTML copier (no TypeScript dep).
- `.github/workflows/gallery.yml.example` — optional GitHub Pages deployment workflow (user opt-in via rename).
- Root `package.json` workspaces (`packages/*`) + scripts (`gallery:dev`, `gallery:build`, `gallery:preview`).

### Notes
- Gallery is **shell only** — no ZZEM-specific content (exemplars, foundations, design tokens, archetype taxonomy). Users layer their own design system.
- Build-time discovery via Astro's `getStaticPaths` — no runtime indexing.
- iframe sandbox is `allow-same-origin` — blocks JS in prototypes by default. Users can relax in components if needed.
- Gallery is **not** in the main CI workflow. Heavy npm install required; deferred to v1.x dedicated CI matrix.
- Single dependency: `astro@^4.16.0`. No React, no MDX, no Playwright (those join in v1.x as needed).

### Deferred to Sprint 4c / v1.x+

- `npx zachflow-gallery init` (scaffold gallery into existing project) — Sprint 4c
- `qa-fix` run rendering (`runs/qa-fix/<id>/` browsing) — v1.x
- Token validation, exemplar management, archetype taxonomy — v1.x
- Screenshot capture / visual baseline / dogfood verification — v1.x
- Search palette, theme toggle, mobile-optimized navigation — v1.x
- Tests (vitest + playwright) — v1.x

## [0.5.0-sprint-4a-plugins] — 2026-04-27
```

- [ ] **Step 7.3: End-to-end smoke**

```bash
cd ~/dev/personal/zachflow

# 1. install-workflows idempotent (Sprint 2)
bash scripts/install-workflows.sh

# 2. KB smoke (Sprint 1)
bash tests/kb-smoke.sh

# 3. init-project smoke (Sprint 3)
bash tests/init-project-smoke.sh

# 4. Plugin tests (Sprint 4a)
bash plugins/recall/tests/test_config.sh
bash plugins/recall/tests/test_session.sh

# 5. Gallery script syntax + empty-runs scenario
bash -n packages/zachflow-gallery/scripts/copy-prototypes.sh && echo "copy-prototypes.sh syntax OK"
bash packages/zachflow-gallery/scripts/copy-prototypes.sh

# 6. ZZEM-leak with current exclusions
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.zachflow \
  --exclude-dir=docs/superpowers \
  --exclude-dir=dist \
  --exclude='CHANGELOG.md' \
  --exclude='docs/roadmap.md' \
  --exclude='docs/llm-platform-coupling.md' \
  --exclude='docs/kb-system.md' \
  --exclude='.github/workflows/ci.yml' \
  . > /dev/null && echo "leak scan FAIL" || echo "leak scan PASS"

# 7. Bash syntax all (now includes gallery scripts)
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh plugins/*/scripts/*.sh plugins/*/tests/*.sh packages/zachflow-gallery/scripts/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 8. Gallery files present
[ -d packages/zachflow-gallery ] && echo "packages/zachflow-gallery/ exists"
[ -f packages/zachflow-gallery/package.json ] && echo "gallery package.json"
[ -f packages/zachflow-gallery/astro.config.mjs ] && echo "astro.config.mjs"
[ -f packages/zachflow-gallery/src/components/Layout.astro ] && echo "Layout.astro"
[ -f packages/zachflow-gallery/src/components/PrototypeCard.astro ] && echo "PrototypeCard.astro"
[ -f packages/zachflow-gallery/src/pages/index.astro ] && echo "index.astro"
[ -f packages/zachflow-gallery/src/pages/\[run\]/\[prototype\].astro ] && echo "[run]/[prototype].astro"
[ -f packages/zachflow-gallery/README.md ] && echo "gallery README"
[ -f .github/workflows/gallery.yml.example ] && echo "gallery.yml.example"

# 9. Root package.json has workspaces
python3 -c "
import json
data = json.load(open('package.json'))
assert data['workspaces'] == ['packages/*']
assert 'gallery:dev' in data['scripts']
assert 'gallery:build' in data['scripts']
print('root package.json workspaces OK')
"

# 10. Gallery file count
gallery_count=$(find packages/zachflow-gallery -type f \( -name '*.astro' -o -name '*.json' -o -name '*.mjs' -o -name '*.md' -o -name '*.svg' -o -name '*.sh' -o -name '.gitignore' \) | wc -l | tr -d ' ')
echo "gallery file count: $gallery_count (expected ≥10)"
[ "$gallery_count" -ge 10 ] && echo "gallery file count OK"
```

Expected: all OK lines, no FAIL.

- [ ] **Step 7.4: Final git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: only CHANGELOG.md + docs/roadmap.md modified (staged for commit).

- [ ] **Step 7.5: Commit roadmap + CHANGELOG**

```bash
cd ~/dev/personal/zachflow
git add docs/roadmap.md CHANGELOG.md
git commit -m "docs(changelog): Sprint 4b — zachflow-gallery package (0.6.0-sprint-4b-gallery)"
```

- [ ] **Step 7.6: Tag v0.6.0-sprint-4b-gallery**

```bash
cd ~/dev/personal/zachflow
git tag -a v0.6.0-sprint-4b-gallery -m "Sprint 4b — zachflow-gallery package complete (Astro shell with auto-indexing of runs/sprint/<id>/prototypes/, no ZZEM content, GH Pages workflow template)"
git tag -l --format='%(refname:short) - %(subject)' | tail -6
```

Expected: 6 tags total (v0.1.0-bootstrap, v0.2.0-sprint-1, v0.3.0-sprint-2, v0.4.0-sprint-3, v0.5.0-sprint-4a-plugins, v0.6.0-sprint-4b-gallery).

- [ ] **Step 7.7: Final commit history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -10
git rev-list --count v0.5.0-sprint-4a-plugins..HEAD
```

Expected: ~7-9 new commits since v0.5.0-sprint-4a-plugins tag.

---

## Sprint 4b Done Criteria

- [ ] `packages/zachflow-gallery/` directory with ≥10 files
- [ ] `package.json` (gallery), `astro.config.mjs`, `tsconfig.json`, `.gitignore` all present and valid
- [ ] `public/favicon.svg` exists
- [ ] `src/components/Layout.astro` + `src/components/PrototypeCard.astro` exist
- [ ] `src/pages/index.astro` + `src/pages/[run]/[prototype].astro` exist
- [ ] `scripts/copy-prototypes.sh` exists, executable, valid bash 3.2 syntax
- [ ] Root `package.json` has `workspaces: ["packages/*"]` + 3 gallery scripts
- [ ] `.github/workflows/gallery.yml.example` exists, valid YAML
- [ ] `docs/roadmap.md` Sprint 4b checked
- [ ] `CHANGELOG.md` `[0.6.0-sprint-4b-gallery]` entry
- [ ] Tag `v0.6.0-sprint-4b-gallery` exists
- [ ] No ZZEM-leak (existing scan passes)
- [ ] All bash scripts syntax OK (gallery scripts join the Sprint 0/1/2/3/4a syntax check)
- [ ] copy-prototypes.sh smoke run completes (empty + fixture scenarios)
- [ ] Working tree clean

---

## Notes for Sprint 4c

- Sprint 4c (`create-zachflow` + v1.0 release): adds `packages/create-zachflow/` npm wrapper for `npx create-zachflow my-project`. Wraps `git clone + bash scripts/init-project.sh`. The monorepo workspaces config (this sprint) makes it natural — both `zachflow-gallery` and `create-zachflow` live under `packages/*`.
- Sprint 4c will also tag `v1.0.0` (final v1.0 release).
- Gallery package is feature-complete for v1.0. v1.x+ will add qa-fix browsing, themes, search, screenshot capture, etc., based on community feedback.
