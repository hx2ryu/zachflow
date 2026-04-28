# Sprint 4c — create-zachflow + v1.0 Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship zachflow v1.0.0 — create `packages/create-zachflow/` Node.js wrapper (clone-and-strip), polish root docs (README/CONTRIBUTING/ARCHITECTURE/MANUAL), add release CI workflow, tag `v1.0.0`.

**Architecture:** `create-zachflow` is a 0-deps Node.js script (`child_process` + `fs` + `path`) that clones the zachflow repo with `--depth 1`, strips dev artifacts (`.git/`, `docs/superpowers/`, `.zachflow/`, `node_modules/`, `dist/`, `package-lock.json`), reinitializes git, and prints next steps. Root docs are append-only polish — preserve existing Sprint 0/3 content, add v1.0 sections covering plugins (Sprint 4a) and gallery (Sprint 4b). Release CI triggers on tag push (`v*`) and creates a GitHub Release with the matching CHANGELOG section as release notes.

**Tech Stack:** Node.js 18+ (0-deps), bash 3.2+ (no new bash scripts; existing remain), GitHub Actions (release workflow), git, JSON, YAML.

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-4c-release-design.md` (commit `9ccace2`). Read sections 1 (directory layout), 2 (create-zachflow logic), 3-4 (package.json + README), 5-8 (root doc polish per file), 9 (release.yml), 10 (CHANGELOG entry), 11 (roadmap update) before starting.

---

## File Structure (Sprint 4c output additions/changes)

```
~/dev/personal/zachflow/
├── packages/
│   └── create-zachflow/                  # NEW
│       ├── index.js                      # NEW (~150 lines, Node.js, executable)
│       ├── package.json                  # NEW (bin entry, private: true)
│       └── README.md                     # NEW (~50 lines)
│
├── .github/workflows/
│   └── release.yml                       # NEW (tag push → GitHub Release)
│
├── README.md                             # MODIFIED (v1.0 polish)
├── CONTRIBUTING.md                       # MODIFIED (v1.0 polish)
├── ARCHITECTURE.md                       # MODIFIED (append plugins + gallery sections)
├── MANUAL.md                             # MODIFIED (append plugin install + gallery sections)
├── CHANGELOG.md                          # MODIFIED ([1.0.0] final entry)
└── docs/roadmap.md                       # MODIFIED (Sprint 4c checked + v1.0 banner)
```

Total NEW files: 4. Modified: 6.

---

## Task 1: Create `packages/create-zachflow/` package

**Files:**
- Create: `~/dev/personal/zachflow/packages/create-zachflow/index.js`
- Create: `~/dev/personal/zachflow/packages/create-zachflow/package.json`
- Create: `~/dev/personal/zachflow/packages/create-zachflow/README.md`

- [ ] **Step 1.1: Create directory**

```bash
mkdir -p ~/dev/personal/zachflow/packages/create-zachflow
```

- [ ] **Step 1.2: Write `index.js`**

Use Write tool to create `~/dev/personal/zachflow/packages/create-zachflow/index.js` with this EXACT content:

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

// Validate target doesn't exist or is empty
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

- [ ] **Step 1.3: Make executable + verify**

```bash
chmod +x ~/dev/personal/zachflow/packages/create-zachflow/index.js
node --check ~/dev/personal/zachflow/packages/create-zachflow/index.js && echo "syntax OK"

# Test --help
node ~/dev/personal/zachflow/packages/create-zachflow/index.js --help | head -3

# Test no-args (should error)
node ~/dev/personal/zachflow/packages/create-zachflow/index.js 2>&1 | head -3 || true
```

Expected:
- `syntax OK`
- Help text first 3 lines (Usage: + options)
- Error message (Usage: ... + Run with --help)

- [ ] **Step 1.4: Write `package.json`**

Use Write tool to create `~/dev/personal/zachflow/packages/create-zachflow/package.json` with this EXACT content:

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

- [ ] **Step 1.5: Write `README.md`**

Use Write tool to create `~/dev/personal/zachflow/packages/create-zachflow/README.md` with this EXACT content:

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

- [ ] **Step 1.6: Verify package.json valid + bin entry**

```bash
python3 -c "
import json
data = json.load(open('/Users/zachryu/dev/personal/zachflow/packages/create-zachflow/package.json'))
assert data['name'] == 'create-zachflow'
assert data['version'] == '1.0.0'
assert data['private'] == True
assert data['bin']['create-zachflow'] == './index.js'
print('package.json OK')
"
```

Expected: `package.json OK`.

- [ ] **Step 1.7: Functional smoke — clone-and-strip from local repo**

Test the wrapper end-to-end using local zachflow as repo source:

```bash
TEST_DIR=$(mktemp -d -t create-zachflow-smoke-XXXX)
cd "$TEST_DIR"

