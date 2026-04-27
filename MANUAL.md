# zachflow Manual

> Sprint 0 placeholder. Sprint 2+3 fill in operations details. For now this is a stub — refer to [`README.md`](README.md) and [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Setup (preview)

```bash
npx create-zachflow my-project   # Sprint 4
cd my-project
./scripts/init-project.sh        # Sprint 3 — interactive wizard
```

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
