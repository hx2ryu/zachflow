# Sprint 4a — Plugins + Recall Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `plugins/recall/` from upstream `zzem-orchestrator` PR #57 into zachflow + formalize `plugins/<name>/` directory pattern + write `scripts/install-plugins.sh` opt-in installer + `docs/plugin-authoring.md` v1.0 reference.

**Architecture:** Recall plugin is OSS-portable per upstream design — port involves sanitizing ZZEM-specific paths (`./sprint-orchestrator/sprints` → `./runs/{sprint,qa-fix}/`, `~/.zzem/kb` → `${KB_PATH:-./.zachflow/kb}`, `zzem-kb` layout name → `zachflow-kb`, hardcoded domain enum → free string). Source files are read via `git show` from the local zzem-orchestrator checkout's origin/main (no checkout required). Plugin's own `scripts/install.sh` symlinks `~/.claude/skills/recall → plugins/recall` (user-level, distinct from Sprint 2's project-level workflow symlinks). Plugin's existing 15 unit tests (`test_config.sh` + `test_session.sh`) run as-is in CI.

**Tech Stack:** bash 3.2+ (already verified Sprint 3), Python 3.11+ (system default for YAML/JSON parsing), git (for `git show` source extraction), JSONSchema draft 2020-12.

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-4a-plugins-recall-design.md` (commit `a2db0be`). Read sections 1 (directory layout), 2 (file-by-file port table), 3 (recall.example.yaml conversion), 4 (schema conversion), 5 (SKILL.md sanitization), 6 (install-plugins.sh), 7 (plugin-authoring.md), 8 (CI), 9 (roadmap).

**Source repo (read-only):** `/Users/zachryu/dev/work/zzem-orchestrator` — origin/main has the recall plugin from PR #57. Use `git show origin/main:<path>` to extract source content without modifying the checkout.

---

## Sanitization Rules (apply to every ported file)

These rules are referenced by Tasks 1-3 below. Apply mechanically per file.

| Pattern | Replacement |
|---------|-------------|
| `./sprint-orchestrator/sprints` | `./runs` (with `workflows: [sprint, qa-fix]` filter where appropriate) |
| `sprints/<id>` (relative) | `runs/{sprint,qa-fix}/<id>` (or specific subdir) |
| `~/.zzem/kb` (KB path default) | `${KB_PATH:-./.zachflow/kb}` |
| `$ZZEM_KB_PATH` (env var) | `${KB_PATH}` (no $ prefix duplication; matches Sprint 1 convention) |
| `layout: zzem-kb` | `layout: zachflow-kb` |
| `domain_enum: [ai-webtoon, free-tab, ugc-platform, infra]` (hardcoded) | remove enum constraint + add note "domain is project-specific, free string matching `^[a-z][a-z0-9-]*$`" |
| `ZZEM` / `zzem-orchestrator` (literal) | `zachflow` |
| `zzem-kb:` (skill prefix in references) | `zachflow-kb:` (matches Sprint 1) |
| `zach-wrtn` / `wrtn.io` | remove |
| `MemeApp` / `meme-api` / `meme-pr` | remove sentence/example or `<example app>` placeholder |
| Korean text (rare in recall plugin) | translate to English |
| `$id` URLs in JSONSchema (e.g., `https://zach-wrtn.github.io/...`) | `https://zachflow.dev/schemas/<path>` |
| References to specific ZZEM sprint IDs (`ai-webtoon-007`, etc.) | `<example-sprint-id>` |
| `mcp__wrtn-mcp__*` tool names | KEEP (per master spec section 9 — user MCP, not zachflow) |

**Verification per file:** `grep -E 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb|\$ZZEM_KB_PATH' <file>` should return zero matches.

---

## File Structure (Sprint 4a output additions/changes)

```
~/dev/personal/zachflow/
├── plugins/                                    # NEW
│   └── recall/                                 # NEW (11 files ported)
│       ├── README.md
│       ├── ask/SKILL.md
│       ├── scripts/
│       │   ├── install.sh
│       │   ├── uninstall.sh
│       │   ├── load-config.sh
│       │   └── session.sh
│       ├── config/
│       │   ├── recall.example.yaml
│       │   └── recall.schema.json
│       └── tests/
│           ├── smoke.md
│           ├── test_config.sh
│           └── test_session.sh
│
├── scripts/
│   └── install-plugins.sh                      # NEW
│
├── docs/
│   ├── plugin-authoring.md                     # NEW (~150 lines)
│   └── roadmap.md                              # MODIFIED (Sprint 4a checkbox)
│
├── .github/workflows/ci.yml                    # MODIFIED (recall tests + install-plugins syntax)
└── CHANGELOG.md                                # MODIFIED ([0.5.0-sprint-4a-plugins])
```

**Source paths in this plan**:
- Source repo: `/Users/zachryu/dev/work/zzem-orchestrator`
- Read source via: `git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/<file>` (writes to stdout)
- Read pattern for implementer: redirect stdout to temp file, then Read the temp file

```bash
# Example: extract a source file
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/ask/SKILL.md > /tmp/recall-ask-SKILL.md
# Then Read /tmp/recall-ask-SKILL.md and apply Sanitization Rules
# Then Write the sanitized result to ~/dev/personal/zachflow/plugins/recall/ask/SKILL.md
```

---

## Task 1: Port simple files (8 files, minimal sanitization)

These files are largely OSS-portable per upstream design. Light sanitization (paths only) needed.

**Files (source → destination):**
- `plugins/recall/README.md` → `~/dev/personal/zachflow/plugins/recall/README.md`
- `plugins/recall/scripts/install.sh` → `~/dev/personal/zachflow/plugins/recall/scripts/install.sh`
- `plugins/recall/scripts/uninstall.sh` → `~/dev/personal/zachflow/plugins/recall/scripts/uninstall.sh`
- `plugins/recall/scripts/load-config.sh` → `~/dev/personal/zachflow/plugins/recall/scripts/load-config.sh`
- `plugins/recall/scripts/session.sh` → `~/dev/personal/zachflow/plugins/recall/scripts/session.sh`
- `plugins/recall/tests/smoke.md` → `~/dev/personal/zachflow/plugins/recall/tests/smoke.md`
- `plugins/recall/tests/test_config.sh` → `~/dev/personal/zachflow/plugins/recall/tests/test_config.sh`
- `plugins/recall/tests/test_session.sh` → `~/dev/personal/zachflow/plugins/recall/tests/test_session.sh`

(Source `.gitkeep` files in scripts/, config/, tests/ are NOT copied — those directories will have actual files.)

- [ ] **Step 1.1: Create directory tree**

```bash
mkdir -p ~/dev/personal/zachflow/plugins/recall/{ask,scripts,config,tests}
```

- [ ] **Step 1.2: Port `README.md`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/README.md > /tmp/recall-readme.md
```

Read `/tmp/recall-readme.md`. Apply Sanitization Rules. Write the result to `~/dev/personal/zachflow/plugins/recall/README.md`.

Specific sanitization for README.md:
- Title and overview kept (recall plugin — interactive sprint/KB recall)
- Install instructions reference `bash plugins/recall/scripts/install.sh` (path stays)
- Path examples (`./sprint-orchestrator/sprints`, `~/.zzem/kb`) → zachflow paths per Sanitization Rules
- Reference to upstream `zzem-orchestrator` removed or replaced with "zachflow's run directories"

- [ ] **Step 1.3: Port `scripts/install.sh`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/scripts/install.sh > /tmp/recall-install.sh
```

Read it. The script symlinks `~/.claude/skills/recall → plugins/recall` (per zachflow design). Should be OSS-portable already. Apply Sanitization Rules — likely just confirm no ZZEM literals (sanity check).

Write to `~/dev/personal/zachflow/plugins/recall/scripts/install.sh`. Then:

```bash
chmod +x ~/dev/personal/zachflow/plugins/recall/scripts/install.sh
bash -n ~/dev/personal/zachflow/plugins/recall/scripts/install.sh && echo "syntax OK"
```

- [ ] **Step 1.4: Port `scripts/uninstall.sh`**

Same procedure as install.sh. Source: `plugins/recall/scripts/uninstall.sh`. Removes the symlink. Should be OSS-portable.

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/scripts/uninstall.sh > /tmp/recall-uninstall.sh
```

Read, sanitize (likely no changes), Write, chmod, syntax check.

- [ ] **Step 1.5: Port `scripts/load-config.sh`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/scripts/load-config.sh > /tmp/recall-load-config.sh
```

This script implements the config search order ($RECALL_CONFIG → CWD → home → defaults). Sanitization:
- Remove ZZEM-specific default paths if any
- The search order pattern itself is generic — keep
- Default fallback paths (if any in script) → zachflow defaults

Read, sanitize, Write to `~/dev/personal/zachflow/plugins/recall/scripts/load-config.sh`. chmod, syntax check.

- [ ] **Step 1.6: Port `scripts/session.sh`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/scripts/session.sh > /tmp/recall-session.sh
```

Session state file path is `~/.recall/session.yaml` (user-level, not project-specific) — keep. Light sanitization for any ZZEM references in comments or echo strings.

Read, sanitize, Write, chmod, syntax check.

- [ ] **Step 1.7: Port `tests/smoke.md`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/tests/smoke.md > /tmp/recall-smoke.md
```

Smoke check protocol document. Light sanitization for any ZZEM examples in scenarios.

Read, sanitize, Write to `~/dev/personal/zachflow/plugins/recall/tests/smoke.md`.

- [ ] **Step 1.8: Port `tests/test_config.sh`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/tests/test_config.sh > /tmp/recall-test-config.sh
```

Sanitization:
- Test fixture data may have ZZEM-specific paths — update to zachflow paths
- Test logic unchanged

Read, sanitize, Write, chmod, syntax check.

- [ ] **Step 1.9: Port `tests/test_session.sh`**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/tests/test_session.sh > /tmp/recall-test-session.sh
```

11 unit tests. Same procedure as test_config.sh.

Read, sanitize, Write, chmod, syntax check.

- [ ] **Step 1.10: Verify ZZEM literal scan**

```bash
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb|\$ZZEM_KB_PATH' \
  ~/dev/personal/zachflow/plugins/recall/README.md \
  ~/dev/personal/zachflow/plugins/recall/scripts/ \
  ~/dev/personal/zachflow/plugins/recall/tests/ \
  2>/dev/null
```

Expected: no output.

- [ ] **Step 1.11: Verify Korean text**

```bash
grep -rP '[\x{AC00}-\x{D7A3}\x{1100}-\x{11FF}\x{3130}-\x{318F}]' \
  ~/dev/personal/zachflow/plugins/recall/README.md \
  ~/dev/personal/zachflow/plugins/recall/scripts/ \
  ~/dev/personal/zachflow/plugins/recall/tests/ \
  2>/dev/null
```

Expected: no output.

- [ ] **Step 1.12: Run unit tests locally**

```bash
bash ~/dev/personal/zachflow/plugins/recall/tests/test_config.sh
bash ~/dev/personal/zachflow/plugins/recall/tests/test_session.sh
```

Expected: each PASS (test count varies per upstream test design — `test_config.sh` has 4, `test_session.sh` has 11).

If tests fail because of missing dependencies (e.g., `recall.example.yaml` not yet ported), that's expected — Task 2 ports the config. Note in report and proceed.

- [ ] **Step 1.13: Commit**

```bash
cd ~/dev/personal/zachflow
git add plugins/recall/
git commit -m "feat(plugins): port recall plugin scripts + tests + README from upstream PR #57"
```

---

## Task 2: Port + sanitize `recall.example.yaml` + `recall.schema.json`

These have the heaviest schema-level sanitization (sources structure change from `sprints` to `runs.workflows`).

**Files:**
- Create: `~/dev/personal/zachflow/plugins/recall/config/recall.example.yaml`
- Create: `~/dev/personal/zachflow/plugins/recall/config/recall.schema.json`

- [ ] **Step 2.1: Read source files**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/config/recall.example.yaml > /tmp/recall-example.yaml
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/config/recall.schema.json > /tmp/recall-schema.json
```

Read both `/tmp/recall-example.yaml` and `/tmp/recall-schema.json`.

- [ ] **Step 2.2: Write `recall.example.yaml`**

Use Write tool to create `~/dev/personal/zachflow/plugins/recall/config/recall.example.yaml` with the SANITIZED version. The original (read in 2.1) has structure like:

```yaml
sources:
  sprints:
    path: ./sprint-orchestrator/sprints
    artifact_layout: ...
  kb:
    path: ~/.zzem/kb
    layout: zzem-kb
    domain_enum: [ai-webtoon, free-tab, ugc-platform, infra]
session:
  state_file: ~/.recall/session.yaml
  idle_timeout_minutes: 30
  stale_days: 7
```

The zachflow-sanitized version (write this exact content):

```yaml
# plugins/recall/config/recall.example.yaml
# zachflow recall plugin config — copy to your repo root as `.recall.yaml`
# or set $RECALL_CONFIG to point at a custom path.
#
# Config search order (see plugins/recall/scripts/load-config.sh):
#   1. $RECALL_CONFIG (if set, must point to existing file)
#   2. <CWD>/.recall.yaml
#   3. ~/.recall.yaml
#   4. plugins/recall/config/recall.example.yaml (this file, as fallback)

sources:
  runs:
    # zachflow workflow run instances live here (Sprint 2+ structure).
    path: ./runs
    workflows: [sprint, qa-fix]
    artifact_layout:
      always_read: [PRD.md, retrospective]
      conditional_read: [evaluations, contracts, tasks]
      skip_by_default: [prototypes, logs, checkpoints]

  kb:
    # zachflow embedded KB (Sprint 1).
    # ${KB_PATH} env var overrides; default is the project's .zachflow/kb.
    path: "${KB_PATH:-./.zachflow/kb}"
    layout: zachflow-kb
    # domain is project-specific. Recall accepts any string matching
    # ^[a-z][a-z0-9-]*$ (matches reflection schema in schemas/learning/).
    # No hardcoded enum.

session:
  # User-level session state (shared across projects on the same machine).
  state_file: ~/.recall/session.yaml
  idle_timeout_minutes: 30
  stale_days: 7
```

- [ ] **Step 2.3: Write `recall.schema.json`**

Use Write tool to create `~/dev/personal/zachflow/plugins/recall/config/recall.schema.json` with the SANITIZED version. Read the source (`/tmp/recall-schema.json`) first to understand its structure.

Source has `$id: "https://zach-wrtn.github.io/..."`. Replace with `https://zachflow.dev/...`. Replace `sprints` schema with `runs` (with `workflows` enum array). Remove `domain_enum` constraint from kb section. Keep session schema unchanged.

Write this content (verify against source for structure):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zachflow.dev/plugins/recall/recall.schema.json",
  "title": "zachflow recall plugin config",
  "type": "object",
  "additionalProperties": false,
  "required": ["sources", "session"],
  "properties": {
    "sources": {
      "type": "object",
      "additionalProperties": false,
      "required": ["runs", "kb"],
      "properties": {
        "runs": {
          "type": "object",
          "additionalProperties": false,
          "required": ["path", "workflows"],
          "properties": {
            "path": { "type": "string" },
            "workflows": {
              "type": "array",
              "items": { "enum": ["sprint", "qa-fix"] },
              "minItems": 1,
              "uniqueItems": true
            },
            "artifact_layout": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "always_read":      { "type": "array", "items": { "type": "string" } },
                "conditional_read": { "type": "array", "items": { "type": "string" } },
                "skip_by_default":  { "type": "array", "items": { "type": "string" } }
              }
            }
          }
        },
        "kb": {
          "type": "object",
          "additionalProperties": false,
          "required": ["path", "layout"],
          "properties": {
            "path":   { "type": "string" },
            "layout": { "const": "zachflow-kb" }
          }
        }
      }
    },
    "session": {
      "type": "object",
      "additionalProperties": false,
      "required": ["state_file", "idle_timeout_minutes", "stale_days"],
      "properties": {
        "state_file":           { "type": "string" },
        "idle_timeout_minutes": { "type": "integer", "minimum": 1 },
        "stale_days":           { "type": "integer", "minimum": 1 }
      }
    }
  }
}
```

- [ ] **Step 2.4: Validate YAML**

```bash
python3 -c "
import yaml
data = yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/plugins/recall/config/recall.example.yaml'))
assert 'sources' in data
assert 'runs' in data['sources']
assert data['sources']['runs']['workflows'] == ['sprint', 'qa-fix']
assert data['sources']['kb']['layout'] == 'zachflow-kb'
assert 'domain_enum' not in data['sources']['kb']
print('recall.example.yaml OK')
"
```

Expected: `recall.example.yaml OK`.

- [ ] **Step 2.5: Validate JSON Schema**

```bash
python3 -c "
import json
data = json.load(open('/Users/zachryu/dev/personal/zachflow/plugins/recall/config/recall.schema.json'))
assert data['\$schema'].endswith('draft/2020-12/schema')
assert data['\$id'].startswith('https://zachflow.dev/')
assert 'runs' in data['properties']['sources']['properties']
assert 'sprints' not in data['properties']['sources']['properties']
print('recall.schema.json OK')
"
```

Expected: `recall.schema.json OK`.

- [ ] **Step 2.6: Validate example against schema**

```bash
python3 -c "
import json, yaml
try:
    import jsonschema
