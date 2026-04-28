# Sprint 1 — KB Embedded Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port 6 KB skills + 3 learning schemas from `~/.zzem/kb/` into zachflow at `~/dev/personal/zachflow/`, adapted for embedded mode (no git remote, no npm validators), making Sprint 0's `zachflow-kb:*` references in phase skills actually invokable.

**Architecture:** Each skill's protocol (`SKILL.md`) is a markdown contract — no compiled code. Skills resolve `KB_PATH` via env var → git-root + `/.zachflow/kb` fallback. Validation is inline (skill protocol's steps include yaml/schema checks) plus a single CI smoke (`tests/kb-smoke.sh`) that verifies schema files are valid JSON Schema and all SKILL.md files have correct frontmatter. Notion-related skills (`sync-prds-from-notion`, `sync-active-prds`) are out of scope. Skill protocol differences from source: remove all `git pull/push/rebase` (embedded = single-machine), remove `npm run validate:learning` (replaced by inline yaml parse + key-presence check), drop `prd`/`events` type cases in `read` skill (products axis is post-v1.0).

**Tech Stack:** bash 5+, Python 3.11+ (system default for inline yaml/json), git, Claude Code skills (markdown SKILL.md with YAML frontmatter), JSON Schema draft 2020-12.

**Predecessor spec:** `~/dev/personal/zachflow/docs/superpowers/specs/2026-04-27-sprint-1-kb-embedded-design.md` (committed `45aee99`). Read its sections 1 (skill layout), 2 (KB_PATH), 3 (skill contracts), 4 (schemas), 5 (kb-bootstrap), 6 (smoke check), 7 (docs) before starting.

**Source reference (read-only)**: `~/.zzem/kb/`. Used for porting source material; not modified.

---

## Sanitization & Adaptation Rules (apply to every ported file)

These are referenced by every "port + adapt" task below.

| Pattern | Replacement |
|---------|-------------|
| `zzem-kb:` (skill names) | `zachflow-kb:` (mechanical rename, every occurrence) |
| `$ZZEM_KB_PATH` | `${KB_PATH}` |
| `~/.zzem/kb` (default path mention) | `<git-root>/.zachflow/kb` (embedded mode default) |
| `git checkout main && git pull --ff-only` (sync prologue) | **REMOVE** — embedded mode has no remote |
| `git pull --rebase origin main && git push` (push retry loop) | **REMOVE** — embedded mode commits, but does not push |
| `npm run validate:learning` / `validate:content` | replace with inline check: `python3 -c "import yaml; yaml.safe_load(open('FILE'))"` (or appropriate per skill) |
| References to `zach-wrtn/knowledge-base` repo | "the project's KB at `${KB_PATH}`" |
| `domain` enum (`ai-webtoon \| free-tab \| ugc-platform \| infra`) | free string matching `^[a-z][a-z0-9-]*$` (schema relaxed accordingly) |
| `prd` / `events` type cases (in `read` skill) | **REMOVE** — products axis is post-v1.0; emit explicit error if user passes `type=prd` or `type=events` |
| `sprint_id` pattern enums (e.g. `ai-webtoon-007`) | placeholder examples like `<sprint-id>` or `example-sprint-001` |
| `source_group` pattern values | keep schema (`^group-[0-9]+$`) |

**Verification per file:** `grep -rE 'ZZEM|zzem-kb:|zach-wrtn|\$ZZEM_KB_PATH|git push|git pull|npm run validate' <file>` should return zero matches.

---

## File Structure (Sprint 1 output, additions to `~/dev/personal/zachflow/`)

```
~/dev/personal/zachflow/
├── .claude/skills/zachflow-kb/        # ← Task 2 NEW
│   ├── read/SKILL.md
│   ├── write-pattern/SKILL.md
│   ├── update-pattern/SKILL.md
│   ├── write-reflection/SKILL.md
│   ├── promote-rubric/SKILL.md
│   └── sync/SKILL.md
│
├── schemas/                            # ← Task 1 NEW (top-level dir)
│   └── learning/
│       ├── pattern.schema.json
│       ├── rubric.schema.json
│       └── reflection.schema.json
│
├── scripts/
│   └── kb-bootstrap.sh                # ← Task 3 EXPANDED (rubric v1 seed)
│
├── tests/                              # ← Task 5 NEW
│   └── kb-smoke.sh
│
├── docs/
│   └── kb-system.md                   # ← Task 4 EXPANDED (Sprint 0 skeleton → full)
│
├── .github/workflows/ci.yml           # ← Task 5 MODIFIED (add KB smoke step)
└── CHANGELOG.md                        # ← Task 6 MODIFIED (Sprint 1 entry)
```

**Source paths (read-only)**:
- `~/.zzem/kb/skills/<op>/SKILL.md` (the 6 skills to port)
- `~/.zzem/kb/schemas/learning/<type>.schema.json` (the 3 schemas to port)

---

## Task 1: Port + sanitize learning schemas (3 files)

**Files:**
- Create: `~/dev/personal/zachflow/schemas/learning/pattern.schema.json`
- Create: `~/dev/personal/zachflow/schemas/learning/rubric.schema.json`
- Create: `~/dev/personal/zachflow/schemas/learning/reflection.schema.json`

- [ ] **Step 1.1: Read source schemas**

```
Read ~/.zzem/kb/schemas/learning/pattern.schema.json
Read ~/.zzem/kb/schemas/learning/rubric.schema.json
Read ~/.zzem/kb/schemas/learning/reflection.schema.json
```

- [ ] **Step 1.2: Write `schemas/learning/pattern.schema.json`**

