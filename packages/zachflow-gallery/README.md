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