except ImportError:
    print('jsonschema not installed; skipping validation (install via: pip install jsonschema)')
    exit(0)
schema = json.load(open('/Users/zachryu/dev/personal/zachflow/plugins/recall/config/recall.schema.json'))
example = yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/plugins/recall/config/recall.example.yaml'))
# Substitute env var for validation
import os
example_str = open('/Users/zachryu/dev/personal/zachflow/plugins/recall/config/recall.example.yaml').read().replace('\${KB_PATH:-./.zachflow/kb}', './.zachflow/kb')
example = yaml.safe_load(example_str)
jsonschema.validate(example, schema)
print('example validates against schema OK')
"
```

Expected: `example validates against schema OK` OR `jsonschema not installed; skipping validation`. (Pip install is optional — not blocking.)

- [ ] **Step 2.7: Commit**

```bash
cd ~/dev/personal/zachflow
git add plugins/recall/config/
git commit -m "feat(plugins): port recall plugin config — sanitize sources schema (sprints → runs.workflows, KB layout zachflow-kb, free domain)"
```

---

## Task 3: Port + sanitize `ask/SKILL.md` (the main skill, ~207 lines)

This is the largest single sanitization in Sprint 4a. Process carefully.

**Files:**
- Create: `~/dev/personal/zachflow/plugins/recall/ask/SKILL.md`

- [ ] **Step 3.1: Read source**

```bash
git -C /Users/zachryu/dev/work/zzem-orchestrator show origin/main:plugins/recall/ask/SKILL.md > /tmp/recall-ask-SKILL.md
```

Read `/tmp/recall-ask-SKILL.md`. The file is ~207 lines with frontmatter + skill protocol.

- [ ] **Step 3.2: Apply sanitization**

Apply ALL Sanitization Rules from the top of this plan. Specific operations expected:

1. **Frontmatter `name:`** — keep as `recall:ask` (plugin namespace, NOT `zachflow-recall:ask` — recall is the plugin name, ask is the skill).

2. **Frontmatter `description:`** — sanitize ZZEM mentions, keep generic recall description.

3. **Discovery section** — find references to `./sprint-orchestrator/sprints/` glob. Replace with `./runs/{sprint,qa-fix}/<id>/` (use the sprint-config or recall config to determine which workflow types to scan).

4. **KB integration section** — find references to `~/.zzem/kb/` and `$ZZEM_KB_PATH`. Replace with `${KB_PATH:-./.zachflow/kb}` and `${KB_PATH}` respectively (matching Sprint 1 convention).

5. **Domain enum logic** — find any code that validates `domain` against ZZEM hardcoded enum. Replace with regex check `^[a-z][a-z0-9-]*$` (matches reflection schema), or remove validation entirely (recall accepts any project-specific domain).

6. **Path examples in instructional text** — change ZZEM-style example IDs (e.g., `ai-webtoon-007`) to generic `<example-sprint-id>` or `example-sprint-001`.

7. **MCP tool name references** — `mcp__wrtn-mcp__*` KEEP (per master spec section 9 — these are user MCP tool names, customizable per project).

8. **Reference to upstream zzem-orchestrator** — replace with "the zachflow project root" or remove.

9. **Korean text** (rare in recall) — translate to English if found.

10. **Sources block in skill** — must align with the new YAML schema (`sources.runs` not `sources.sprints`).

Write the sanitized version to `~/dev/personal/zachflow/plugins/recall/ask/SKILL.md`.

- [ ] **Step 3.3: Verify frontmatter**

```bash
python3 -c "
import yaml
content = open('/Users/zachryu/dev/personal/zachflow/plugins/recall/ask/SKILL.md').read()
assert content.startswith('---')
end = content.find('---', 3)
fm = yaml.safe_load(content[3:end])
assert fm['name'] == 'recall:ask', f'wrong name: {fm[\"name\"]}'
print('frontmatter OK')
"
```

Expected: `frontmatter OK`.

- [ ] **Step 3.4: Verify ZZEM-leak scan**

```bash
grep -E 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb|\$ZZEM_KB_PATH|sprint-orchestrator/sprints' \
  ~/dev/personal/zachflow/plugins/recall/ask/SKILL.md
