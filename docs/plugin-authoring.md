# Authoring Plugins

zachflow ships one reference plugin: `plugins/recall/` (interactive sprint/KB recall). This document explains how plugins differ from workflows, the directory structure, and how to author a new plugin.

## Workflow vs Plugin (refresher)

(See [`workflow-authoring.md`](workflow-authoring.md) for the workflow side. Reproduced here in summary.)

| | Workflow | Plugin |
|-|----------|--------|
| Location | `workflows/<name>/` | `plugins/<name>/` |
| Install location | `.claude/skills/<name>` (project-level symlink, auto-installed by `scripts/install-workflows.sh`) | `~/.claude/skills/<name>` (user-level symlink, opt-in via `scripts/install-plugins.sh <name>`) |
| Distribution | Core, ships with zachflow v1.0 | Optional, user-installable |
| Updates | Tied to zachflow version | Independent versioning |
| Examples | `sprint`, `qa-fix` | `recall` (v1.0); future: Notion sync, Slack notifications |

If your feature is central to zachflow's value, it's a workflow. If it's peripheral and optional, it's a plugin.

## Plugin Directory Structure

```
plugins/<name>/
├── README.md              # plugin overview, install, config
├── <skill-name>/
│   └── SKILL.md           # frontmatter `name: <plugin>:<skill-name>` (e.g., `recall:ask`)
├── scripts/
│   ├── install.sh         # symlinks ~/.claude/skills/<name> → plugins/<name>
│   ├── uninstall.sh       # removes symlink (idempotent)
│   ├── load-config.sh     # config search path resolution (optional)
│   └── <other helpers>.sh
├── config/
│   ├── <name>.example.yaml    # annotated example with all fields
│   └── <name>.schema.json     # JSONSchema (draft 2020-12) for validation
└── tests/
    ├── smoke.md           # smoke check protocol (manual or CI)
    └── test_<area>.sh     # shell-based unit tests (e.g., test_config.sh)
```

## Required components

Each plugin must provide:

1. **`README.md`** — overview, install/uninstall, config file location, example usage.
2. **`<skill-name>/SKILL.md`** — at least one skill protocol with valid YAML frontmatter and `name: <plugin>:<skill-name>`.
3. **`scripts/install.sh`** — idempotent symlink creator (`ln -s plugins/<name> ~/.claude/skills/<name>`).
4. **`scripts/uninstall.sh`** — symlink remover (idempotent — no error if symlink missing).

## Optional components

- `config/` — if your plugin reads runtime config, ship an example + JSONSchema
- `scripts/load-config.sh` — if you support env-var override + multiple search paths
- `tests/` — shell-based unit tests, run via `bash tests/test_*.sh`

## Plugin namespacing

Skills inside a plugin use the plugin name as namespace prefix:

- `plugins/recall/ask/SKILL.md` has frontmatter `name: recall:ask` — invoked as `/recall:ask` or via Skill tool.
- `plugins/notion/sync/SKILL.md` would have `name: notion:sync`.

This avoids collision with core skill namespaces (`sprint`, `qa-fix`, `zachflow-kb`).

## Config layer pattern

If your plugin reads config, follow recall's pattern (see `plugins/recall/scripts/load-config.sh`):

```
$<NAME>_CONFIG  →  CWD/.<name>.yaml  →  ~/.<name>.yaml  →  plugins/<name>/config/<name>.example.yaml (fallback)
```

This lets users override per-environment without modifying the plugin.

## JSONSchema validation

Ship a schema file at `config/<name>.schema.json`. Use draft 2020-12. Skill protocol or `load-config.sh` validates user config against the schema before loading.

## Tests pattern

Plugin tests are bash scripts that exercise core behaviors. Run via:

```bash
bash plugins/<name>/tests/test_<area>.sh
```

Tests should:
- Be self-contained (no external service dependencies)
- Use temporary directories (`mktemp -d`) for fixtures
- Clean up via `trap`
- Print clear PASS/FAIL output

The `recall` plugin has 15 unit tests across `test_config.sh` (4) and `test_session.sh` (11) as a template.

## Adding a new plugin (10-step checklist)

1. **Decide if it's a plugin** — peripheral, optional, user-installable. If it's central to zachflow value, it's a workflow instead.

2. **Pick a name** — lowercase-hyphen, unique. Don't collide with `sprint`, `qa-fix`, `zachflow-kb` (core namespaces).

3. **Create the directory**:
   ```bash
   mkdir -p plugins/<name>/{<skill>,scripts,config,tests}
   ```

4. **Write `<skill>/SKILL.md`** with frontmatter `name: <name>:<skill>` and the skill protocol body.

5. **Write `scripts/install.sh`** that symlinks `~/.claude/skills/<name> → plugins/<name>` (idempotent — see `plugins/recall/scripts/install.sh` as reference).

6. **Write `scripts/uninstall.sh`** that removes the symlink (idempotent).

7. **(If config-driven) Write `config/<name>.example.yaml` + `config/<name>.schema.json`** with full annotation. Follow recall's config layer pattern in `scripts/load-config.sh`.

8. **Write `tests/test_<area>.sh`** for core behaviors. Use the recall plugin's `test_config.sh` and `test_session.sh` as templates.

9. **Write `README.md`** covering: overview, install (`bash scripts/install-plugins.sh <name>`), config location, basic usage, skill invocation examples.

10. **Add to CI** — modify `.github/workflows/ci.yml` to run your plugin's tests:
    ```yaml
    - name: <name> plugin unit tests
      run: |
        bash plugins/<name>/tests/test_<area>.sh
    ```

## Plugin-Core boundary (one-way dependency)

Plugins MAY use zachflow core assets:
- `workflows/_shared/*.md` (e.g., reference Build Loop primitive)
- `schemas/learning/*.schema.json` (e.g., reflection schema for domain validation)
- `${KB_PATH:-./.zachflow/kb}` (embedded KB)
- `runs/{sprint,qa-fix}/<id>/` (run artifacts)

Core MUST NOT depend on plugins. Workflows, KB skills, and core scripts work without any plugin installed.

## Reference plugin: `recall`

`plugins/recall/` is the v1.0 reference plugin. Use it as a template:

- Read `plugins/recall/README.md` for the user-facing format
- Read `plugins/recall/ask/SKILL.md` for the skill protocol pattern
- Read `plugins/recall/config/recall.example.yaml` and `recall.schema.json` for config + validation
- Read `plugins/recall/scripts/load-config.sh` for the config layer
- Read `plugins/recall/tests/test_*.sh` for the unit test pattern

## Future (v1.x+)

- Plugin marketplace / discovery — currently no central catalog; PRs to zachflow's `plugins/` are the channel
- Plugin upgrade/version management — currently each plugin is a directory; users update by replacing
- Plugin sandboxing/permissions — v2.0 candidate
- Cross-plugin events — v2.0 candidate
