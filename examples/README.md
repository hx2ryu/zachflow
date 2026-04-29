# Examples

This directory is for **stack adapter examples** — concrete configurations showing how to set up zachflow for specific tech stacks.

## Quick start (using the wizard)

```bash
git clone https://github.com/hx2ryu/zachflow.git my-project
cd my-project
bash scripts/init-project.sh
```

The wizard prompts for project name, workflows, role definitions, and teammate stack details. After completion, your `sprint-config.yaml` and `.claude/teammates/` are filled and ready.

For CI / scripted setup, use non-interactive mode:

```bash
cp templates/init.config.template.yaml init.config.yaml
# Edit init.config.yaml with your project specifics
bash scripts/init-project.sh --from=init.config.yaml --non-interactive
```

## Stack adapter examples

| Example | Stack | Roles | When to use |
|---------|-------|-------|-------------|
| [`nextjs-supabase/`](nextjs-supabase/) | Next.js (App Router, TS) + Supabase (Postgres, Auth, Storage) | 1 (`app`) | Single-app project with hosted backend; demonstrates minimum viable wizard config. |

External contributions welcome — see [`CONTRIBUTING.md`](../CONTRIBUTING.md).

(`plugins/recall/` is the first reference plugin example.)

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