```

Expected: no output.

- [ ] **Step 3.5: Verify Korean text**

```bash
grep -P '[\x{AC00}-\x{D7A3}\x{1100}-\x{11FF}\x{3130}-\x{318F}]' \
  ~/dev/personal/zachflow/plugins/recall/ask/SKILL.md 2>/dev/null
```

Expected: no output.

- [ ] **Step 3.6: Verify references to new structure present**

```bash
grep -E 'runs/(sprint|qa-fix)|\${KB_PATH|zachflow-kb' \
  ~/dev/personal/zachflow/plugins/recall/ask/SKILL.md | head -10
```

Expected: ≥3 matches (each referenced at least once).

- [ ] **Step 3.7: Commit**

```bash
cd ~/dev/personal/zachflow
git add plugins/recall/ask/
git commit -m "feat(plugins): port recall:ask SKILL.md — sanitize for zachflow embedded KB + workflow-aware run discovery"
```

---

## Task 4: Write `scripts/install-plugins.sh`

**Files:**
- Create: `~/dev/personal/zachflow/scripts/install-plugins.sh`

- [ ] **Step 4.1: Write the script**

Use Write tool to create `~/dev/personal/zachflow/scripts/install-plugins.sh` with this EXACT content:

```bash
#!/usr/bin/env bash
# install-plugins.sh — opt-in installer for zachflow plugins.
#
# Usage:
#   bash scripts/install-plugins.sh recall              # install one plugin
#   bash scripts/install-plugins.sh recall foo bar      # install multiple
#   bash scripts/install-plugins.sh --list              # list available plugins
#   bash scripts/install-plugins.sh --help
#
# Each plugin must have plugins/<name>/scripts/install.sh which symlinks
# ~/.claude/skills/<name> -> $PROJECT_ROOT/plugins/<name>.
#
# Plugins are user-installable (system-wide via ~/.claude/), separate from
# zachflow workflows (project-bundled via .claude/skills/{sprint,qa-fix}).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ $# -eq 0 ]; then
  echo "Error: specify plugin name(s) or --list" >&2
  echo "Run with --help for usage." >&2
  exit 1
