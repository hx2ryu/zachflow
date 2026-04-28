# Examples

This directory is for **stack adapter examples** — concrete configurations showing how to set up zachflow for specific tech stacks.

## Quick start (using the wizard)

```bash
git clone https://github.com/<org>/zachflow.git my-project
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