Write `~/dev/personal/zachflow/schemas/learning/pattern.schema.json` with this exact content (source preserved as-is — category/severity/severity enums are stack-agnostic; only `$id` is rewritten):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zachflow.dev/schemas/learning/pattern.schema.json",
  "title": "Pattern",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "id", "title", "category", "severity", "source_sprint",
    "discovered_at", "frequency", "last_seen",
    "description", "detection", "prevention", "contract_clause",
    "schema_version"
  ],
  "properties": {
    "id":              { "type": "string", "pattern": "^(correctness|completeness|integration|edge_case|code_quality|design_proto|design_spec)-[0-9]{3}$" },
    "title":           { "type": "string", "maxLength": 120 },
    "category":        { "enum": ["correctness","completeness","integration","edge_case","code_quality","design_proto","design_spec"] },
    "severity":        { "enum": ["critical","major","minor"] },
    "source_sprint":   { "type": "string", "pattern": "^[a-z0-9-]+$" },
    "source_group":    { "type": "string", "pattern": "^group-[0-9]+$" },
    "discovered_at":   { "type": "string", "format": "date-time" },
    "frequency":       { "type": "integer", "minimum": 1 },
    "last_seen":       { "type": "string", "pattern": "^[a-z0-9-]+$" },
    "description":     { "type": "string", "minLength": 10 },
    "detection":       { "type": "string", "minLength": 10 },
    "prevention":      { "type": "string", "minLength": 10 },
    "contract_clause": { "type": "string", "minLength": 10 },
    "example": {
      "type": "object",
      "required": ["bad","good"],
      "properties": { "bad": {"type":"string"}, "good": {"type":"string"} }
    },
    "schema_version":  { "const": 1 }
  }
}
```

- [ ] **Step 1.3: Write `schemas/learning/rubric.schema.json`**

Write `~/dev/personal/zachflow/schemas/learning/rubric.schema.json` with this exact content (source preserved; `$id` rewritten):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zachflow.dev/schemas/learning/rubric.schema.json",
  "title": "Rubric (frontmatter only)",
  "type": "object",
  "additionalProperties": false,
  "required": ["version", "status", "superseded_by", "schema_version"],
  "properties": {
    "version":        { "type": "integer", "minimum": 1 },
    "status":         { "enum": ["active", "superseded"] },
    "superseded_by":  { "type": ["integer", "null"] },
    "changelog":      { "type": "string" },
    "schema_version": { "const": 1 }
  }
}
```

- [ ] **Step 1.4: Write `schemas/learning/reflection.schema.json`**

