# Next.js + Supabase

Single-role zachflow setup for a Next.js application backed by Supabase. Demonstrates the smallest viable wizard config: one `app` role, one filled `fe-engineer` teammate, evaluator left as-shipped.

Use this as a starting point if your project is a Next.js (App Router) frontend talking to Supabase (Postgres + Auth + Storage), with no separately-versioned backend repo — Supabase migrations live alongside the app.

## What's in here

```
nextjs-supabase/
├── README.md                     # this file
├── init.config.yaml              # non-interactive wizard input
├── sprint-config.example.yaml    # expected wizard output (for diff/verify)
└── teammates/
    └── fe-engineer.md            # filled FE Engineer guide for Next.js + Supabase
```

`evaluator.md` is intentionally absent — the shipped `templates/teammates/evaluator.template.md` is stack-agnostic and works as-is.

## Using this example

1. Bootstrap a fresh project:

   ```bash
   npx https://github.com/hx2ryu/zachflow/releases/download/v1.1.0/create-zachflow-1.1.0.tgz my-app --tag=v1.1.0
   cd my-app
   ```

2. Copy this example's config in and **edit the `source:` path** to point at your real Next.js app checkout:

   ```bash
   cp examples/nextjs-supabase/init.config.yaml ./init.config.yaml
   $EDITOR init.config.yaml   # change `source: ~/dev/<your-nextjs-app>`
   ```

3. Run the wizard:

   ```bash
   bash scripts/init-project.sh --from=init.config.yaml --non-interactive
   ```

4. Compare your generated `sprint-config.yaml` to `sprint-config.example.yaml` — they should differ only in the `source:` path.

5. Optionally pre-seed the FE teammate guide:

   ```bash
   cp examples/nextjs-supabase/teammates/fe-engineer.md .claude/teammates/fe-engineer.md
   ```

## What this example does NOT cover

- Multi-role setups (e.g., separate NestJS backend + Next.js frontend). Use the default 3-role template in `templates/init.config.template.yaml` for that.
- A separate Supabase Edge Functions repo. If your edge functions live in their own repo, add a second role for them.
- Design tokens. If you publish design tokens from a separate repo, add a `tokens` role with `mode: symlink`.

## Maintainer

First-party reference example shipped with v1.1.0. Issues / improvements: open a PR against `examples/nextjs-supabase/`.
