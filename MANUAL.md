# zachflow Manual

> Sprint 0 placeholder. Sprint 2+3 fill in operations details. For now this is a stub — refer to [`README.md`](README.md) and [`ARCHITECTURE.md`](ARCHITECTURE.md).

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

## Running a Sprint

```bash
/sprint my-first-sprint                   # full pipeline (Phase 1~6)
/sprint my-first-sprint --phase=init      # single phase
/sprint my-first-sprint --status          # dashboard
```

(Detailed phase docs live in `.claude/skills/sprint/`.)

## Running QA-Fix

```bash
/qa-fix qa-2026-04-27 --jql="project=ABC AND status='Ready for QA'"
```

(Detailed stages live in `.claude/skills/sprint/phase-qa-fix.md` — moves to `workflows/qa-fix/` in Sprint 2.)