Write `~/dev/personal/zachflow/schemas/learning/reflection.schema.json` with this exact content. **Difference from source**: `domain` is changed from a 4-value ZZEM-specific enum to a free string with kebab-case pattern, allowing per-project domain values. `$id` is rewritten.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://zachflow.dev/schemas/learning/reflection.schema.json",
  "title": "Reflection (frontmatter only)",
  "type": "object",
  "additionalProperties": false,
  "required": ["sprint_id", "domain", "completed_at", "outcome", "schema_version"],
  "properties": {
    "sprint_id":    { "type": "string", "pattern": "^[a-z0-9-]+$" },
    "domain":       { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
    "completed_at": { "type": "string", "format": "date-time" },
    "outcome":      { "enum": ["pass", "fail", "partial"] },
    "related_patterns": {
      "type": "array",
      "items": { "type": "string", "pattern": "^(correctness|completeness|integration|edge_case|code_quality|design_proto|design_spec)-[0-9]{3}$" }
    },
    "schema_version": { "const": 1 }
  }
}
```

- [ ] **Step 1.5: Verify all 3 schemas are valid JSON**

```bash
for f in ~/dev/personal/zachflow/schemas/learning/*.json; do
  python3 -c "import json; json.load(open('$f'))" && echo "OK: $f" || { echo "FAIL: $f"; exit 1; }
done
```

Expected: 3 `OK:` lines.

- [ ] **Step 1.6: Verify `$schema` declares draft 2020-12**

```bash
for f in ~/dev/personal/zachflow/schemas/learning/*.json; do
  python3 -c "
import json
data = json.load(open('$f'))
assert data['\$schema'].endswith('draft/2020-12/schema'), 'wrong dialect: ' + data['\$schema']
print('OK:', '$f')
"
done
```

Expected: 3 `OK:` lines.

- [ ] **Step 1.7: Commit**

```bash
cd ~/dev/personal/zachflow
git add schemas/
git commit -m "feat(kb): import learning schemas (pattern/rubric/reflection)"
```

---

## Task 2: Port + adapt 6 KB skills

**Files:**
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/read/SKILL.md`
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/write-pattern/SKILL.md`
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/update-pattern/SKILL.md`
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/write-reflection/SKILL.md`
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/promote-rubric/SKILL.md`
- Create: `~/dev/personal/zachflow/.claude/skills/zachflow-kb/sync/SKILL.md`

Each skill is a self-contained protocol. Process file-by-file. The implementer should Read each source SKILL.md first (in `~/.zzem/kb/skills/<op>/SKILL.md`), then Write the adapted version. The exact target content for each is provided below.

### KB_PATH resolution boilerplate (referenced by all 6 skills)

The following bash snippet is the standard prologue. Each skill's "Steps" section starts with this:

```bash
KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"

if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
  echo "Error: zachflow KB not found at $KB_PATH" >&2
  echo "Run 'bash scripts/kb-bootstrap.sh' first, or set KB_PATH env var." >&2
  exit 1
fi
```

- [ ] **Step 2.1: Create the `zachflow-kb/` directory**

```bash
mkdir -p ~/dev/personal/zachflow/.claude/skills/zachflow-kb/{read,write-pattern,update-pattern,write-reflection,promote-rubric,sync}
```

- [ ] **Step 2.2: Write `read/SKILL.md`**

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/read/SKILL.md` with this exact content (adapted from `~/.zzem/kb/skills/read/SKILL.md`):

```markdown
---
name: zachflow-kb:read
description: Query the KB by content type and filters. Returns file paths (caller reads content via Read tool). Use at Phase 2 Spec to load prior patterns/reflections, Phase 4 Evaluator to load the latest rubric.
---

# zachflow-kb:read

## Inputs
- `type` — one of `pattern`, `rubric`, `reflection` (required). The `prd` and `events` types are post-v1.0 (products axis); requesting them returns an explicit error.
- Filters (optional, AND semantics):
  - For `pattern`: `category` (enum: correctness, completeness, integration, edge_case, code_quality, design_proto, design_spec), `severity` (enum: critical, major, minor), `min_frequency` (integer).
  - For `rubric`: `status` (default `active`).
  - For `reflection`: `domain` (free string matching `^[a-z][a-z0-9-]*$`), `limit` (integer, default 3, most-recent first by `completed_at`).

## Preconditions
- `bash scripts/kb-bootstrap.sh` was run at least once for this project (creates `.zachflow/kb/`).

## Steps

1. **Resolve KB_PATH**

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     echo "Run 'bash scripts/kb-bootstrap.sh' first, or set KB_PATH env var." >&2
     exit 1
   fi
   ```

2. **Reject products-axis types**

   If `type` is `prd` or `events`, abort with: `Error: type=prd/events requires the products-axis plugin (post-v1.0). See docs/kb-system.md.`

3. **Resolve directory/glob**
   - `pattern` → `${KB_PATH}/learning/patterns/*.yaml`
   - `rubric`  → `${KB_PATH}/learning/rubrics/*.md`
   - `reflection` → `${KB_PATH}/learning/reflections/*.md`

4. **List candidates** — glob the resolved pattern.

5. **Filter client-side**
   Read each candidate, parse YAML (`.yaml`) or frontmatter (`.md`). Apply filter predicate:
   - `pattern`: keep if `category`, `severity`, `frequency >= min_frequency` match.
   - `rubric`: keep if frontmatter `status` matches; sort descending by `version`; return top 1.
   - `reflection`: keep if `domain` matches; sort by `completed_at` desc; slice `limit`.

6. **Return paths**
   Output a list of absolute file paths. The caller uses Read on each.

## Failure handling
- No matches → return empty list. Do not treat as error.
- Parse error on one file → log the specific file and skip it; continue.

## Verification (smoke)
- `type=pattern` (no filters) → returns all pattern paths under `${KB_PATH}/learning/patterns/`.
- `type=rubric` → returns the single active rubric path (or empty if KB freshly bootstrapped).
- `type=prd` → returns explicit "products-axis plugin required" error.
```

- [ ] **Step 2.3: Write `write-pattern/SKILL.md`**

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/write-pattern/SKILL.md`:

```markdown
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
```

- [ ] **Step 2.4: Write `update-pattern/SKILL.md`**

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/update-pattern/SKILL.md`:

```markdown
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
```

- [ ] **Step 2.5: Write `write-reflection/SKILL.md`**

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/write-reflection/SKILL.md`:

```markdown
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
```

- [ ] **Step 2.6: Write `promote-rubric/SKILL.md`**

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/promote-rubric/SKILL.md`:

```markdown
---
name: zachflow-kb:promote-rubric
description: Append a Promotion Log row to the active Evaluator rubric. Use at Phase 6 Retro when a pattern with frequency >= 2 and a defined contract_clause should promote into next-version rubric. Adds the log row only; creating a new v(N+1) file is a separate manual follow-up.
---

# zachflow-kb:promote-rubric

Append a single row to the active rubric's **Promotion Log** table. Version-bump (v(N) → v(N+1)) is NOT handled by this skill — see Follow-up below.

## Inputs

- `source_sprint` — lowercase-hyphen sprint id (required).
- `source_pattern` — pattern id (required, e.g. `correctness-001`).
- `clause_id` — next clause identifier in sequence (required, e.g. `C10`). Caller picks the next free id by reading the active rubric's Clauses section.
- `clause_title` — short title for the log entry (required, ≤80 chars, e.g. `Retry Idempotency`).

## Preconditions

- `bash scripts/kb-bootstrap.sh` ran at least once.
- At least one active rubric exists at `${KB_PATH}/learning/rubrics/v{N}.md` with frontmatter `status: active`, `superseded_by: null`. (`kb-bootstrap.sh` seeds `v1.md` on first run.)

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Locate active rubric**
   Glob `${KB_PATH}/learning/rubrics/*.md`. Parse each frontmatter; pick the one with `status: active` AND `superseded_by: null`. Expect exactly one.
   - Zero matches: abort, `no active rubric found; bootstrap should have seeded v1.md`.
   - Multiple matches: abort, `multiple active rubrics found — KB needs cleanup`.

3. **Verify clause_id is free**
   Read the active rubric body. Confirm:
   - No existing heading in `## Clauses` section uses `clause_id` (e.g. `### C10. …`).
   - Promotion Log column "Clause Added" has no row starting with `clause_id`.
   On collision: abort with `clause_id {clause_id} already in use; pick a different id`.

4. **Append Promotion Log row**
   Edit the active rubric. Locate the Promotion Log table (matches header `| Date | Sprint | Clause Added | Source Pattern |`). Append one row immediately after the last non-placeholder row:

   ```
   | {YYYY-MM-DD} | {source_sprint} | {clause_id} {clause_title} | {source_pattern} |
   ```

   Use the current local date (`date +%Y-%m-%d`). Do NOT remove the existing baseline placeholder row (`| — | — | (baseline) | — |`); if it is the only row, keep it as the first row and append after it.

5. **Inline validate (post-edit)**
   Bash:
   ```
   python3 -c "
   content = open('${KB_PATH}/learning/rubrics/v{N}.md').read()
   assert content.startswith('---'), 'no frontmatter'
   assert '| Date | Sprint | Clause Added | Source Pattern |' in content
   print('OK')
   "
   ```

6. **Commit (no push)**
   ```
   if [ -d "${KB_PATH}/.git" ]; then
     cd "$KB_PATH"
     git add learning/rubrics/v{N}.md
     git commit -m "kb: rubric promote {clause_id} from {source_sprint}"
   else
     PROJECT_ROOT="$(cd "$KB_PATH/../.." && pwd)"
     cd "$PROJECT_ROOT"
     git add ".zachflow/kb/learning/rubrics/v{N}.md"
     git commit -m "kb: rubric promote {clause_id} from {source_sprint}"
   fi
   ```

7. **Nudge**
   Count Promotion Log rows (excluding the baseline placeholder). If count `>= 2`, emit a nudge to the caller:

   ```
   ⚠ Rubric v{N} Promotion Log now has {K} accumulated entries (threshold 2).
     Consider bumping to v{N+1} at the next Retro so the clauses get promoted
     into the main Clauses section. Version bump is currently a manual step —
     see follow-up below.
   ```

## Failure handling

- No active rubric → user must initialize one. `kb-bootstrap.sh` seeds `v1.md` on first run; if missing, re-run `bash scripts/kb-bootstrap.sh`.
- `clause_id` collision → caller picks a different id.
- Validate fails → edit produced malformed frontmatter or broke markdown structure; fix and re-run from step 4.

## Verification (smoke)

Invoke with a throwaway `clause_id` and a dummy sprint id. Verify:
- Promotion Log table of active rubric gains exactly one new row.
- `git log -1 --stat` shows a single-file change.

## Follow-up (not implemented by this skill)

**Version bump** (v{N} → v{N+1}): when the Promotion Log hits 2+ accumulated rows, a new rubric file should be created with:
- All existing v{N} clauses preserved,
- Full bodies of the promoted clauses added to the `## Clauses` section,
- A fresh empty Promotion Log,
- v{N} marked `status: superseded`, `superseded_by: N+1`.

This is currently a manual process because it requires the full clause body (markdown content) which is NOT stored by this skill — only the short title is logged. A future `zachflow-kb:bump-rubric` skill could accept a `clauses` array (each with body) and perform the migration; design is deferred until the promotion cadence justifies the tooling.
```

- [ ] **Step 2.7: Write `sync/SKILL.md`** (embedded mode no-op + remote-mode stub)

Write `~/dev/personal/zachflow/.claude/skills/zachflow-kb/sync/SKILL.md`:

```markdown
---
name: zachflow-kb:sync
description: Sync the local KB with its source. In embedded mode (default), this is a no-op since the KB lives in the project repo. In remote mode (v1.x roadmap), it pulls from the configured remote. Invoke at the start of every sprint phase before reading or writing KB content (cheap if no-op).
---

# zachflow-kb:sync

## Behavior by mode

zachflow KB has two modes:

- **Embedded** (default, v1.0): KB lives at `<git-root>/.zachflow/kb/`. No remote, no fetch — `sync` is a no-op. The skill simply confirms the KB exists and reports embedded mode.
- **Remote** (v1.1+ roadmap): when `KB_PATH` env var points to a separate clone of an external KB git repo, `sync` runs `git fetch && git pull --ff-only`.

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Detect mode**
   - If `${KB_PATH}/.git` exists → potentially a separate KB repo (remote mode candidate).
   - Otherwise → embedded mode (KB is part of the parent project's repo).

3. **Embedded mode** — print status and exit:

   ```
   echo "zachflow KB: embedded mode at $KB_PATH — nothing to sync."
   exit 0
   ```

4. **Remote mode** (v1.1+ — currently a stub):

   In v1.0 the remote branch is a stub. If `${KB_PATH}/.git` exists AND the user has explicitly opted in to remote mode (env var `ZACHFLOW_KB_MODE=remote`), the skill performs a fetch + fast-forward pull. If the env var is NOT set, the skill assumes embedded mode and reports "no-op".

   ```bash
   if [ -d "${KB_PATH}/.git" ] && [ "${ZACHFLOW_KB_MODE:-embedded}" = "remote" ]; then
     cd "$KB_PATH"
     git checkout main 2>/dev/null || true
     git pull --ff-only || { echo "Warning: KB pull failed; using cached state" >&2; exit 0; }
     git rev-parse --short HEAD
   fi
   ```

   Full remote-mode workflow (clone, push, conflict handling) is the v1.1 roadmap.

## Failure handling
- KB not found → abort with bootstrap instructions.
- Network failure (remote mode) → log warning, continue with cached state. Reads remain valid.

## Verification (smoke)
- Embedded mode: skill outputs `zachflow KB: embedded mode at ... — nothing to sync.` and exits 0.
- Remote mode: skipped in v1.0.
```

- [ ] **Step 2.8: Verify all 6 SKILL.md files exist + have valid frontmatter**

```bash
for f in ~/dev/personal/zachflow/.claude/skills/zachflow-kb/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f').read()
assert content.startswith('---'), '$f no frontmatter'
end = content.find('---', 3)
fm = yaml.safe_load(content[3:end])
assert fm['name'].startswith('zachflow-kb:'), '$f bad name'
print('OK:', '$f')
"
done
```

Expected: 6 `OK:` lines.

- [ ] **Step 2.9: Verify no ZZEM/legacy literals**

```bash
grep -rE 'ZZEM|zzem-kb:|zach-wrtn|\$ZZEM_KB_PATH|git push|git pull --rebase|npm run validate' \
  ~/dev/personal/zachflow/.claude/skills/zachflow-kb/
```

Expected: no output. (`git pull --ff-only` IS allowed inside the sync skill's remote-mode stub block.)

- [ ] **Step 2.10: Commit**

```bash
cd ~/dev/personal/zachflow
git add .claude/skills/zachflow-kb/
git commit -m "feat(kb): port 6 KB skills (read/write-pattern/update-pattern/write-reflection/promote-rubric/sync) for embedded mode"
```

---

## Task 3: Expand `kb-bootstrap.sh` with rubric v1 seed

**Files:**
- Modify: `~/dev/personal/zachflow/scripts/kb-bootstrap.sh`

Sprint 0 left a minimal version that only creates `.zachflow/kb/` directories. Sprint 1 adds an initial active rubric (`v1.md`) so that `zachflow-kb:promote-rubric` has a target on first use.

- [ ] **Step 3.1: Read current `kb-bootstrap.sh`**

Read `~/dev/personal/zachflow/scripts/kb-bootstrap.sh` to confirm Sprint 0's body.

- [ ] **Step 3.2: Replace with the expanded version**

Write `~/dev/personal/zachflow/scripts/kb-bootstrap.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# zachflow KB bootstrap — Sprint 1 embedded mode
# v1.x will add remote-mode support (pull from external git repo when KB_PATH points to a remote-mode clone).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KB_DIR="${PROJECT_ROOT}/.zachflow/kb"

mkdir -p "${KB_DIR}/learning/patterns"
mkdir -p "${KB_DIR}/learning/rubrics"
mkdir -p "${KB_DIR}/learning/reflections"
mkdir -p "${KB_DIR}/products"

# Sprint 1: seed initial active rubric v1 if absent
RUBRIC_V1="${KB_DIR}/learning/rubrics/v1.md"
if [ ! -f "$RUBRIC_V1" ]; then
  cat > "$RUBRIC_V1" <<'EOF'
---
version: 1
status: active
superseded_by: null
schema_version: 1
changelog: |
  v1 — baseline rubric seeded by kb-bootstrap.sh on first run.
---

# Evaluator Rubric v1

The active Evaluator rubric. New clauses are promoted from observed patterns
(see `zachflow-kb:promote-rubric`). Version bumps (v1 → v2) consolidate the
Promotion Log into the Clauses section — currently a manual operation.

## Clauses

(No clauses yet. Patterns earn promotion via the `zachflow-kb:promote-rubric`
skill at Phase 6 Retro when `frequency >= 2` and a `contract_clause` is defined.)

## Promotion Log

| Date | Sprint | Clause Added | Source Pattern |
|------|--------|--------------|----------------|
| —    | —      | (baseline)   | —              |
EOF
fi

if [ ! -f "${KB_DIR}/.initialized" ]; then
  touch "${KB_DIR}/.initialized"
  echo "zachflow KB initialized at ${KB_DIR} (embedded mode)"
else
  echo "zachflow KB already initialized at ${KB_DIR}"
fi
```

- [ ] **Step 3.3: Make executable + verify syntax**

```bash
chmod +x ~/dev/personal/zachflow/scripts/kb-bootstrap.sh
bash -n ~/dev/personal/zachflow/scripts/kb-bootstrap.sh && echo "syntax OK"
```

Expected: `syntax OK`.

- [ ] **Step 3.4: Run kb-bootstrap.sh end-to-end**

```bash
cd ~/dev/personal/zachflow
rm -rf .zachflow  # ensure fresh start
bash scripts/kb-bootstrap.sh
ls -la .zachflow/kb/learning/rubrics/v1.md
head -10 .zachflow/kb/learning/rubrics/v1.md
```

Expected:
- `v1.md` exists (sized > 0)
- First 10 lines show YAML frontmatter (`---`, `version: 1`, `status: active`, ...)

- [ ] **Step 3.5: Verify rubric v1 frontmatter parses cleanly**

```bash
python3 -c "
import yaml
content = open('/Users/zachryu/dev/personal/zachflow/.zachflow/kb/learning/rubrics/v1.md').read()
assert content.startswith('---')
end = content.find('---', 3)
fm = yaml.safe_load(content[3:end])
assert fm['version'] == 1
assert fm['status'] == 'active'
assert fm['superseded_by'] is None
assert fm['schema_version'] == 1
print('rubric v1 OK')
"
```

Expected: `rubric v1 OK`.

- [ ] **Step 3.6: Run kb-bootstrap.sh again (idempotency test)**

```bash
bash ~/dev/personal/zachflow/scripts/kb-bootstrap.sh
```

Expected: `zachflow KB already initialized at ...` (and `v1.md` still exists, unchanged).

- [ ] **Step 3.7: Clean up smoke test artifacts**

```bash
rm -rf ~/dev/personal/zachflow/.zachflow
```

(Per-project state — should not be committed in Sprint 1 either.)

- [ ] **Step 3.8: Commit**

```bash
cd ~/dev/personal/zachflow
git add scripts/kb-bootstrap.sh
git commit -m "feat(kb): expand kb-bootstrap.sh with rubric v1 seed"
```

---

## Task 4: Expand `docs/kb-system.md`

**Files:**
- Modify: `~/dev/personal/zachflow/docs/kb-system.md`

Sprint 0 wrote a skeleton. Sprint 1 fills it with the v1.0 KB system documentation.

- [ ] **Step 4.1: Replace `docs/kb-system.md` with the full v1.0 version**

Write `~/dev/personal/zachflow/docs/kb-system.md` with this exact content:

```markdown
# Knowledge Base

zachflow's KB is the cross-session memory layer used by the Sprint workflow's evaluation and retrospective phases. It accumulates **patterns** (defect signatures), **rubrics** (Evaluator clauses), and **reflections** (per-sprint outcomes) — and feeds them forward into future Sprint Contracts.

## Modes

zachflow's KB supports two modes:

- **Embedded** (default) — `.zachflow/kb/` lives in your project repo. Zero external dependencies. Patterns/rubrics/reflections are tracked alongside your code, sharing the same git history.
- **Remote** (opt-in, v1.1+ roadmap) — KB content lives in a separate git repo, accessed via `${KB_PATH}` pointing to that clone. Useful for teams sharing learning across multiple projects.

## Layout

```
.zachflow/kb/
├── .initialized            # bootstrap marker
├── learning/
│   ├── patterns/{category}-{NNN}.yaml
│   ├── rubrics/v{N}.md     # active rubric is the latest with status: active
│   └── reflections/{sprint-id}.md
└── products/               # post-v1.0 (not used yet)
```

Schemas (zachflow core, not in user KB) live at `<git-root>/schemas/learning/`.

## KB_PATH resolution

All `zachflow-kb:*` skills resolve `KB_PATH` via this prologue:

```bash
KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
```

Rules:
- If env var `KB_PATH` is set, use it (allows remote mode + tests with custom paths).
- Otherwise, default to `<git-root>/.zachflow/kb` (embedded mode).
- If neither yields a valid directory, the skill exits with an explicit error pointing at `bash scripts/kb-bootstrap.sh`.

## Skills

| Skill | Purpose |
|-------|---------|
| `zachflow-kb:read` | Query patterns / rubrics / reflections by filters. Returns paths; caller reads content. |
| `zachflow-kb:write-pattern` | Create a new pattern YAML at `learning/patterns/{category}-{NNN}.yaml`. Auto-numbers within category. |
| `zachflow-kb:update-pattern` | Increment `frequency`, refresh `last_seen` on an existing pattern. |
| `zachflow-kb:write-reflection` | Record a sprint-end reflection (markdown + frontmatter) at `learning/reflections/{sprint_id}.md`. |
| `zachflow-kb:promote-rubric` | Append a Promotion Log row to the active rubric. Version-bump remains manual. |
| `zachflow-kb:sync` | Embedded mode: no-op. Remote mode (v1.1+): `git pull --ff-only` from KB remote. |

Each skill's `SKILL.md` (under `.claude/skills/zachflow-kb/<op>/SKILL.md`) is the authoritative protocol; agents invoke them via the Skill tool.

## Schemas reference

### Pattern (`schemas/learning/pattern.schema.json`)

Required fields: `id`, `title`, `category`, `severity`, `source_sprint`, `discovered_at`, `frequency`, `last_seen`, `description`, `detection`, `prevention`, `contract_clause`, `schema_version`.

Enums:
- `category`: `correctness | completeness | integration | edge_case | code_quality | design_proto | design_spec`
- `severity`: `critical | major | minor`

ID format: `{category}-{NNN}` (zero-padded 3 digits). Example: `correctness-001`, `design_proto-014`.

### Rubric (`schemas/learning/rubric.schema.json`)

Required frontmatter fields: `version` (int), `status` (`active | superseded`), `superseded_by` (int or null), `schema_version`. Body is markdown with `## Clauses` and `## Promotion Log` sections.

### Reflection (`schemas/learning/reflection.schema.json`)

Required frontmatter fields: `sprint_id`, `domain`, `completed_at`, `outcome` (`pass | fail | partial`), `schema_version`. Optional: `related_patterns` (array of pattern ids). Body is markdown narrative.

`domain` is a free string matching `^[a-z][a-z0-9-]*$` — use whatever identifier makes sense for your project (e.g., `auth`, `payments`, `mobile-app`).

## Validation

zachflow runs **two layers** of validation:

1. **Skill-inline** — each KB skill's protocol includes a `python3` snippet that parses the file post-write and verifies required keys + basic patterns. Catches malformed output before commit.

2. **CI smoke** (`tests/kb-smoke.sh`) — runs in CI on every push. Verifies:
   - All schema files in `schemas/learning/` are valid JSON Schema (draft 2020-12).
   - All KB SKILL.md files have correct YAML frontmatter and `name: zachflow-kb:*` prefix.

zachflow does NOT validate user KB content (`.zachflow/kb/`) in CI by default — that's user-space, embedded-mode philosophy. If you want stricter validation, you can extend `tests/kb-smoke.sh` to walk `.zachflow/kb/` (forward-compatible).

## Lifecycle integration with Sprint workflow

| Phase | KB skill | Purpose |
|-------|----------|---------|
| 2 (Spec) | `zachflow-kb:read type=pattern` | Load prior patterns to inform task decomposition. |
| 4.1 (Contract) | `zachflow-kb:read` | Auto-inject critical patterns' contract_clause into Done Criteria. |
| 4.4 (Evaluate) | `zachflow-kb:read type=rubric` | Load active rubric clauses for evaluation criteria. |
| 6 (Retro) | `zachflow-kb:write-pattern`, `update-pattern`, `write-reflection`, `promote-rubric` | Record new patterns, bump frequencies, log reflection, promote rubric clauses. |

## External integrations (plugins)

External integrations like Notion sync, Slack notifications, etc. are NOT part of zachflow core. They will live as optional plugins under `plugins/` (post-v1.0). Reference: the `zzem-orchestrator` ancestor used `zzem-kb:sync-prds-from-notion` and `zzem-kb:sync-active-prds`; these are NOT included in zachflow v1.0.

## Migration from `zzem-orchestrator` users

If you have existing `~/.zzem/kb/learning/` content from the legacy `zzem-orchestrator` system, you can copy individual pattern/reflection files into `<your-project>/.zachflow/kb/learning/` after running `bash scripts/kb-bootstrap.sh`. There is no automated migration tool in v1.0 — the file formats are compatible since zachflow's schemas are direct ports of the source.
```

- [ ] **Step 4.2: Verify the file is valid markdown (basic check)**

```bash
[ -s ~/dev/personal/zachflow/docs/kb-system.md ] && echo "exists, non-empty"
head -1 ~/dev/personal/zachflow/docs/kb-system.md
# Balanced code fences
fence_count=$(grep -c '^```' ~/dev/personal/zachflow/docs/kb-system.md)
[ $((fence_count % 2)) -eq 0 ] && echo "fences balanced ($fence_count)" || echo "FAIL: unbalanced fences"
```

Expected: `exists, non-empty` + `# Knowledge Base` + `fences balanced` (even number).

- [ ] **Step 4.3: Commit**

```bash
cd ~/dev/personal/zachflow
git add docs/kb-system.md
git commit -m "docs(kb): expand kb-system.md to v1.0 (skills, schemas, validation, lifecycle)"
```

---

## Task 5: CI smoke check + workflow integration

**Files:**
- Create: `~/dev/personal/zachflow/tests/kb-smoke.sh`
- Modify: `~/dev/personal/zachflow/.github/workflows/ci.yml`

- [ ] **Step 5.1: Create `tests/` directory if absent**

```bash
mkdir -p ~/dev/personal/zachflow/tests
```

- [ ] **Step 5.2: Write `tests/kb-smoke.sh`**

Write `~/dev/personal/zachflow/tests/kb-smoke.sh` with this exact content:

```bash
#!/usr/bin/env bash
# tests/kb-smoke.sh — minimal CI smoke check for zachflow KB
#
# Validates:
#   1. All schemas/learning/*.json are valid JSON.
#   2. All schemas declare $schema as draft 2020-12.
#   3. All .claude/skills/zachflow-kb/*/SKILL.md have valid YAML frontmatter
#      with name: zachflow-kb:<op>.
#
# Does NOT validate user KB content (.zachflow/kb/) — that's user-space per
# embedded-mode philosophy. Extend if your project wants stricter checks.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running KB smoke check at: $PROJECT_ROOT"