fi

if [ "$1" = "--list" ]; then
  echo "Available plugins:"
  for d in "$PROJECT_ROOT"/plugins/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    echo "  - $name"
  done
  exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit 0
fi

for plugin in "$@"; do
  PLUGIN_DIR="$PROJECT_ROOT/plugins/$plugin"
  if [ ! -d "$PLUGIN_DIR" ]; then
    echo "Error: plugin '$plugin' not found at $PLUGIN_DIR" >&2
    exit 1
  fi
  INSTALL_SH="$PLUGIN_DIR/scripts/install.sh"
  if [ ! -x "$INSTALL_SH" ]; then
    echo "Error: $INSTALL_SH not executable" >&2
    exit 1
  fi
  echo "Installing plugin: $plugin"
  bash "$INSTALL_SH"
done

echo
echo "Done. Plugins are now available system-wide via ~/.claude/skills/."
```

- [ ] **Step 4.2: Make executable + verify syntax**

```bash
chmod +x ~/dev/personal/zachflow/scripts/install-plugins.sh
bash -n ~/dev/personal/zachflow/scripts/install-plugins.sh && echo "syntax OK"
```

- [ ] **Step 4.3: Test --list**

```bash
bash ~/dev/personal/zachflow/scripts/install-plugins.sh --list
```

Expected: `Available plugins:` followed by `  - recall`.

- [ ] **Step 4.4: Test --help**

```bash
bash ~/dev/personal/zachflow/scripts/install-plugins.sh --help | head -5
```

Expected: comment header lines starting with `install-plugins.sh — opt-in installer...`.

- [ ] **Step 4.5: Test installing recall plugin**

```bash
bash ~/dev/personal/zachflow/scripts/install-plugins.sh recall
```

Expected: `Installing plugin: recall`, the plugin's install.sh runs, creates `~/.claude/skills/recall → ~/dev/personal/zachflow/plugins/recall` symlink. Final `Done.` line.

Verify symlink:

```bash
ls -la ~/.claude/skills/recall
[ -L ~/.claude/skills/recall ] && echo "symlink installed"
[ -f ~/.claude/skills/recall/ask/SKILL.md ] && echo "SKILL.md readable through symlink"
```

Expected: shows `recall -> /Users/zachryu/dev/personal/zachflow/plugins/recall` + 2 OK lines.

- [ ] **Step 4.6: Test idempotency**

```bash
bash ~/dev/personal/zachflow/scripts/install-plugins.sh recall
```

Expected: plugin's install.sh detects `already linked` (or similar), exits cleanly.

- [ ] **Step 4.7: Test error handling — unknown plugin**

```bash
bash ~/dev/personal/zachflow/scripts/install-plugins.sh nonexistent 2>&1 | head -3
```

Expected: error message `plugin 'nonexistent' not found at ...`, exit 1.

- [ ] **Step 4.8: Test recall plugin smoke (now that it's installed)**

```bash
bash ~/dev/personal/zachflow/plugins/recall/tests/test_config.sh
bash ~/dev/personal/zachflow/plugins/recall/tests/test_session.sh
```

Expected: both PASS (4 + 11 unit tests).

- [ ] **Step 4.9: Commit**

```bash
cd ~/dev/personal/zachflow
git add scripts/install-plugins.sh
git commit -m "feat(scripts): add install-plugins.sh opt-in plugin installer"
```

---

## Task 5: Write `docs/plugin-authoring.md`

**Files:**
- Create: `~/dev/personal/zachflow/docs/plugin-authoring.md`

- [ ] **Step 5.1: Write the doc**

Use Write tool to create `~/dev/personal/zachflow/docs/plugin-authoring.md` with this EXACT content:

```markdown
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
```

- [ ] **Step 5.2: Verify**

```bash
[ -s ~/dev/personal/zachflow/docs/plugin-authoring.md ] && echo "exists, non-empty"
lc=$(wc -l < ~/dev/personal/zachflow/docs/plugin-authoring.md)
echo "lines: $lc"
[ $lc -ge 120 ] && echo "size OK"

