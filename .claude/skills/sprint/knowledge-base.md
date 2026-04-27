# Knowledge Base Search/Write Protocol

> Protocol for the Sprint Lead to reference and update the Knowledge Base in each sprint phase.
>
> **All KB access must go through the `zachflow-kb:*` skills.** Direct filesystem reads/writes are forbidden.

## KB Location

- **Source of truth**: the configured KB (embedded `.zachflow/kb/` by default, or an optional remote git repo via `kb.remote` in sprint-config).
- **Local clone**: `$KB_PATH` (default `~/.zachflow/kb`) — the SessionStart hook auto-clones/pulls.
- **Content layout** (two axes):
  - Axis 1 (self-improving): `learning/patterns/*.yaml`, `learning/rubrics/*.md`, `learning/reflections/*.md`
  - Axis 2 (product specs): `products/<product-slug>/prd.md` + `events.yaml`

---

## Skills

| Skill | Purpose |
|-------|---------|
| `zachflow-kb:sync` | Fast-forward pull on entry to each Phase (before first KB access in Phase 2/3/4, before writes in Phase 6) |
| `zachflow-kb:read` | Read (type=pattern\|rubric\|reflection\|prd\|events, filters: category/domain/status/limit/product) |
| `zachflow-kb:write-pattern` | Create a new pattern |
| `zachflow-kb:update-pattern` | Update an existing pattern's frequency/severity |
| `zachflow-kb:write-reflection` | Record retrospective at the end of a sprint |
| `zachflow-kb:promote-rubric` | Promote a pattern → evaluator rubric clause (Phase 6 §6.7a) |
| `zachflow-kb:sync-prds-from-notion` | Sync a Notion database → `products/notion-prds.yaml` (requires an external integration plugin — not part of zachflow core) |
| `zachflow-kb:sync-active-prds` | Mirror in-progress feature PRD bodies → `products/active-prds/{notion-id}.md` (requires an external integration plugin — not part of zachflow core) |

> **Sync timing**: The SessionStart hook (`scripts/kb-bootstrap.sh`) attempts ff-only at bootstrap, but upstream may update during a long-running sprint. Call `zachflow-kb:sync` before the first KB access in each phase to ensure freshness.

---

## KB Search Protocol

### When to Search

| Phase | Trigger | Purpose | Skill call |
|-------|---------|---------|------------|
| Phase 2 (Spec) | At spec design start | Reinforce spec with correctness, integration patterns | `zachflow-kb:read type=pattern category=correctness` (and integration) |
| Phase 2 (Spec) | Domain learning | Reference past retrospectives | `zachflow-kb:read type=reflection domain=<domain> limit=3` |
| Phase 3 (Prototype) | At prototyping start | design_proto, design_spec patterns | `zachflow-kb:read type=pattern category=design_proto` |
| Phase 4.1 (Contract) | When drafting Done Criteria | Reflect every relevant pattern's contract_clause into Criteria | `zachflow-kb:read type=pattern category=<relevant>` |
| Phase 4.4 (Evaluate) | When establishing evaluation criteria | Load the latest rubric + include the patterns' detection criteria | `zachflow-kb:read type=rubric status=active`, `zachflow-kb:read type=pattern ...` |

### Relevance Mapping (task type → category)

| Task type | Preferred categories |
|-----------|----------------------|
| API endpoint implementation | correctness, integration |
| DTO/model design | correctness (especially serialization) |
| FE component implementation | completeness, code_quality |
| BE/FE integration | integration, correctness |
| Navigation/routing | completeness |
| Prototype creation | design_proto, design_spec |
| Pagination implementation | correctness (cursor-wrap pattern) |
| Hooks/utilities | completeness (call sites included) |

### Search Output Format

When reflecting KB search results into the Contract:

```markdown
## KB-Informed Done Criteria

> Found {N} relevant patterns in the Knowledge Base, reflected into Done Criteria:

- [ ] [correctness-001] Do not re-wrap DTOs in pagination Controllers
- [ ] [integration-001] BE DTO field names must match FE type field names
  ...
```

Injection criteria (consistent with sprint-contract.template.md):
- `severity: critical` → always inject
- `severity: major` + `frequency >= 2` → inject
- `severity: minor` → do not inject

---

## KB Write Protocol

### When to Write

| Phase | Trigger | Recorded | Skill |
|-------|---------|----------|-------|
| Phase 6 (Retro) | After pattern-digest.yaml is generated | New code patterns | `zachflow-kb:write-pattern` |
| Phase 6 (Retro) | Existing pattern re-observed | frequency/severity update | `zachflow-kb:update-pattern` |
| Phase 6 (Retro) | At sprint close | Domain learning record | `zachflow-kb:write-reflection` |
| Phase 6 (Retro) | quality-report fabrication_risk detected | Design pattern | `zachflow-kb:write-pattern category=design_proto` |

### How to Write

#### Step 1: Match Existing

```
1. zachflow-kb:read type=pattern category=<category>
2. Compare new pattern's title/description with existing patterns
3. If same pattern → zachflow-kb:update-pattern (Step 2a)
4. If new pattern → zachflow-kb:write-pattern (Step 2b)
```

#### Step 2a: Update Existing Pattern

Call `zachflow-kb:update-pattern id=<pattern-id>`. The skill applies frequency+1 and last_seen=<current sprint-id> via rebase-retry.

#### Step 2b: Create New Pattern

Call `zachflow-kb:write-pattern` with the category only; the skill auto-numbers the next ID ({category}-{NNN+1}) + schema validation + commit/push. Conflicts handled via rebase-retry.

### Design Pattern Recording

When fabrication_risk is detected in quality-report:

```yaml
category: "design_proto"  # or "design_spec"
severity: "{according to fabrication_risk level}"
description: |
  {description of the design issue found in the prototype}
prevention: |
  {refer to docs/designs/README.md or strengthen Figma references}
```

---

## Auto-Cleanup Rules

After KB writes in Phase 6, apply these rules (target for Phase 2+ automation; currently the Sprint Lead reviews periodically by hand):

| Condition | Action |
|-----------|--------|
| frequency >= 3 | Candidate for Sprint Contract template inclusion |
| frequency >= 5 | Promote to a required clause in the Contract template |
| 3+ consecutive sprints not observed | Mark status=archived |

### Cleanup Check Method

```
Subtract last_seen sprint number from current sprint number; if 3+, archive.
Example: current sprint-005, last_seen sprint-001 → 4 sprints not observed → archived
```

---

## Failure Handling

- **CI rejection**: `zachflow-kb:*` skills return errors immediately on push failure. Inspect schema violation details, fix, retry.
- **Concurrent write conflicts**: rebase-retry built in. If it still fails after retry, manual investigation is required.
- **Bootstrap failure**: If `$KB_PATH` is missing, run the SessionStart hook (`scripts/kb-bootstrap.sh`) manually.