# 1. Schema files are valid JSON
for f in "${PROJECT_ROOT}"/schemas/learning/*.json; do
  python3 -c "import json; json.load(open('$f'))" || {
    echo "FAIL: $f is not valid JSON"
    exit 1
  }
done
echo "  [1/3] schemas/learning/*.json — valid JSON"

# 2. Schemas declare draft 2020-12
for f in "${PROJECT_ROOT}"/schemas/learning/*.json; do
  python3 -c "
import json
data = json.load(open('$f'))
assert '\$schema' in data, '\$schema missing in $f'
assert data['\$schema'].endswith('draft/2020-12/schema'), 'wrong dialect: ' + data['\$schema']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [2/3] schemas/learning/*.json — draft 2020-12"

# 3. KB skill SKILL.md frontmatter
for f in "${PROJECT_ROOT}"/.claude/skills/zachflow-kb/*/SKILL.md; do
  python3 -c "
import yaml
content = open('$f').read()
assert content.startswith('---'), '$f no frontmatter'
end = content.find('---', 3)
assert end > 0, '$f unterminated frontmatter'
fm = yaml.safe_load(content[3:end])
assert 'name' in fm, '$f missing name'
assert fm['name'].startswith('zachflow-kb:'), '$f wrong name prefix: ' + fm['name']
" || { echo "FAIL: $f"; exit 1; }
done
echo "  [3/3] zachflow-kb/*/SKILL.md — frontmatter OK"