# Code fences balanced
fc=$(grep -c '^```' ~/dev/personal/zachflow/docs/plugin-authoring.md)
[ $((fc % 2)) -eq 0 ] && echo "fences balanced ($fc)"

# Verify references to recall plugin
grep -q "plugins/recall/" ~/dev/personal/zachflow/docs/plugin-authoring.md && echo "references recall plugin"
```

Expected: 4 OK lines.

- [ ] **Step 5.3: Commit**

```bash
cd ~/dev/personal/zachflow
git add docs/plugin-authoring.md
git commit -m "docs: add plugin-authoring.md v1.0 reference (mirror workflow-authoring.md quality)"
```

---

## Task 6: CI integration + roadmap.md update

**Files:**
- Modify: `~/dev/personal/zachflow/.github/workflows/ci.yml`
- Modify: `~/dev/personal/zachflow/docs/roadmap.md`

- [ ] **Step 6.1: Add plugin steps to ci.yml**

Read `~/dev/personal/zachflow/.github/workflows/ci.yml`. Find the existing `init-project.sh non-interactive smoke` step (Sprint 3 added). Add new steps AFTER it. Use Edit tool to insert:

```yaml
      - name: install-plugins.sh syntax check
        run: bash -n scripts/install-plugins.sh

      - name: recall plugin unit tests
        run: |
          bash plugins/recall/tests/test_config.sh
          bash plugins/recall/tests/test_session.sh
