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

# Defensive: warn if bash too old. Most modern features are fine, but the script
# was tested with bash 3.2+ via dedup-without-associative-arrays.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Warning: this script assumes bash. Behavior on other shells is undefined." >&2
fi

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

# For each unique teammate (across all roles), find the LAST role's fill
# (last-wins for shared teammates) and write to .claude/teammates/.
# Bash 3.2-compatible: indexed array + string-search dedup, no associative arrays.

unique_teammates=""
for role_entry in "${ROLES[@]}"; do
  IFS='|' read -ra parts <<< "$role_entry"
  teammate="${parts[4]}"
  case " $unique_teammates " in
    *" $teammate "*) ;;  # already in list
    *) unique_teammates="$unique_teammates $teammate" ;;
  esac
done

for teammate in $unique_teammates; do
  # Find last fill_json for this teammate
  fill_json="{}"
  for role_entry in "${ROLES[@]}"; do
    IFS='|' read -ra parts <<< "$role_entry"
    if [ "${parts[4]}" = "$teammate" ]; then
      candidate="${parts[5]:-{}}"
      fill_json="${candidate//__PIPE__/|}"
    fi
  done

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