echo "PASS: KB smoke check"
```

- [ ] **Step 5.3: Make executable + run locally**

```bash
chmod +x ~/dev/personal/zachflow/tests/kb-smoke.sh
bash -n ~/dev/personal/zachflow/tests/kb-smoke.sh && echo "syntax OK"
bash ~/dev/personal/zachflow/tests/kb-smoke.sh
```

Expected:
- `syntax OK`
- `Running KB smoke check at: /Users/zachryu/dev/personal/zachflow`
- 3 step-by-step lines
- `PASS: KB smoke check`

- [ ] **Step 5.4: Add KB smoke step to CI workflow**

Read `~/dev/personal/zachflow/.github/workflows/ci.yml`.

Add a new step after the existing `ZZEM-leak scan` step (which is the last step in the `smoke` job). The new step:

```yaml
      - name: KB smoke check
        run: bash tests/kb-smoke.sh
```

Use Edit to insert this step. The exact insertion point is after the `ZZEM-leak scan` step's last line (which contains `echo "PASS: clean of ZZEM literals"`). Add it as a sibling step.

After Edit, verify with:

```bash
cat ~/dev/personal/zachflow/.github/workflows/ci.yml
```

Confirm the new `KB smoke check` step is present.

- [ ] **Step 5.5: Verify ci.yml YAML is still valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('/Users/zachryu/dev/personal/zachflow/.github/workflows/ci.yml')); print('yaml OK')"
```