```

After Edit, verify YAML still parses:

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/ci.yml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 6.2: Update roadmap.md**

Read `~/dev/personal/zachflow/docs/roadmap.md`. Find the Sprint 4 line (current state):

```markdown
- [ ] Sprint 4 — `zachflow-gallery` package + `plugins/<name>/` pattern + first reference plugin (`plugins/recall/` ported from upstream PR #57) + `create-zachflow` npm wrapper + `docs/plugin-authoring.md` + LICENSE/CI/release
```

Use Edit tool to replace it with the 3-way split (per Sprint 4a design spec section 9):

```markdown
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [ ] Sprint 4b — `zachflow-gallery` package
- [ ] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release
```

- [ ] **Step 6.3: Verify roadmap edits**

```bash
grep "Sprint 4a" ~/dev/personal/zachflow/docs/roadmap.md
grep "Sprint 4b" ~/dev/personal/zachflow/docs/roadmap.md
grep "Sprint 4c" ~/dev/personal/zachflow/docs/roadmap.md
```

Expected: 3 matching lines, with Sprint 4a checked `[x]`, 4b/4c unchecked `[ ]`.

- [ ] **Step 6.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add .github/workflows/ci.yml docs/roadmap.md
git commit -m "feat(ci): add recall plugin tests + install-plugins syntax check; update roadmap for Sprint 4 split"
```

---

## Task 7: CHANGELOG + final smoke + v0.5.0-sprint-4a-plugins tag

**Files:**
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`

- [ ] **Step 7.1: Add Sprint 4a entry to CHANGELOG**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Find this line:

```markdown
## [0.4.0-sprint-3] — 2026-04-27
```

Use Edit tool to insert a new section ABOVE that line:

```markdown
## [0.5.0-sprint-4a-plugins] — 2026-04-27

### Added
- `plugins/<name>/` directory pattern formalized as the optional, user-installable counterpart to `workflows/<name>/` (project-bundled).
- `plugins/recall/` — first reference plugin, ported from upstream `zzem-orchestrator` PR #57 (11 files: README + ask/SKILL.md + 4 scripts + 2 config files + 3 tests).
- `scripts/install-plugins.sh` — opt-in plugin installer (`bash scripts/install-plugins.sh <name>`). Symlinks `~/.claude/skills/<name> → plugins/<name>` (user-level).
- `docs/plugin-authoring.md` — v1.0 plugin authoring guide with 10-step checklist + recall as worked example.
- CI integration: `install-plugins.sh syntax check` + `recall plugin unit tests` (15 tests) added to `.github/workflows/ci.yml`.

### Changed
- `recall.example.yaml` schema: `sources.sprints` → `sources.runs.{path, workflows: [sprint, qa-fix]}` (zachflow's Sprint 2 directory structure).
- `recall.example.yaml` KB: `~/.zzem/kb` (hardcoded) → `${KB_PATH:-./.zachflow/kb}` (env-var with embedded KB default).
- `recall.example.yaml` domain enum: removed hardcoded ZZEM enum; recall now accepts any project-specific domain matching `^[a-z][a-z0-9-]*$`.
- `recall.schema.json` `$id`: `https://zach-wrtn.github.io/...` → `https://zachflow.dev/...`.
- `ask/SKILL.md` path discovery: scans `runs/{sprint,qa-fix}/<id>/` instead of `./sprint-orchestrator/sprints/`.
- `docs/roadmap.md` Sprint 4 entry split into 4a (this sprint, complete) / 4b (gallery) / 4c (create-zachflow + v1.0 release).

### Notes
- Plugin install is **explicit** (user runs `bash scripts/install-plugins.sh recall`) — distinct from workflows which install automatically via `scripts/install-workflows.sh`.
- Plugin namespace: skills inside a plugin use `<plugin>:<skill>` frontmatter (e.g., `recall:ask`). Avoids collision with core skill names.
- Core does NOT depend on plugins. zachflow workflows + KB work without any plugin installed.

### Deferred to Sprint 4b/4c

- `zachflow-gallery` package — Sprint 4b
- `create-zachflow` npm wrapper — Sprint 4c
- README/CONTRIBUTING/v1.0 release polish — Sprint 4c
- v1.0.0 final tag — Sprint 4c

## [0.4.0-sprint-3] — 2026-04-27
```

- [ ] **Step 7.2: End-to-end smoke**

```bash
cd ~/dev/personal/zachflow

# 1. install-workflows idempotent (Sprint 2)
bash scripts/install-workflows.sh

# 2. KB smoke (Sprint 1)
bash tests/kb-smoke.sh

# 3. init-project smoke (Sprint 3)
bash tests/init-project-smoke.sh

# 4. install-plugins syntax + list
bash -n scripts/install-plugins.sh && echo "install-plugins.sh syntax OK"
bash scripts/install-plugins.sh --list | head -3

# 5. Plugin tests
bash plugins/recall/tests/test_config.sh
bash plugins/recall/tests/test_session.sh

# 6. ZZEM-leak with current exclusions
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.zachflow \
  --exclude-dir=docs/superpowers \
  --exclude='CHANGELOG.md' \
  --exclude='docs/roadmap.md' \
  --exclude='docs/llm-platform-coupling.md' \
  --exclude='docs/kb-system.md' \
  --exclude='.github/workflows/ci.yml' \
  . > /dev/null && echo "leak scan FAIL" || echo "leak scan PASS"

# 7. Bash syntax all
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh plugins/*/scripts/*.sh plugins/*/tests/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 8. Verify new files
[ -d plugins/recall ] && echo "plugins/recall/ exists"
[ -f scripts/install-plugins.sh ] && echo "install-plugins.sh exists"
[ -f docs/plugin-authoring.md ] && echo "plugin-authoring.md exists"

# 9. Plugin file count
plugin_count=$(find plugins/recall -type f -not -name '.gitkeep' | wc -l | tr -d ' ')
echo "plugins/recall/ files: $plugin_count (expected 11)"

# 10. Symlink installed (from earlier Task 4 manual install)
[ -L ~/.claude/skills/recall ] && echo "recall symlink installed"
```

Expected: all OK lines, no FAIL. Plugin file count = 11 (README + SKILL.md + 4 scripts + 2 config + 3 tests).

- [ ] **Step 7.3: Final git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: only CHANGELOG.md modified (staged).

- [ ] **Step 7.4: Commit CHANGELOG**

```bash
cd ~/dev/personal/zachflow
git add CHANGELOG.md
git commit -m "docs(changelog): Sprint 4a — plugins + recall port (0.5.0-sprint-4a-plugins)"
```

- [ ] **Step 7.5: Tag v0.5.0-sprint-4a-plugins**

```bash
cd ~/dev/personal/zachflow
git tag -a v0.5.0-sprint-4a-plugins -m "Sprint 4a — plugins + recall port complete (plugins/<name>/ pattern + recall plugin + install-plugins.sh + plugin-authoring.md + CI)"
git tag -l --format='%(refname:short) - %(subject)' | tail -5
```

Expected: 5 tags listed (v0.1.0-bootstrap, v0.2.0-sprint-1, v0.3.0-sprint-2, v0.4.0-sprint-3, v0.5.0-sprint-4a-plugins).

- [ ] **Step 7.6: Final commit history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -10
git rev-list --count v0.4.0-sprint-3..HEAD
```

Expected: ~7-9 new commits since v0.4.0-sprint-3.

---

## Sprint 4a Done Criteria

- [ ] `plugins/recall/` has 11 files (README + ask/SKILL.md + 4 scripts + 2 config + 3 tests)
- [ ] `plugins/recall/ask/SKILL.md` frontmatter `name: recall:ask` valid
- [ ] `plugins/recall/config/recall.example.yaml` valid YAML, uses `sources.runs.workflows`, `${KB_PATH:-./.zachflow/kb}`, no domain_enum
- [ ] `plugins/recall/config/recall.schema.json` valid JSON Schema draft 2020-12, `$id` at zachflow.dev
- [ ] `bash scripts/install-plugins.sh recall` works + idempotent
- [ ] `~/.claude/skills/recall` symlink to `plugins/recall` after install
- [ ] `bash plugins/recall/tests/test_config.sh` PASS (4 tests)
- [ ] `bash plugins/recall/tests/test_session.sh` PASS (11 tests)
- [ ] `scripts/install-plugins.sh --list` shows `recall`
- [ ] `scripts/install-plugins.sh --help` shows usage
- [ ] `docs/plugin-authoring.md` ≥120 lines, references recall
- [ ] `docs/roadmap.md` Sprint 4a checked, 4b/4c added unchecked
- [ ] CI workflow has install-plugins syntax + recall plugin tests
- [ ] CHANGELOG.md `[0.5.0-sprint-4a-plugins]` entry
- [ ] Tag `v0.5.0-sprint-4a-plugins`
- [ ] No ZZEM-leak in plugins/ (existing scan passes)
- [ ] No Korean residue in plugins/
- [ ] Working tree clean

---

## Notes for Sprint 4b/4c

- **Sprint 4b** (`zachflow-gallery`) — Astro app + empty content slots. Independent of plugins. Different domain knowledge (frontend/Astro).
- **Sprint 4c** (`create-zachflow` + v1.0 release) — npm wrapper + README/CONTRIBUTING polish + v1.0.0 final tag. Depends on Sprint 4b being done so v1.0 release includes gallery.

The `plugins/<name>/` pattern (this sprint) is a foundation that future plugins (Notion sync, etc.) follow without further architectural work.
