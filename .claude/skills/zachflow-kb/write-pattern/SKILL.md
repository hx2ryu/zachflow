---
name: zachflow-kb:write-pattern
description: Create a new pattern YAML, validate inline against schema, and commit locally. Use at Phase 4 Evaluator when a defect pattern does not match any existing pattern.
---

# zachflow-kb:write-pattern

## Inputs (all required unless noted)
- `category` — one of `correctness | completeness | integration | edge_case | code_quality | design_proto | design_spec`
- `severity` — one of `critical | major | minor`
- `title` — ≤120 chars
- `source_sprint` — lowercase-hyphen sprint id, e.g. `example-sprint-001`
- `source_group` — e.g. `group-001`
- `description`, `detection`, `prevention`, `contract_clause` — each ≥10 chars
- `example.bad`, `example.good` — optional

## Preconditions
- `bash scripts/kb-bootstrap.sh` ran at least once.
- Working tree at `${KB_PATH}` is clean (this skill commits but does not push).

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Determine next id**
   Glob: `${KB_PATH}/learning/patterns/{category}-*.yaml`
   Parse `NNN` suffix; take `max + 1`; zero-pad to 3 digits. If no existing patterns of this category, start at `001`. Next id = `{category}-{NNN}`.

3. **Read schema for reference (optional, advisory)**
   The authoritative schema is at `<git-root>/schemas/learning/pattern.schema.json` (zachflow core, not in KB). The skill does not enforce it — inline validation in step 5 catches structural issues; the CI smoke check (`tests/kb-smoke.sh`) catches schema-level drift.

4. **Compose the YAML**
   Write: `${KB_PATH}/learning/patterns/{id}.yaml`

   Fields to emit:
   - `id`, `title`, `category`, `severity`, `source_sprint`, `source_group`
   - `discovered_at`: current ISO 8601 with offset (e.g. `2026-04-27T12:34:56+09:00`) — use `date -u +%Y-%m-%dT%H:%M:%S+00:00` or `python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat(timespec='seconds'))"`.
   - `frequency: 1`
   - `last_seen: {source_sprint}`
   - `description`, `detection`, `prevention`, `contract_clause`
   - `example` (if provided)
   - `schema_version: 1`

5. **Inline validate**
   Bash:
   ```
   python3 -c "
   import yaml, sys, re
   data = yaml.safe_load(open('${KB_PATH}/learning/patterns/{id}.yaml'))
   for k in ['id','title','category','severity','source_sprint','discovered_at','frequency','last_seen','description','detection','prevention','contract_clause','schema_version']:
     assert k in data, 'missing: ' + k
   assert re.match(r'^(correctness|completeness|integration|edge_case|code_quality|design_proto|design_spec)-[0-9]{3}$', data['id']), 'bad id'
   assert data['frequency'] >= 1
   assert data['schema_version'] == 1
   print('inline validate OK')
   "
   ```
   On failure: surface error, do not commit.

6. **Commit (no push)**
   Bash:
   ```
   cd "$KB_PATH"
   git add learning/patterns/{id}.yaml 2>/dev/null || true
   # If KB_PATH is the project repo's .zachflow/kb (embedded mode), the
   # git operation may need to run from the project root with the relative
   # path — caller should adapt if KB_PATH is not its own git repo.
   ```

   In embedded mode, `${KB_PATH}` is `<project-root>/.zachflow/kb` and the `git` command runs at the project root. The skill's caller (Sprint Lead orchestrator) is responsible for staging from the project root if `${KB_PATH}/.git` does not exist:

   ```
   if [ -d "${KB_PATH}/.git" ]; then
     cd "$KB_PATH"
     git add learning/patterns/{id}.yaml
     git commit -m "kb: pattern {id} from {source_sprint}/{source_group}"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/patterns/{id}.yaml"
     git commit -m "kb: pattern {id} from {source_sprint}/{source_group}"
   fi
   ```

## Failure handling
- Inline validate fails → fix body; re-write file from step 4. Do NOT commit malformed content.
- `git commit` fails (e.g., nothing to commit, or pre-commit hook) → surface error; pattern file remains on disk for inspection.

## Verification (smoke)
Invoke with a test category/title:
- File appears at `${KB_PATH}/learning/patterns/{id}.yaml`.
- `id` follows `{category}-{NNN}` pattern.
- `git log -1` shows the commit.