Expected: `yaml OK`.

- [ ] **Step 5.6: Commit**

```bash
cd ~/dev/personal/zachflow
git add tests/kb-smoke.sh .github/workflows/ci.yml
git commit -m "feat(ci): add KB smoke check (schemas + skill frontmatter)"
```

---

## Task 6: CHANGELOG entry + final smoke verification + tag

**Files:**
- Modify: `~/dev/personal/zachflow/CHANGELOG.md`

- [ ] **Step 6.1: Update CHANGELOG.md**

Read `~/dev/personal/zachflow/CHANGELOG.md`. Add a new section under the existing `## [Unreleased]` heading, OR add a new versioned section if you want to mark Sprint 1 as a checkpoint.

Use Edit to add this entry directly after the existing `### Notes` section (or as a new top-level section under `## [Unreleased]`):

Find this block:
```markdown
### Notes
- v1.0 ships after Sprints 1–4.
```

Replace it with:
```markdown
### Notes
- v1.0 ships after Sprints 1–4.

## [0.2.0-sprint-1] — 2026-04-27

### Added
- KB embedded mode: 6 skills under `.claude/skills/zachflow-kb/` (read, write-pattern, update-pattern, write-reflection, promote-rubric, sync).
- Learning schemas (`schemas/learning/{pattern,rubric,reflection}.schema.json`) — draft 2020-12.
- `kb-bootstrap.sh` expanded to seed initial active rubric (`learning/rubrics/v1.md`).
- `tests/kb-smoke.sh` — CI smoke check for KB schemas + SKILL.md frontmatter.
- KB smoke step in `.github/workflows/ci.yml`.
- `docs/kb-system.md` expanded to v1.0 reference (modes, KB_PATH resolution, skills, schemas, validation, lifecycle).

### Changed
- `domain` enum in reflection schema relaxed from ZZEM-specific 4-value enum to free string matching `^[a-z][a-z0-9-]*$`. Per-project domain identifiers now allowed.

### Deferred to v1.1+
- KB remote mode wizard (`zachflow kb migrate --remote=<url>`).
- `products` axis (prd, events, active-prds).
- External integration plugins (Notion sync, etc.).
- Full Node validator port (filename-id matching, unique IDs, backwards-compat checks).
```

