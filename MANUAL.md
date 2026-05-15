# zachflow Manual

Operational guide for zachflow projects. For architecture and design rationale, see [`ARCHITECTURE.md`](ARCHITECTURE.md). For a high-level overview, see [`README.md`](README.md).

## Setup

### First-time setup

```bash
npx create-zachflow my-project
```

`create-zachflow` clones zachflow at the matching tag, strips dev artifacts, re-inits git, and auto-runs the interactive wizard (when stdin is a TTY). End-to-end setup takes ~5 minutes. Alternative install paths (legacy GitHub Release tarball, repo clone) live in [`packages/create-zachflow/README.md`](packages/create-zachflow/README.md).

After completion:
- `sprint-config.yaml` defines your project's roles and base branches
- `.claude/teammates/*.md` are filled with your stack specifics
- `.zachflow/kb/` is initialized (embedded mode)

If you'd rather inspect the project before initializing, pass `--no-init` and run `bash scripts/init-project.sh` yourself.

### Non-interactive setup (for CI)

```bash
npx create-zachflow my-project --no-init
cd my-project
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml — see examples/nextjs-supabase/init.config.yaml for a
# working reference (one role, fe-engineer teammate, fill block populated).
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

The shape of `init.config.yaml` is documented inline in `templates/init.config.template.yaml`. After running, compare your generated `sprint-config.yaml` against `examples/nextjs-supabase/sprint-config.example.yaml` to sanity-check the wizard output.

### Try it without your own repo (`--demo`)

```bash
bash scripts/init-project.sh --demo
```

Synthesizes a throwaway Node.js source repo in a temp directory (3 files, one git commit), wires a single backend role at it, initializes the KB, and prints the cleanup path. Zero prompts. Useful for evaluating zachflow before pointing it at real code, or for trying the sprint pipeline end-to-end in a workshop / demo. The wizard prints the throwaway path at the end — delete it with `rm -rf` when you're done.

`--demo` is incompatible with `--from=<file>` (the demo synthesizes its own config).

### Prerequisites

Before the wizard runs, `init-project.sh` checks for `git`, `python3 ≥ 3.8`, the `pyyaml` Python module, and (optionally) `node ≥ 18`. Missing items are reported as a batch with platform-aware install hints (macOS PEP 668 paths included). Pass `--skip-preflight` to bypass the check; the wizard will then fail later if something it actually needs is missing, so reach for this only when you know the check itself is wrong about your environment.

### Re-running the wizard

If you re-run `init-project.sh` and `sprint-config.yaml` exists, the wizard prompts before overwriting. Use `--force` to skip the prompt (with care — overwrites your customizations).

### Skipping placeholder fills

In step 5/7, answer `n` to skip teammate filling entirely; or per-placeholder, leave blank to keep the `{{...}}` marker. You can edit `.claude/teammates/*.md` directly later.

## Running a Sprint

```bash
/sprint my-first-sprint                   # full pipeline (Phase 1~6)
/sprint my-first-sprint --phase=init      # single phase
/sprint my-first-sprint --status          # dashboard
```

(Detailed phase docs live in [`workflows/sprint/`](workflows/sprint/) — `.claude/skills/sprint/` is a symlink installed by `scripts/install-workflows.sh`.)

## Running QA-Fix

```bash
/qa-fix qa-2026-04-27 --jql="project=ABC AND status='Ready for QA'"
```

(Detailed stages live in [`workflows/qa-fix/`](workflows/qa-fix/).)

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
