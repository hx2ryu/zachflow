---
name: zachflow-kb:write-reflection
description: Record a sprint-end reflection (markdown + frontmatter) into the KB. Use at the Phase 6 Retrospective of every sprint.
---

# zachflow-kb:write-reflection

## Inputs
- `sprint_id` — required, lowercase-hyphen.
- `domain` — required, free string matching `^[a-z][a-z0-9-]*$`. Use whatever domain identifier makes sense for your project.
- `completed_at` — ISO 8601 with offset.
- `outcome` — one of `pass | fail | partial`.
- `related_patterns` — optional array of pattern ids (e.g. `[correctness-001, integration-014]`).
- `body` — markdown narrative (required, non-empty).

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

2. **Reject duplicate**
   If `${KB_PATH}/learning/reflections/{sprint_id}.md` exists, abort with `reflection already exists for {sprint_id}; use a different sprint_id or remove the existing file.` Do NOT overwrite.

3. **Write file**
   Write: `${KB_PATH}/learning/reflections/{sprint_id}.md`

   Content:
   ```
   ---
   sprint_id: {sprint_id}
   domain: {domain}
   completed_at: "{completed_at}"
   outcome: {outcome}
   related_patterns:
   {each id as "  - <id>"; omit "related_patterns" key entirely if no ids}
   schema_version: 1
   ---

   {body}
   ```

4. **Inline validate frontmatter**
   Bash:
   ```
   python3 -c "
   import yaml, re
   content = open('${KB_PATH}/learning/reflections/{sprint_id}.md').read()
   assert content.startswith('---')
   end = content.find('---', 3)
   assert end > 0
   fm = yaml.safe_load(content[3:end])
   for k in ['sprint_id','domain','completed_at','outcome','schema_version']:
     assert k in fm, 'missing: ' + k
   assert re.match(r'^[a-z][a-z0-9-]*$', fm['domain']), 'bad domain'
   assert fm['outcome'] in ['pass','fail','partial']
   assert fm['schema_version'] == 1
   print('OK')
   "
   ```

5. **Commit (no push)**
   ```
   if [ -d "${KB_PATH}/.git" ]; then
     cd "$KB_PATH"
     git add learning/reflections/{sprint_id}.md
     git commit -m "kb: reflection {sprint_id} ({outcome})"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/reflections/{sprint_id}.md"
     git commit -m "kb: reflection {sprint_id} ({outcome})"
   fi
   ```

## Failure handling
- Duplicate reflection → abort, do not overwrite.
- Invalid frontmatter → fix and re-run from step 3.

## Verification (smoke)
Create a throwaway reflection (`sprint_id=test-sprint-999`); confirm file appears, parses cleanly, and is committed.