- [ ] **Step 6.2: Run end-to-end smoke**

```bash
cd ~/dev/personal/zachflow

# 1. Re-bootstrap (clean state)
rm -rf .zachflow
bash scripts/kb-bootstrap.sh

# 2. Verify rubric v1 seeded
[ -f .zachflow/kb/learning/rubrics/v1.md ] && echo "rubric v1 seeded"

# 3. Run KB smoke
bash tests/kb-smoke.sh

# 4. Run existing leak scan (Sprint 0's ci check)
grep -rE 'ZZEM|zzem-orchestrator|MemeApp|meme-api|meme-pr|zach-wrtn|wrtn\.io|zzem-kb' \
  --exclude-dir=.git \
  --exclude-dir=node_modules \
  --exclude-dir=.zachflow \
  --exclude='CHANGELOG.md' \
  --exclude='docs/roadmap.md' \
  --exclude='docs/llm-platform-coupling.md' \
  --exclude='.github/workflows/ci.yml' \
  . > /dev/null && echo "leak scan FAIL" || echo "leak scan PASS"

# 5. Cleanup smoke artifacts
rm -rf .zachflow

# 6. Verify all bash scripts still pass syntax
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do
  bash -n "$f" || { echo "SYNTAX ERROR: $f"; exit 1; }
done
echo "all scripts syntax OK"
```

