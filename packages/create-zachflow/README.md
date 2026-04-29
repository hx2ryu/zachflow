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