# Use local zachflow as --repo (bypasses GitHub)
node ~/dev/personal/zachflow/packages/create-zachflow/index.js my-test \
  --repo="$HOME/dev/personal/zachflow" \
  --branch=main 2>&1 | tail -20

# Verify outputs
[ -d "$TEST_DIR/my-test" ] && echo "directory created"
[ ! -d "$TEST_DIR/my-test/.git" ] || git -C "$TEST_DIR/my-test" log --oneline | head -1  # fresh git init shows 1 commit
[ ! -d "$TEST_DIR/my-test/docs/superpowers" ] && echo "docs/superpowers stripped"
[ ! -d "$TEST_DIR/my-test/.zachflow" ] && echo ".zachflow stripped"
[ ! -d "$TEST_DIR/my-test/node_modules" ] && echo "node_modules stripped"
[ -f "$TEST_DIR/my-test/scripts/init-project.sh" ] && echo "init-project.sh preserved"
[ -d "$TEST_DIR/my-test/workflows" ] && echo "workflows/ preserved"
[ -d "$TEST_DIR/my-test/plugins" ] && echo "plugins/ preserved"

# Cleanup
cd /tmp
rm -rf "$TEST_DIR"
```

Expected:
- Tail shows "Cloning zachflow from..." → "Stripping development artifacts..." → "Initializing fresh git repo..." → "✓ zachflow project created"
- 6 OK lines for verification

- [ ] **Step 1.8: Commit**

```bash
cd ~/dev/personal/zachflow
git add packages/create-zachflow/
git commit -m "feat(create-zachflow): add 0-deps Node.js bootstrap wrapper (clone-and-strip)"
```

---

## Task 2: Root README.md v1.0 polish

**Files:**
- Modify: `~/dev/personal/zachflow/README.md`

- [ ] **Step 2.1: Read current README**

```
Read ~/dev/personal/zachflow/README.md
```

The current README is the v0.1 stub from Sprint 0 — it has Quick Start placeholder and basic feature list.

- [ ] **Step 2.2: Replace with v1.0 polished version**

Use Write tool to overwrite `~/dev/personal/zachflow/README.md` with this EXACT content:

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

- [ ] **Step 2.3: Verify**

```bash
[ -s ~/dev/personal/zachflow/README.md ] && echo "exists, non-empty"
lc=$(wc -l < ~/dev/personal/zachflow/README.md)
echo "lines: $lc"
[ $lc -ge 60 ] && echo "size OK"