Expected output (no failures):
- `zachflow KB initialized at .../.zachflow/kb (embedded mode)`
- `rubric v1 seeded`
- `PASS: KB smoke check` (with 3 step lines before)
- `leak scan PASS`
- `all scripts syntax OK`

- [ ] **Step 6.3: Final git status check**

```bash
cd ~/dev/personal/zachflow
git status
```

Expected: `nothing to commit, working tree clean`. (`.zachflow/` was deleted in step 6.2.5.)

- [ ] **Step 6.4: Commit CHANGELOG**

```bash
cd ~/dev/personal/zachflow
git add CHANGELOG.md
git commit -m "docs(changelog): Sprint 1 — KB embedded mode (0.2.0-sprint-1)"
```

- [ ] **Step 6.5: Tag the Sprint 1 milestone**

```bash
cd ~/dev/personal/zachflow
git tag -a v0.2.0-sprint-1 -m "Sprint 1 — KB embedded mode complete (6 skills + 3 schemas + bootstrap + smoke)"
git tag -l --format='%(refname:short) - %(subject)' | tail -5
```

Expected: tag created. Output shows both `v0.1.0-bootstrap` and `v0.2.0-sprint-1`.

- [ ] **Step 6.6: Final commit history audit**

```bash
cd ~/dev/personal/zachflow
git log --oneline | head -10
```

Expected: 6 new commits from Sprint 1 (Tasks 1–6) + 14 from Sprint 0 = ~20 commits total. Latest is the CHANGELOG commit.

---

## Sprint 1 Done Criteria

- [ ] 3 schema files at `schemas/learning/*.json` — all valid JSON, draft 2020-12
- [ ] 6 SKILL.md files at `.claude/skills/zachflow-kb/<op>/SKILL.md` — all with valid frontmatter, name `zachflow-kb:<op>`
- [ ] `scripts/kb-bootstrap.sh` seeds rubric v1 on fresh init, idempotent on re-run
- [ ] `tests/kb-smoke.sh` runs locally and PASSes
- [ ] `.github/workflows/ci.yml` includes KB smoke step
- [ ] `docs/kb-system.md` is the v1.0 reference (modes, schemas, lifecycle)
- [ ] `CHANGELOG.md` has the `0.2.0-sprint-1` entry
- [ ] Tag `v0.2.0-sprint-1` exists
- [ ] No ZZEM-leak (existing scan still passes)
- [ ] Working tree clean

---

## Notes for Sprint 2+

- Sprint 2 (`workflow-split`): introduces `workflows/{sprint,qa-fix,_shared}/` and extracts the Build Loop primitive. KB skills (this sprint's output) become callable from any workflow's phase markdown.
- Sprint 3 (`stack-adapter`): `init-project.sh` wizard fills teammate placeholders. The wizard may also configure KB mode (embedded default vs explicit remote URL).
- Sprint 4 (`gallery-split` + release): `zachflow-gallery` package, `npx create-zachflow` wrapper, LICENSE/CI/release prep.

KB skills (this sprint) are forward-compatible with all of these — they don't depend on workflow structure or any future stack adapter system.
