# zachflow Manual

Operational guide for zachflow projects. For architecture and design rationale, see [`ARCHITECTURE.md`](ARCHITECTURE.md). For a high-level overview, see [`README.md`](README.md).

## Setup

### First-time setup

```bash
npx create-zachflow my-project
cd my-project
bash scripts/init-project.sh
```

This bootstraps a new project from the matching tagged release of zachflow, then runs the interactive wizard. Alternative install paths (legacy GitHub Release tarball, repo clone) live in [`packages/create-zachflow/README.md`](packages/create-zachflow/README.md).

The wizard takes ~5 minutes. After completion:
- `sprint-config.yaml` defines your project's roles and base branches
- `.claude/teammates/*.md` are filled with your stack specifics
- `.zachflow/kb/` is initialized (embedded mode)

### Non-interactive setup (for CI)

```bash
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml — see examples/nextjs-supabase/init.config.yaml for a
# working reference (one role, fe-engineer teammate, fill block populated).
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

The shape of `init.config.yaml` is documented inline in `templates/init.config.template.yaml`. After running, compare your generated `sprint-config.yaml` against `examples/nextjs-supabase/sprint-config.example.yaml` to sanity-check the wizard output.

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