# Code fences balanced
fc=$(grep -c '^```' ~/dev/personal/zachflow/README.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"

# Verify v1.0 markers
grep -q "v1.0.0" ~/dev/personal/zachflow/README.md && echo "v1.0.0 reference present"
grep -q "npx create-zachflow" ~/dev/personal/zachflow/README.md && echo "create-zachflow reference"
grep -q "Plugin system" ~/dev/personal/zachflow/README.md && echo "Plugin section"
grep -q "Auto-indexed gallery" ~/dev/personal/zachflow/README.md && echo "Gallery section"
```

Expected: 7 OK lines.

- [ ] **Step 2.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add README.md
git commit -m "docs: polish README to v1.0 (badges, quickstart, features, architecture)"
```

---

## Task 3: CONTRIBUTING.md v1.0 polish

**Files:**
- Modify: `~/dev/personal/zachflow/CONTRIBUTING.md`

- [ ] **Step 3.1: Read current CONTRIBUTING**

```
Read ~/dev/personal/zachflow/CONTRIBUTING.md
```

Sprint 0 의 v0.1 stub. Sprint 4c 가 v1.0 정식화.

- [ ] **Step 3.2: Replace with v1.0 polished version**

Use Write tool to overwrite `~/dev/personal/zachflow/CONTRIBUTING.md` with this EXACT content:

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

- [ ] **Step 3.3: Verify**

```bash
[ -s ~/dev/personal/zachflow/CONTRIBUTING.md ] && echo "exists, non-empty"
lc=$(wc -l < ~/dev/personal/zachflow/CONTRIBUTING.md)
echo "lines: $lc"
[ $lc -ge 40 ] && echo "size OK"

# Verify v1.0 markers
grep -q "v1.0.0" ~/dev/personal/zachflow/CONTRIBUTING.md && echo "v1.0.0 reference"
grep -q "Bash 3.2" ~/dev/personal/zachflow/CONTRIBUTING.md && echo "bash 3.2 standard"
grep -q "plugin-authoring.md" ~/dev/personal/zachflow/CONTRIBUTING.md && echo "plugin guide ref"
grep -q "workflow-authoring.md" ~/dev/personal/zachflow/CONTRIBUTING.md && echo "workflow guide ref"
```

Expected: 6 OK lines.

- [ ] **Step 3.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add CONTRIBUTING.md
git commit -m "docs: polish CONTRIBUTING.md to v1.0 (issue/PR + standards + license sign-off)"
```

---

## Task 4: ARCHITECTURE.md v1.0 polish (append plugins + gallery sections)

**Files:**
- Modify: `~/dev/personal/zachflow/ARCHITECTURE.md`

- [ ] **Step 4.1: Read current ARCHITECTURE**

```
Read ~/dev/personal/zachflow/ARCHITECTURE.md
```

Sprint 0 의 ARCHITECTURE 가 design principles + sprint pipeline + Build Loop + KB 까지 다룸. Sprint 4c 가 plugin system + gallery package sections 추가 (append-only).

- [ ] **Step 4.2: Find insertion point**

Locate the `## LLM Platform Coupling` section (or the LAST section before it). The new sections go BEFORE that section, after `## Knowledge Base`.

If the current file structure is:
```
... existing sections ...
## Knowledge Base
(KB content)

## LLM Platform Coupling
(LLM content)
```

The insertion target is between Knowledge Base and LLM Platform Coupling.

- [ ] **Step 4.3: Insert plugin + gallery sections via Edit**

Use Edit tool. Find the line `## LLM Platform Coupling` (or whatever section comes after Knowledge Base). Insert this content BEFORE that line:

```markdown
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

```

(Note: trailing blank line preserves spacing before LLM Platform Coupling section.)

If `## LLM Platform Coupling` is not found in the file (Sprint 0 may have used different header), insert at end of file (before final newline).

- [ ] **Step 4.4: Verify**

```bash
[ -s ~/dev/personal/zachflow/ARCHITECTURE.md ] && echo "exists, non-empty"

grep -q "## Plugin System" ~/dev/personal/zachflow/ARCHITECTURE.md && echo "Plugin section"
grep -q "## Gallery Package" ~/dev/personal/zachflow/ARCHITECTURE.md && echo "Gallery section"
grep -q "plugins/recall/" ~/dev/personal/zachflow/ARCHITECTURE.md && echo "recall reference"
grep -q "packages/zachflow-gallery/" ~/dev/personal/zachflow/ARCHITECTURE.md && echo "gallery package reference"

# Code fences balanced
fc=$(grep -c '^```' ~/dev/personal/zachflow/ARCHITECTURE.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"
```

Expected: 5 OK lines.

- [ ] **Step 4.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add ARCHITECTURE.md
git commit -m "docs: append Plugin System + Gallery Package sections to ARCHITECTURE for v1.0"
```

---

## Task 5: MANUAL.md v1.0 polish (append plugin install + gallery sections)

**Files:**
- Modify: `~/dev/personal/zachflow/MANUAL.md`

- [ ] **Step 5.1: Read current MANUAL**

```
Read ~/dev/personal/zachflow/MANUAL.md
```

Sprint 3 가 Setup section 정식화 했음. Sprint 4c 가 plugin install + gallery sections 추가 (append-only at end).

- [ ] **Step 5.2: Append plugin + gallery sections at end of file**

Read the file's last line. Use Edit tool to APPEND the new sections at the end. Find the last meaningful line (likely the end of the existing "Running QA-Fix" section or any closing section), and insert AFTER it:

The exact append content:

```markdown

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

If MANUAL.md ends with a specific section that you can detect, use Edit to find that section's last line and append after. If the file ends ambiguously, use Read to see the actual last lines, then append carefully (preserve existing trailing newline behavior).

- [ ] **Step 5.3: Verify**

```bash
[ -s ~/dev/personal/zachflow/MANUAL.md ] && echo "exists, non-empty"

grep -q "## Installing Plugins" ~/dev/personal/zachflow/MANUAL.md && echo "Plugin install section"
grep -q "## Running the Gallery" ~/dev/personal/zachflow/MANUAL.md && echo "Gallery section"
grep -q "scripts/install-plugins.sh" ~/dev/personal/zachflow/MANUAL.md && echo "install-plugins ref"
grep -q "npm run gallery:dev" ~/dev/personal/zachflow/MANUAL.md && echo "gallery:dev ref"

fc=$(grep -c '^```' ~/dev/personal/zachflow/MANUAL.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"
```

Expected: 5 OK lines.

- [ ] **Step 5.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add MANUAL.md
git commit -m "docs: append Plugin install + Gallery sections to MANUAL for v1.0"
```

---

## Task 6: GitHub Actions release workflow

**Files:**
- Create: `~/dev/personal/zachflow/.github/workflows/release.yml`

- [ ] **Step 6.1: Write release.yml**

Use Write tool to create `~/dev/personal/zachflow/.github/workflows/release.yml` with this EXACT content:

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

- [ ] **Step 6.2: Verify YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/release.yml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 6.3: Verify trigger + permissions**

```bash
python3 -c "
import yaml
data = yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/release.yml'))
# Get the 'on' trigger (key may be parsed as bool True or string 'on')
trigger = data.get(True, data.get('on'))
assert trigger is not None, 'no on trigger'
assert 'tags' in trigger['push'], 'no tags trigger'
assert trigger['push']['tags'] == ['v*'], 'wrong tag pattern'
assert data['permissions']['contents'] == 'write', 'wrong permissions'
print('release.yml structure OK')
"
```

Expected: `release.yml structure OK`.

- [ ] **Step 6.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add .github/workflows/release.yml
git commit -m "feat(ci): add release.yml — tag push (v*) → GitHub Release with CHANGELOG excerpt"
```

---

## Task 7: CHANGELOG [1.0.0] + roadmap update + final smoke + v1.0.0 tag 🎉

**Files:**
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`
- Modify: `~/dev/personal/zachflow/docs/roadmap.md`

- [ ] **Step 7.1: Add [1.0.0] entry to CHANGELOG**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Find this exact line:

```markdown
## [0.6.0-sprint-4b-gallery] — 2026-04-27
```

Use Edit tool to insert a new section ABOVE that line:

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

## [0.6.0-sprint-4b-gallery] — 2026-04-27
```

- [ ] **Step 7.2: Update roadmap.md**

Read `~/dev/personal/zachflow/docs/roadmap.md`. Find this section:

```markdown
## v1.0 (current — Sprints 0–4)

- [x] Sprint 0 — Bootstrap: clean repo + sanitized core
- [x] Sprint 1 — KB embedded mode + skill rename (`zzem-kb:*` → `zachflow-kb:*`)
- [ ] Sprint 2 — Workflow split: `workflows/{sprint,qa-fix,_shared}/` + `/qa-fix` first-class
- [ ] Sprint 3 — Stack adapter: placeholder templates + `init-project.sh` wizard
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [ ] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release
```

Use Edit tool to replace this section with:

```markdown
## v1.0 ✓ shipped 2026-04-29

- [x] Sprint 0 — Bootstrap: clean repo + sanitized core
- [x] Sprint 1 — KB embedded mode + skill rename (`zzem-kb:*` → `zachflow-kb:*`)
- [x] Sprint 2 — Workflow split: `workflows/{sprint,qa-fix,_shared}/` + `/qa-fix` first-class
- [x] Sprint 3 — Stack adapter: placeholder templates + `init-project.sh` wizard
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [x] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release
```

(Note: also marks Sprint 2 + Sprint 3 as `[x]` — those were completed earlier but checkbox was missed in earlier roadmap commits. Sprint 4c finalizes all checkboxes.)

- [ ] **Step 7.3: End-to-end smoke (v1.0 final verification)**

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

# 5. Gallery script syntax (Sprint 4b)
bash -n packages/zachflow-gallery/scripts/copy-prototypes.sh && echo "gallery script syntax OK"

# 6. create-zachflow node syntax (Sprint 4c)
node --check packages/create-zachflow/index.js && echo "create-zachflow syntax OK"

# 7. ZZEM-leak with current exclusions
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

# 8. Bash syntax all
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh plugins/*/scripts/*.sh plugins/*/tests/*.sh packages/zachflow-gallery/scripts/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 9. v1.0 final docs check
grep -q "v1.0.0" README.md && echo "README v1.0"
grep -q "Bash 3.2" CONTRIBUTING.md && echo "CONTRIBUTING v1.0"
grep -q "## Plugin System" ARCHITECTURE.md && echo "ARCHITECTURE plugins"
grep -q "## Installing Plugins" MANUAL.md && echo "MANUAL plugins"

# 10. Sprint 4c new files
[ -d packages/create-zachflow ] && echo "create-zachflow package"
[ -f packages/create-zachflow/index.js ] && echo "create-zachflow index.js"
[ -f .github/workflows/release.yml ] && echo "release.yml"

# 11. CHANGELOG [1.0.0] entry present
grep -q "^## \[1.0.0\]" CHANGELOG.md && echo "CHANGELOG [1.0.0]"
```

Expected: all OK lines, no FAIL.

- [ ] **Step 7.4: Final git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: only CHANGELOG.md + docs/roadmap.md modified (staged).

- [ ] **Step 7.5: Commit CHANGELOG + roadmap**

```bash
cd ~/dev/personal/zachflow
git add CHANGELOG.md docs/roadmap.md
git commit -m "docs: zachflow v1.0.0 release — CHANGELOG + roadmap final"
```

- [ ] **Step 7.6: Tag v1.0.0 🎉**

```bash
cd ~/dev/personal/zachflow
git tag -a v1.0.0 -m "zachflow v1.0.0 — initial release. Sprint 4c complete (create-zachflow + docs polish + release CI). v1.0 ship gate satisfied: full sprint runner + KB embedded + workflow split + stack adapter + plugin system + gallery package + create-zachflow wrapper."
git tag -l --format='%(refname:short) - %(subject)' | tail -7
```

Expected: 7 tags total (bootstrap, sprint-1, sprint-2, sprint-3, sprint-4a, sprint-4b, **v1.0.0** 🎉).

- [ ] **Step 7.7: Final history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -15
git rev-list --count v0.6.0-sprint-4b-gallery..HEAD
echo "Total commits in v1.0:"
git rev-list --count v1.0.0
```

Expected: ~7-9 new commits since v0.6.0-sprint-4b-gallery + total ~70 commits in v1.0.

---

## Sprint 4c Done Criteria (v1.0 final)

- [ ] `packages/create-zachflow/index.js` 0-deps Node.js, executable, `node --check` PASS
- [ ] `packages/create-zachflow/package.json` valid + bin entry
- [ ] `packages/create-zachflow/README.md` ~50 lines
- [ ] `node packages/create-zachflow/index.js my-test --repo=<local zachflow path>` clone-and-strip works (manual smoke)
- [ ] `README.md` v1.0 polished (badges + quickstart + features + architecture)
- [ ] `CONTRIBUTING.md` v1.0 polished (issue/PR + standards + license)
- [ ] `ARCHITECTURE.md` v1.0 polished (Plugin System + Gallery Package sections appended)
- [ ] `MANUAL.md` v1.0 polished (Installing Plugins + Running the Gallery sections appended)
- [ ] `.github/workflows/release.yml` valid YAML, tag push trigger, contents:write permission
- [ ] `CHANGELOG.md` `[1.0.0]` final entry (release date + highlights + sprint history + roadmap)
- [ ] `docs/roadmap.md` v1.0 banner ("✓ shipped 2026-04-29") + all 7 sprints checked
- [ ] **Tag `v1.0.0`** 🎉
- [ ] No ZZEM-leak (existing scan passes)
- [ ] All bash scripts syntax OK (regression check)
- [ ] All existing CI smokes still pass (KB, init-project, recall, gallery script syntax)
- [ ] Working tree clean

---

## Notes for v1.x+

- v1.0 ship complete. zachflow is now externally-installable via `npx create-zachflow my-project` (with `--repo=` override until npm publish lands).
- Hot-fix policy: v1.0.x patches via `git tag v1.0.1` etc. CHANGELOG section format remains `## [<version>] — <date>`.
- v1.x roadmap: KB remote mode wizard, npm publish, multi-LLM platform support, additional plugins, qa-fix gallery rendering, theme toggle, multi-platform CI matrix.
- v2.0: Workflow yaml DSL, plugin lifecycle hooks, plugin sandboxing.

The complete migration plan from `zzem-orchestrator` reference patterns to `zachflow` v1.0 is now realized: 7 sprints, ~70 commits, 117+ tracked files, 7 tags, working ship gate (`npx create-zachflow` → `init-project.sh` → `/sprint <id>` end-to-end on Claude Code).
