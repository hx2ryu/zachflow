---
name: zachflow-kb:update-pattern
description: Increment the frequency counter and refresh last_seen on an existing pattern. Use at Phase 4 Evaluator when a recurring defect matches an existing pattern.
---

# zachflow-kb:update-pattern

## Inputs
- `id` — e.g. `correctness-001` (required, must match existing pattern)
- `source_sprint` — the sprint that just observed the pattern (required)

## Preconditions
- `bash scripts/kb-bootstrap.sh` ran at least once.

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Locate and parse file**
   Read: `${KB_PATH}/learning/patterns/{id}.yaml`
   If missing: abort with `pattern not found: {id}`. Do NOT create a new pattern here; use `zachflow-kb:write-pattern`.

3. **Mutate frequency + last_seen**
   Edit the YAML:
   - `frequency: <current + 1>`
   - `last_seen: {source_sprint}`
   Leave every other field untouched (especially `discovered_at`).

4. **Inline validate (post-edit)**
   Bash:
   ```
   python3 -c "
   import yaml
   data = yaml.safe_load(open('${KB_PATH}/learning/patterns/{id}.yaml'))
   assert isinstance(data['frequency'], int) and data['frequency'] >= 2
   assert data['last_seen']
   print('OK')
   "
   ```

5. **Commit (no push)**
   Bash (using the same project-root vs KB-as-its-own-repo logic as `write-pattern`):
   ```
   if [ -d "${KB_PATH}/.git" ]; then
     cd "$KB_PATH"
     git add learning/patterns/{id}.yaml
     git commit -m "kb: pattern {id} frequency +1 ({source_sprint})"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/patterns/{id}.yaml"
     git commit -m "kb: pattern {id} frequency +1 ({source_sprint})"
   fi
   ```

## Failure handling
- Pattern not found → abort with `pattern not found: {id}`. Use `zachflow-kb:write-pattern` for new patterns.
- Validate fails → pattern file was unexpectedly malformed; surface to caller.

## Verification (smoke)
Pick an existing pattern (say `correctness-001`), invoke with a test sprint id. Diff on the YAML shows only `frequency` incremented and `last_seen` updated.
