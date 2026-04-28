# Sprint 3 — Stack Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `scripts/init-project.sh` interactive wizard + `templates/teammates/*.template.md` canonical location, enabling new zachflow users to bootstrap a project from clone in ≤5 minutes.

**Architecture:** Hybrid wizard — interactive bash by default, `--from=init.config.yaml --non-interactive` for CI/scripted setup. Templates live in two places: `templates/teammates/*.template.md` (canonical, shared with future `create-zachflow` npm wrapper) and `.claude/teammates/*.md` (Claude Code's pickup location, either Sprint 0 placeholders OR wizard fills). Wizard reads templates, prompts user, writes filled output to `.claude/teammates/`. Sprint-config.yaml + KB initialization (`bash scripts/kb-bootstrap.sh`) + workflow symlink installation (`bash scripts/install-workflows.sh`) are the wizard's other outputs. Non-interactive YAML schema mirrors interactive prompt structure 1:1.

**Tech Stack:** bash 5+ (wizard, smoke), Python 3.11+ (system default — used in non-interactive mode for YAML parsing via `python3 -c "import yaml; ..."`).

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-3-stack-adapter-design.md` (commit `8ccd310`). Read sections 1 (directory layout), 2 (interaction model), 3 (templates location), 4 (7 wizard steps), 5 (idempotency), 6 (init.config template), 7-8 (docs updates), 9 (CI) before starting.

---

## File Structure (Sprint 3 output additions/changes)

```
~/dev/personal/zachflow/
├── scripts/
│   └── init-project.sh                   # NEW (~280 lines bash wizard)
│
├── templates/
│   ├── teammates/                        # NEW directory
│   │   ├── be-engineer.template.md       # NEW (copy of .claude/teammates/be-engineer.md)
│   │   ├── fe-engineer.template.md       # NEW (copy of .claude/teammates/fe-engineer.md)
│   │   ├── design-engineer.template.md   # NEW (copy of .claude/teammates/design-engineer.md)
│   │   └── evaluator.template.md         # NEW (copy of .claude/teammates/evaluator.md)
│   └── init.config.template.yaml         # NEW (annotated example for non-interactive mode)
│
├── tests/
│   └── init-project-smoke.sh             # NEW (CI smoke for non-interactive wizard)
│
├── examples/
│   └── README.md                         # MODIFIED (add wizard usage)
│
├── MANUAL.md                             # MODIFIED (Setup section filled)
├── CHANGELOG.md                          # MODIFIED ([0.4.0-sprint-3] entry)
└── .github/workflows/ci.yml              # MODIFIED (init-project syntax + smoke steps)
```

---

## Task 1: Copy `.claude/teammates/*.md` → `templates/teammates/*.template.md`

**Files:**
- Create: `~/dev/personal/zachflow/templates/teammates/be-engineer.template.md`
- Create: `~/dev/personal/zachflow/templates/teammates/fe-engineer.template.md`
- Create: `~/dev/personal/zachflow/templates/teammates/design-engineer.template.md`
- Create: `~/dev/personal/zachflow/templates/teammates/evaluator.template.md`

These are **copies** (not moves). `.claude/teammates/*.md` stays as Sprint 0 placeholder defaults (clone-and-go UX). The new `templates/teammates/*.template.md` files are byte-identical at Sprint 3 start time, becoming canonical templates the wizard reads from.

- [ ] **Step 1.1: Create directory**

```bash
mkdir -p ~/dev/personal/zachflow/templates/teammates
```

- [ ] **Step 1.2: Copy 4 teammate files**

```bash
cp ~/dev/personal/zachflow/.claude/teammates/be-engineer.md      ~/dev/personal/zachflow/templates/teammates/be-engineer.template.md
cp ~/dev/personal/zachflow/.claude/teammates/fe-engineer.md      ~/dev/personal/zachflow/templates/teammates/fe-engineer.template.md
cp ~/dev/personal/zachflow/.claude/teammates/design-engineer.md  ~/dev/personal/zachflow/templates/teammates/design-engineer.template.md
cp ~/dev/personal/zachflow/.claude/teammates/evaluator.md        ~/dev/personal/zachflow/templates/teammates/evaluator.template.md
```

- [ ] **Step 1.3: Verify byte-identical**

```bash
for name in be-engineer fe-engineer design-engineer evaluator; do
  src=~/dev/personal/zachflow/.claude/teammates/$name.md
  dst=~/dev/personal/zachflow/templates/teammates/$name.template.md
  if cmp -s "$src" "$dst"; then echo "OK: $name"; else echo "FAIL: $name"; fi
done
```

Expected: 4 OK lines.

- [ ] **Step 1.4: Verify placeholder markers present in templates**

```bash
for f in ~/dev/personal/zachflow/templates/teammates/{be-engineer,fe-engineer}.template.md; do
  count=$(grep -cE '\{\{[A-Z_]+\}\}' "$f")
  echo "$(basename $f): $count placeholders"
done
```

Expected: BE/FE files show ≥4 placeholders each (matching Sprint 0 Task 5 output).

- [ ] **Step 1.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add templates/teammates/
git commit -m "feat(templates): add canonical teammates/ template directory"
```

---

## Task 2: Write `templates/init.config.template.yaml`

**Files:**
- Create: `~/dev/personal/zachflow/templates/init.config.template.yaml`

- [ ] **Step 2.1: Write the template**

Use Write tool to create `~/dev/personal/zachflow/templates/init.config.template.yaml` with this EXACT content:

```yaml
# templates/init.config.template.yaml
# zachflow non-interactive init config
#
# Usage:
#   cp templates/init.config.template.yaml init.config.yaml
#   # Edit init.config.yaml with your project specifics
#   bash scripts/init-project.sh --from=init.config.yaml --non-interactive
#
# All fields are required unless marked optional.
# String patterns: lowercase-hyphen unless noted.

# ─── Project metadata ────────────────────────────────────────────
project_name: my-project           # ^[a-z][a-z0-9-]*$, 3+ chars
workflows: both                    # one of: sprint | qa-fix | both
branch_prefix: sprint              # ^[a-z][a-z0-9-]*$ (default 'run' if both, 'sprint' if sprint-only, 'qa' if qa-fix-only)

# ─── Role definitions (≥1 required) ──────────────────────────────
# Each role becomes a directory in {sprint-worktree}/{role-key}/ via
# scripts/setup-sprint.sh. The 'teammate' field selects which template
# from templates/teammates/ to fill for this role.

roles:
  - key: backend                          # role key (used as directory name and tasks/{role}/ prefix)
    source: ~/dev/work/<your-be-repo>     # absolute path or ~ to your repo on disk
    base: main                            # base branch for sprint runs
    mode: worktree                        # one of: worktree | symlink
    teammate: be-engineer                 # one of: be-engineer | fe-engineer | design-engineer | evaluator
    fill:                                 # optional — omit any field to leave its {{...}} marker as-is
      stack_description: |
        Describe your backend stack here in 1-2 sentences (framework, language, key dependencies).
      repo_layout: |
        Brief description of top-level directory structure (3-5 lines).
      build_cmd: |
        # Commands to verify implementation
        npm install
        npm run typecheck
        npm test
      conventions: |
        - Convention 1 specific to this codebase
        - Convention 2
        - Convention 3

  # Uncomment to add a frontend role:
  # - key: app
  #   source: ~/dev/work/<your-fe-repo>
  #   base: main
  #   mode: worktree
  #   teammate: fe-engineer
  #   fill:
  #     stack_description: |
  #       React Native + TypeScript app...
  #     repo_layout: |
  #       src/...
  #     build_cmd: |
  #       npm install
  #       npm run lint
  #       npm test
  #     conventions: |
  #       - Use functional components only
  #       - ...

# ─── KB configuration ────────────────────────────────────────────
kb:
  mode: embedded                   # only 'embedded' supported in v1.0; 'remote' coming v1.1
init_kb: true                      # bool — run scripts/kb-bootstrap.sh after wizard
```

- [ ] **Step 2.2: Verify valid YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/templates/init.config.template.yaml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 2.3: Verify required fields are present in template**

```bash
python3 -c "
import yaml
data = yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/templates/init.config.template.yaml'))
for k in ['project_name', 'workflows', 'branch_prefix', 'roles', 'kb', 'init_kb']:
  assert k in data, 'missing: ' + k
assert len(data['roles']) >= 1
role = data['roles'][0]
for k in ['key', 'source', 'base', 'mode', 'teammate']:
  assert k in role, 'role missing: ' + k
print('template structure OK')
"
```

Expected: `template structure OK`.

- [ ] **Step 2.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add templates/init.config.template.yaml
git commit -m "feat(templates): add init.config.template.yaml for non-interactive wizard"
```

---

## Task 3: Write `scripts/init-project.sh` wizard

**Files:**
- Create: `~/dev/personal/zachflow/scripts/init-project.sh` (~280 lines bash, executable)

The wizard's full content is provided below. The implementer writes it verbatim, makes it executable, then verifies.

- [ ] **Step 3.1: Write the wizard**

Use Write tool to create `~/dev/personal/zachflow/scripts/init-project.sh` with this EXACT content:

```bash
#!/usr/bin/env bash
# init-project.sh — zachflow project initialization wizard.
#
# Modes:
#   bash scripts/init-project.sh                            # interactive (default)
#   bash scripts/init-project.sh --from=init.config.yaml --non-interactive
#   bash scripts/init-project.sh --force                    # skip overwrite confirmations
#
# Outputs:
#   sprint-config.yaml                       (project root)
#   .claude/teammates/<teammate>.md          (filled from templates/teammates/<teammate>.template.md)
#   .zachflow/kb/                            (initialized via scripts/kb-bootstrap.sh)
#   .claude/skills/{sprint,qa-fix}           (symlinks installed via scripts/install-workflows.sh)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ─── Argument parsing ─────────────────────────────────────────────

NON_INTERACTIVE=0
FROM_CONFIG=""
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive)        NON_INTERACTIVE=1; shift ;;
    --from=*)                 FROM_CONFIG="${1#*=}"; shift ;;
    --force)                  FORCE=1; shift ;;
    -h|--help)
      grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ─── Sanity check (must run from zachflow project root) ──────────

if [ ! -f "scripts/install-workflows.sh" ] || [ ! -d "workflows" ] || [ ! -d "templates/teammates" ]; then
  echo "Error: must run from a zachflow project root (scripts/install-workflows.sh, workflows/, and templates/teammates/ required)" >&2
  exit 1
fi

# ─── Helpers ─────────────────────────────────────────────────────

prompt() {
  # prompt VARNAME "label" [default]
  local var="$1" label="$2" default="${3:-}"
  local prompt_str="$label"
  [ -n "$default" ] && prompt_str+=" [$default]"
  prompt_str+=": "
  local input
  read -r -p "$prompt_str" input
  if [ -z "$input" ]; then
    eval "$var=\"\$default\""
  else
    eval "$var=\"\$input\""
  fi
}

prompt_required() {
  # prompt_required VARNAME "label" "validate-pattern" "error-msg"
  local var="$1" label="$2" pattern="$3" errmsg="$4"
  local val=""
  while true; do
    read -r -p "$label: " val
    if [ -z "$val" ]; then
      echo "  Required. $errmsg" >&2
      continue
    fi
    if [ -n "$pattern" ] && ! [[ "$val" =~ $pattern ]]; then
      echo "  Invalid. $errmsg" >&2
      continue
    fi
    break
  done
  eval "$var=\"\$val\""
}

confirm() {
  # confirm "question" [default y|n]
  local q="$1" default="${2:-y}"
  local input
  read -r -p "$q (y/n) [$default]: " input
  input="${input:-$default}"
  [ "$input" = "y" ] || [ "$input" = "Y" ]
}

# Load YAML field via python3 — usage: yaml_get FILE KEY [DEFAULT]
yaml_get() {
  python3 -c "
import yaml, sys
data = yaml.safe_load(open('$1'))
keys = '$2'.split('.')
for k in keys:
    if data is None or not isinstance(data, dict) or k not in data:
        print('${3:-}')
        sys.exit(0)
    data = data[k]
if data is None: print('${3:-}')
elif isinstance(data, bool): print('true' if data else 'false')
else: print(data)
"
}

# Load roles list as JSON-ish lines via python3 — usage: yaml_roles FILE
yaml_roles() {
  python3 -c "
import yaml, json
data = yaml.safe_load(open('$1'))
for role in data.get('roles', []):
    fill = role.get('fill', {}) or {}
    print('|'.join([
        role.get('key', ''),
        role.get('source', ''),
        role.get('base', 'main'),
        role.get('mode', 'worktree'),
        role.get('teammate', 'be-engineer'),
        json.dumps(fill).replace('|', '__PIPE__'),
    ]))
"
}

# ─── State variables ─────────────────────────────────────────────

PROJECT_NAME=""
WORKFLOWS=""
BRANCH_PREFIX=""
ROLES=()           # array of "key|source|base|mode|teammate|fill_json"
KB_MODE=""
INIT_KB=""

# ─── Mode 1: Non-interactive (load from YAML) ────────────────────

if [ $NON_INTERACTIVE -eq 1 ]; then
  [ -z "$FROM_CONFIG" ] && { echo "Error: --non-interactive requires --from=<file>" >&2; exit 1; }
  [ ! -f "$FROM_CONFIG" ] && { echo "Error: $FROM_CONFIG not found" >&2; exit 1; }

  echo "zachflow init (non-interactive): loading from $FROM_CONFIG"

  PROJECT_NAME=$(yaml_get "$FROM_CONFIG" project_name)
  WORKFLOWS=$(yaml_get "$FROM_CONFIG" workflows both)
  BRANCH_PREFIX=$(yaml_get "$FROM_CONFIG" branch_prefix run)
  KB_MODE=$(yaml_get "$FROM_CONFIG" kb.mode embedded)
  INIT_KB=$(yaml_get "$FROM_CONFIG" init_kb true)

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ROLES+=("$line")
  done < <(yaml_roles "$FROM_CONFIG")

  [ -z "$PROJECT_NAME" ] && { echo "Error: project_name required in $FROM_CONFIG" >&2; exit 1; }
  [ ${#ROLES[@]} -eq 0 ] && { echo "Error: at least one role required in $FROM_CONFIG" >&2; exit 1; }

# ─── Mode 2: Interactive ──────────────────────────────────────────

else
  echo "zachflow init wizard v1.0"
  echo "─────────────────────────"
  echo

  # Step 1: Project name
  prompt_required PROJECT_NAME "[1/7] Project name (lowercase-hyphen, 3+ chars)" '^[a-z][a-z0-9-]{2,}$' "Use lowercase letters, digits, hyphens. Must start with letter."

  # Step 2: Workflows
  while true; do
    prompt WORKFLOWS "[2/7] Activate workflows (sprint/qa-fix/both)" "both"
    case "$WORKFLOWS" in
      sprint|qa-fix|both) break ;;
      *) echo "  Must be one of: sprint, qa-fix, both" >&2 ;;
    esac
  done

  # Step 3: Branch prefix
  default_prefix="run"
  [ "$WORKFLOWS" = "sprint" ] && default_prefix="sprint"
  [ "$WORKFLOWS" = "qa-fix" ] && default_prefix="qa"
  while true; do
    prompt BRANCH_PREFIX "[3/7] Branch prefix" "$default_prefix"
    [[ "$BRANCH_PREFIX" =~ ^[a-z][a-z0-9-]*$ ]] && break
    echo "  Must be lowercase-hyphen starting with letter" >&2
  done

  # Step 4: Role definitions (loop)
  echo
  echo "[4/7] Role definitions (define ≥1 role)"
  while true; do
    if [ ${#ROLES[@]} -eq 0 ]; then
      add="y"
    else
      read -r -p "  Add another role? (y/n) [n]: " add; add="${add:-n}"
    fi
    [ "$add" != "y" ] && [ "$add" != "Y" ] && break

    role_key=""; role_source=""; role_base=""; role_mode=""; role_teammate=""
    prompt_required role_key "  Role key (e.g., backend, app)" '^[a-z][a-z0-9-]*$' "lowercase-hyphen"
    prompt_required role_source "  Source repo path (~/dev/...)" '' "non-empty"
    prompt role_base "  Base branch" "main"
    while true; do
      prompt role_mode "  Mode (worktree/symlink)" "worktree"
      case "$role_mode" in
        worktree|symlink) break ;;
        *) echo "    Must be 'worktree' or 'symlink'" >&2 ;;
      esac
    done
    while true; do
      prompt role_teammate "  Teammate template (be-engineer/fe-engineer/design-engineer/evaluator)" "be-engineer"
      case "$role_teammate" in
        be-engineer|fe-engineer|design-engineer|evaluator) break ;;
        *) echo "    Must be one of the 4 teammate names" >&2 ;;
      esac
    done

    ROLES+=("$role_key|$role_source|$role_base|$role_mode|$role_teammate|{}")
  done

  [ ${#ROLES[@]} -eq 0 ] && { echo "Error: at least 1 role required" >&2; exit 1; }

  # Step 5: Teammate placeholder fill
  echo
  if confirm "[5/7] Fill teammate placeholders interactively?" "y"; then
    NEW_ROLES=()
    for role_entry in "${ROLES[@]}"; do
      IFS='|' read -ra parts <<< "$role_entry"
      role_key="${parts[0]}"
      teammate="${parts[4]}"
      echo "  For role '$role_key' ($teammate):"
      stack_desc=""; repo_layout=""; build_cmd=""; conventions=""
      prompt stack_desc "    Stack description (1 line, blank to skip)" ""
      prompt repo_layout "    Repository layout summary (1 line, blank to skip)" ""
      prompt build_cmd "    Build & test commands (1 line, blank to skip)" ""
      prompt conventions "    Conventions summary (1 line, blank to skip)" ""

      # Build fill JSON
      fill_json=$(python3 -c "
import json
print(json.dumps({
    'stack_description': '''$stack_desc''',
    'repo_layout': '''$repo_layout''',
    'build_cmd': '''$build_cmd''',
    'conventions': '''$conventions''',
}).replace('|', '__PIPE__'))
")
      NEW_ROLES+=("${parts[0]}|${parts[1]}|${parts[2]}|${parts[3]}|${parts[4]}|$fill_json")
    done
    ROLES=("${NEW_ROLES[@]}")
  fi

  # Step 6: KB mode
  echo
  echo "[6/7] KB mode (embedded only in v1.0; remote coming v1.1)"
  prompt KB_MODE "  Mode" "embedded"
  if [ "$KB_MODE" != "embedded" ]; then
    echo "  Warning: only 'embedded' is supported in v1.0; setting to 'embedded'"
    KB_MODE="embedded"
  fi

  # Step 7: Init KB
  echo
  if confirm "[7/7] Initialize KB at .zachflow/kb/?" "y"; then
    INIT_KB="true"
  else
    INIT_KB="false"
  fi
fi

# ─── Summary + Confirm ────────────────────────────────────────────

echo
echo "─────────────────────────"
echo "Summary:"
echo "  - Project: $PROJECT_NAME"
echo "  - Workflows: $WORKFLOWS"
echo "  - Branch prefix: $BRANCH_PREFIX"
echo "  - Roles: ${#ROLES[@]}"
for role_entry in "${ROLES[@]}"; do
  IFS='|' read -ra parts <<< "$role_entry"
  echo "      - ${parts[0]} (source=${parts[1]}, mode=${parts[3]}, teammate=${parts[4]})"
done
echo "  - KB mode: $KB_MODE"
echo "  - Init KB: $INIT_KB"
echo "─────────────────────────"

if [ $NON_INTERACTIVE -eq 0 ]; then
  if ! confirm "Confirm and write?" "y"; then
    echo "Aborted."
    exit 1
  fi
fi

# ─── Idempotency: warn on existing sprint-config.yaml ─────────────

if [ -f "sprint-config.yaml" ]; then
  if [ $FORCE -eq 0 ]; then
    if [ $NON_INTERACTIVE -eq 1 ]; then
      echo "Error: sprint-config.yaml exists and --force not set; refusing to overwrite" >&2
      exit 1
    fi
    if ! confirm "sprint-config.yaml exists. Overwrite?" "n"; then
      echo "Aborted."
      exit 1
    fi
  fi
fi

# ─── Write sprint-config.yaml ─────────────────────────────────────

{
  echo "# sprint-config.yaml — generated by scripts/init-project.sh"
  echo "# Edit freely; this is your project's source of truth for runs."
  echo
  echo "project_name: $PROJECT_NAME"
  echo "workflows: $WORKFLOWS"
  echo "branch_prefix: $BRANCH_PREFIX"
  echo
  echo "repositories:"
  for role_entry in "${ROLES[@]}"; do
    IFS='|' read -ra parts <<< "$role_entry"
    echo "  ${parts[0]}:"
    echo "    source: ${parts[1]}"
    echo "    base: ${parts[2]}"
    echo "    mode: ${parts[3]}"
  done
  echo
  echo "kb:"
  echo "  mode: $KB_MODE"
} > sprint-config.yaml

echo "wrote: sprint-config.yaml"

# ─── Fill teammate templates ──────────────────────────────────────

# For each unique teammate (across all roles), find the highest-priority fill data
# (last role wins if multiple roles use the same teammate template) and write to .claude/teammates/

declare -A teammate_fill_map  # teammate-name -> fill_json
for role_entry in "${ROLES[@]}"; do
  IFS='|' read -ra parts <<< "$role_entry"
  teammate="${parts[4]}"
  fill_json="${parts[5]:-{}}"
  fill_json="${fill_json//__PIPE__/|}"
  teammate_fill_map["$teammate"]="$fill_json"
done

for teammate in "${!teammate_fill_map[@]}"; do
  fill_json="${teammate_fill_map[$teammate]}"
  template_file="templates/teammates/$teammate.template.md"
  output_file=".claude/teammates/$teammate.md"

  if [ ! -f "$template_file" ]; then
    echo "Warning: template $template_file not found; skipping" >&2
    continue
  fi

  # Re-run detection: existing wizard-fill marker?
  if [ -f "$output_file" ] && grep -q "<!-- zachflow init-project.sh wizard fill" "$output_file"; then
    if [ $FORCE -eq 0 ] && [ $NON_INTERACTIVE -eq 0 ]; then
      if ! confirm "$output_file was previously filled by wizard. Overwrite?" "n"; then
        echo "  skipping: $output_file"
        continue
      fi
    fi
  fi

  python3 - <<PYEOF
import json, re, sys
fill = json.loads('''$fill_json''')
template = open('$template_file').read()

substitutions = {
    'STACK_DESCRIPTION': fill.get('stack_description', '').strip(),
    'REPO_LAYOUT': fill.get('repo_layout', '').strip(),
    'BUILD_CMD': fill.get('build_cmd', '').strip(),
    'CONVENTIONS': fill.get('conventions', '').strip(),
}

output = template
for key, value in substitutions.items():
    if value:
        output = output.replace('{{' + key + '}}', value)

# Prepend fill marker
import datetime
now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')
marker = f"<!-- zachflow init-project.sh wizard fill — {now} -->\n"
output = marker + output

open('$output_file', 'w').write(output)
print(f"wrote: $output_file")
PYEOF
done

# ─── Initialize KB ────────────────────────────────────────────────

if [ "$INIT_KB" = "true" ] || [ "$INIT_KB" = "y" ]; then
  echo
  bash scripts/kb-bootstrap.sh
fi

# ─── Install workflow symlinks ────────────────────────────────────

echo
bash scripts/install-workflows.sh

# ─── Done ─────────────────────────────────────────────────────────

echo
echo "─────────────────────────"
echo "zachflow init complete."
echo
echo "Next:"
case "$WORKFLOWS" in
  sprint|both)
    echo "  /sprint <run-id>                          # start a sprint"
    ;;
esac
case "$WORKFLOWS" in
  qa-fix|both)
    echo "  /qa-fix <run-id> --jql=\"...\"             # run QA fix loop"
    ;;
esac
echo
echo "Edit teammate guides at .claude/teammates/<name>.md to refine stack details."
echo "─────────────────────────"
```

- [ ] **Step 3.2: Make executable**

```bash
chmod +x ~/dev/personal/zachflow/scripts/init-project.sh
```

- [ ] **Step 3.3: Verify bash syntax**

```bash
bash -n ~/dev/personal/zachflow/scripts/init-project.sh && echo "syntax OK"
```

Expected: `syntax OK`.

- [ ] **Step 3.4: Verify --help works**

```bash
bash ~/dev/personal/zachflow/scripts/init-project.sh --help | head -5
```

Expected: comment lines from script header (the help output is grep + sed of `# ...` comments).

- [ ] **Step 3.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add scripts/init-project.sh
git commit -m "feat(scripts): add init-project.sh interactive + non-interactive wizard"
```

---

## Task 4: Write `tests/init-project-smoke.sh` + CI integration

**Files:**
- Create: `~/dev/personal/zachflow/tests/init-project-smoke.sh`
- Modify: `~/dev/personal/zachflow/.github/workflows/ci.yml`

The smoke test exercises non-interactive mode in a temporary directory using a fixture init.config.yaml.

- [ ] **Step 4.1: Write the smoke script**

Use Write tool to create `~/dev/personal/zachflow/tests/init-project-smoke.sh` with this EXACT content:

```bash
#!/usr/bin/env bash
# init-project-smoke.sh — non-interactive smoke test for scripts/init-project.sh
#
# Creates a fixture init.config.yaml, runs the wizard non-interactively in a
# temporary copy of the project, and verifies the outputs exist and parse.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "init-project smoke at: $PROJECT_ROOT"

TMPDIR=$(mktemp -d -t zachflow-init-smoke-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# 1. Copy project tree to temp dir (excluding .git, .zachflow, node_modules)
echo "  [1/5] Stage project copy at $TMPDIR"
rsync -a --exclude='.git/' --exclude='.zachflow/' --exclude='node_modules/' \
      "${PROJECT_ROOT}/" "${TMPDIR}/"

cd "$TMPDIR"

# 2. Write fixture init.config.yaml
cat > init.config.yaml <<'EOF'
project_name: smoke-test
workflows: both
branch_prefix: sprint
roles:
  - key: backend
    source: /tmp/fake-backend
    base: main
    mode: worktree
    teammate: be-engineer
    fill:
      stack_description: |
        Smoke test backend.
      repo_layout: |
        src/
      build_cmd: |
        echo build
      conventions: |
        - Smoke convention
kb:
  mode: embedded
init_kb: false
EOF

# 3. Run wizard non-interactively
echo "  [2/5] Run init-project.sh --non-interactive"
bash scripts/init-project.sh --from=init.config.yaml --non-interactive --force > /tmp/wizard-output.log 2>&1 || {
  echo "FAIL: wizard exited non-zero"
  cat /tmp/wizard-output.log
  exit 1
}

# 4. Verify outputs
echo "  [3/5] Verify sprint-config.yaml"
[ -f sprint-config.yaml ] || { echo "FAIL: sprint-config.yaml not created"; exit 1; }
python3 -c "
import yaml
data = yaml.safe_load(open('sprint-config.yaml'))
assert data['project_name'] == 'smoke-test', f'got {data[\"project_name\"]}'
assert data['workflows'] == 'both'
assert data['branch_prefix'] == 'sprint'
assert 'backend' in data['repositories']
assert data['repositories']['backend']['mode'] == 'worktree'
assert data['kb']['mode'] == 'embedded'
print('    sprint-config.yaml OK')
"

echo "  [4/5] Verify .claude/teammates/be-engineer.md fill"
[ -f .claude/teammates/be-engineer.md ] || { echo "FAIL: be-engineer.md not created"; exit 1; }
grep -q "wizard fill" .claude/teammates/be-engineer.md || { echo "FAIL: marker missing"; exit 1; }
grep -q "Smoke test backend" .claude/teammates/be-engineer.md || { echo "FAIL: stack_description not substituted"; exit 1; }
echo "    be-engineer.md OK (marker present, stack filled)"

echo "  [5/5] Verify symlinks were installed"
[ -L .claude/skills/sprint ] || { echo "FAIL: sprint symlink missing"; exit 1; }
[ -L .claude/skills/qa-fix ] || { echo "FAIL: qa-fix symlink missing"; exit 1; }
echo "    symlinks OK"

echo
echo "PASS: init-project smoke check"
```

- [ ] **Step 4.2: Make executable + verify syntax**

```bash
chmod +x ~/dev/personal/zachflow/tests/init-project-smoke.sh
bash -n ~/dev/personal/zachflow/tests/init-project-smoke.sh && echo "syntax OK"
```

Expected: `syntax OK`.

- [ ] **Step 4.3: Run smoke locally**

```bash
bash ~/dev/personal/zachflow/tests/init-project-smoke.sh
```

Expected output ending with `PASS: init-project smoke check`.

- [ ] **Step 4.4: Add init-project steps to ci.yml**

Read `~/dev/personal/zachflow/.github/workflows/ci.yml`. After the existing `KB smoke check` step, add two new steps. Use Edit to insert these:

```yaml
      - name: init-project.sh syntax check
        run: bash -n scripts/init-project.sh

      - name: init-project.sh non-interactive smoke
        run: bash tests/init-project-smoke.sh
```

After Edit, verify YAML still parses:

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/ci.yml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 4.5: Commit**

```bash
cd ~/dev/personal/zachflow
git add tests/init-project-smoke.sh .github/workflows/ci.yml
git commit -m "feat(ci): add init-project.sh smoke test"
```

---

## Task 5: Update `examples/README.md` + `MANUAL.md`

**Files:**
- Modify: `~/dev/personal/zachflow/examples/README.md`
- Modify: `~/dev/personal/zachflow/MANUAL.md`

- [ ] **Step 5.1: Replace `examples/README.md`**

Read current content first. Then use Write to overwrite with this exact content:

```markdown
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
```

- [ ] **Step 5.2: Update MANUAL.md Setup section**

Read `~/dev/personal/zachflow/MANUAL.md`. Find the existing `## Setup (preview)` section (Sprint 0 stub). Use Edit to replace that section's body with the expanded content. The section header changes from "Setup (preview)" to "Setup".

Find this exact block:

```markdown
## Setup (preview)

```bash
npx create-zachflow my-project   # Sprint 4
cd my-project
./scripts/init-project.sh        # Sprint 3 — interactive wizard
```
```

Replace with:

```markdown
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
```

- [ ] **Step 5.3: Verify both files**

```bash
[ -s ~/dev/personal/zachflow/examples/README.md ] && head -1 ~/dev/personal/zachflow/examples/README.md
grep -q "init-project.sh" ~/dev/personal/zachflow/examples/README.md && echo "examples/README.md OK"

grep -q "## Setup$" ~/dev/personal/zachflow/MANUAL.md && echo "MANUAL.md Setup section updated"
grep -q "init.config.template.yaml" ~/dev/personal/zachflow/MANUAL.md && echo "MANUAL.md mentions non-interactive"
```

Expected: 4 OK / matching lines.

- [ ] **Step 5.4: Commit**

```bash
cd ~/dev/personal/zachflow
git add examples/README.md MANUAL.md
git commit -m "docs: expand examples/README.md + MANUAL.md Setup with wizard usage"
```

---

## Task 6: CHANGELOG + final smoke + v0.4.0-sprint-3 tag

**Files:**
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`

- [ ] **Step 6.1: Add Sprint 3 entry to CHANGELOG**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Find this exact line:

```markdown
## [0.3.0-sprint-2] — 2026-04-27
```

Use Edit to insert a new section ABOVE it (newer-on-top convention). Replace the line with:

```markdown
## [0.4.0-sprint-3] — 2026-04-27

### Added
- `scripts/init-project.sh` — interactive (default) and non-interactive (`--from=init.config.yaml --non-interactive`) project bootstrap wizard. 7-step flow (project name, workflows, branch prefix, roles, teammate fills, KB mode, init KB).
- `templates/teammates/{be,fe,design,evaluator}-engineer.template.md` — canonical placeholder templates the wizard reads from.
- `templates/init.config.template.yaml` — annotated example for non-interactive mode.
- `tests/init-project-smoke.sh` — CI smoke test for non-interactive wizard (fixture-based).
- CI integration: `init-project.sh syntax check` + `init-project.sh non-interactive smoke` steps in `.github/workflows/ci.yml`.

### Changed
- `examples/README.md` — added wizard quick-start + non-interactive setup instructions.
- `MANUAL.md` — Setup section expanded from Sprint 0 stub to full wizard usage docs (interactive + non-interactive + re-run + skip behavior).

### Notes
- `.claude/teammates/*.md` Sprint 0 placeholders remain as clone-and-go defaults. Wizard fills overwrite them (with confirm gate + `--force` flag for CI).
- Wizard inserts an HTML comment marker (`<!-- zachflow init-project.sh wizard fill — <ISO 8601> -->`) at the top of filled teammate files for re-run detection.

### Deferred to v1.x+
- KB remote mode wizard.
- Stack adapter examples catalog (external PRs).
- Multi-stack mixing in single wizard run.
- Template inheritance.

## [0.3.0-sprint-2] — 2026-04-27
```

- [ ] **Step 6.2: End-to-end smoke**

```bash
cd ~/dev/personal/zachflow

# 1. install-workflows idempotent
bash scripts/install-workflows.sh

# 2. KB smoke
bash tests/kb-smoke.sh

# 3. init-project smoke (full)
bash tests/init-project-smoke.sh

# 4. ZZEM-leak with current exclusions
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

# 5. Bash syntax all
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"

# 6. Verify new files
[ -f scripts/init-project.sh ] && echo "init-project.sh exists"
[ -d templates/teammates ] && [ -f templates/teammates/be-engineer.template.md ] && echo "templates/teammates/ OK"
[ -f templates/init.config.template.yaml ] && echo "init.config.template.yaml OK"
[ -f tests/init-project-smoke.sh ] && echo "init-project-smoke.sh OK"
```

Expected: all OK lines, no FAIL.

- [ ] **Step 6.3: Final git status**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: only CHANGELOG.md modified (staged).

- [ ] **Step 6.4: Commit CHANGELOG**

```bash
cd ~/dev/personal/zachflow
git add CHANGELOG.md
git commit -m "docs(changelog): Sprint 3 — stack adapter (0.4.0-sprint-3)"
```

- [ ] **Step 6.5: Tag v0.4.0-sprint-3**

```bash
cd ~/dev/personal/zachflow
git tag -a v0.4.0-sprint-3 -m "Sprint 3 — stack adapter complete (init-project.sh wizard + templates/teammates/ canonical + CI smoke)"
git tag -l --format='%(refname:short) - %(subject)' | tail -5
```

Expected: 4 tags (v0.1.0-bootstrap, v0.2.0-sprint-1, v0.3.0-sprint-2, v0.4.0-sprint-3).

- [ ] **Step 6.6: Final commit history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -10
git rev-list --count v0.3.0-sprint-2..HEAD
```

Expected: ~7-9 new commits since v0.3.0-sprint-2 tag.

---

## Sprint 3 Done Criteria

- [ ] `scripts/init-project.sh` exists, executable, valid bash syntax
- [ ] Interactive mode produces sprint-config.yaml + filled .claude/teammates/ (manual smoke)
- [ ] Non-interactive mode (`--from=init.config.yaml --non-interactive --force`) PASSES `tests/init-project-smoke.sh`
- [ ] `templates/teammates/{be,fe,design,evaluator}-engineer.template.md` exist + byte-identical to `.claude/teammates/<name>.md` at Sprint 3 start
- [ ] `templates/init.config.template.yaml` exists, valid YAML, has all required sections
- [ ] `tests/init-project-smoke.sh` PASSES locally
- [ ] CI workflow has init-project syntax + smoke steps
- [ ] `examples/README.md` mentions wizard
- [ ] `MANUAL.md` Setup section expanded (no longer "preview")
- [ ] CHANGELOG.md `[0.4.0-sprint-3]` entry
- [ ] Tag `v0.4.0-sprint-3` exists
- [ ] No ZZEM-leak (existing scan passes)
- [ ] All bash scripts syntax OK (kb-bootstrap, install-workflows, setup-sprint, sync-repos, cleanup-sprint, sprint-monitor, hook-handler, init-project + tests/*.sh)
- [ ] Working tree clean

---

## Notes for Sprint 4+

- Sprint 4 (`gallery-split + plugins-formalize + release`): `npx create-zachflow my-project` will wrap `git clone + bash scripts/init-project.sh` into a single npm command. The wizard (this sprint) is the engine.
- Sprint 4 also adds `plugins/<name>/` directory pattern + ports `plugins/recall/` from upstream PR #57. The plugin install pattern (symlink) mirrors `install-workflows.sh` (Sprint 2) — same precedent.
- Stack adapter examples (`examples/<stack>/`) become a community PR channel post-v1.0. The wizard's non-interactive mode (`init.config.yaml`) makes it easy for contributors to share working configs.
