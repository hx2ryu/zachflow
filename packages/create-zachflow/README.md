# create-zachflow

Bootstrap a new zachflow project. Zero runtime dependencies — uses only `git` and Node's built-in `node:child_process`/`node:fs`/`node:path`.

## Usage

```bash
npx https://github.com/hx2ryu/zachflow/releases/download/v1.1.1/create-zachflow-1.1.1.tgz my-project --tag=v1.1.1
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
| `--repo=<url>` | github.com/hx2ryu/zachflow.git | Repo URL |
| `--branch=<name>` | (none) | Branch to clone (e.g. `main`) |
| `--tag=<tag>` | `v<pkg-version>` | Tag to clone. Defaults to this package's version, so `create-zachflow@X.Y.Z` clones zachflow at `vX.Y.Z`. |
| `--help`, `-h` | | Show help |

Env vars: `ZACHFLOW_REPO_URL`, `ZACHFLOW_REF` (overrides the default ref).

## What gets stripped

The following are removed from the cloned repo:
- `.git/` (replaced with fresh git init)
- `docs/superpowers/` (zachflow design history — for contributors)
- `.zachflow/` (per-project state — wizard creates fresh)
- `node_modules/`, `dist/`, `package-lock.json` (regenerated)

What stays: `workflows/`, `plugins/`, `scripts/`, `templates/`, `.claude/`, `schemas/`, `tests/`, `packages/`, all root docs (README, MANUAL, ARCHITECTURE, CONTRIBUTING, CHANGELOG, LICENSE).

## v1.0 limitations

- Not yet on npm registry. Install today by pointing `npx` at the release tarball URL above. A direct `npx create-zachflow` form is planned for a v1.x publish.
- Alternative: `git clone --depth 1 --branch v1.1.1 https://github.com/hx2ryu/zachflow.git zachflow-template && node zachflow-template/packages/create-zachflow/index.js my-project --tag=v1.1.1`.

## License

MIT
