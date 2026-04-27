# PRD Amendment Proposal: {sprint-id}

> Generated from Phase 3 Prototype Revision Analysis
> Source PRD: {prd-file}
> Revision Stats: {N} screens revised, {M} total revision cycles

## Summary

{1–2 sentences: how many screens had what kind of gaps}

## Amendments

### AMD-{N}: {title}
- **Category**: {new_ac | clarify_ac | add_ui_spec | implicit_req | add_rule}
- **Related AC**: AC {X.Y} (or "new")
- **Related screen**: {ScreenName}
- **Revision evidence**: {feedback summary + revision type (minor/major)}
- **Current PRD content**: {existing AC text or "n/a"}
- **Proposed amendment**:
  - Given {condition}
  - When {action}
  - Then {expected result}
- **Impact area**: {Backend task | App task | Both | Business rule}
- **Apply when**: {immediately | before Phase 4 | next sprint}

---

## Revision Evidence

| Screen | Task ID | Revision count | Type | Feedback summary | Amendment ID |
|--------|---------|----------------|------|------------------|--------------|
| {ScreenName} | {task-id} | {N} | {minor/major} | {one-line} | AMD-{N} |

## Amendment classification

| Revision signal | PRD gap type | Category |
|-----------------|--------------|----------|
| Major revision + new component added | AC missing | `new_ac` |
| Minor revision + text/label change | AC ambiguous | `clarify_ac` |
| Major revision + layout structure change | UI spec missing | `add_ui_spec` |
| fabrication_risk: medium + approved | implicit assumption approved | `implicit_req` |
| Same pattern revised across multiple screens | Common rule missing | `add_rule` |

## Recommendations

- [ ] {Tasks/specs that need updating once amendments are applied}
- [ ] {Whether API contract changes are needed}
- [ ] {Items to land before Phase 4}

## Disposition

| AMD ID | Title | Verdict | Notes |
|--------|-------|---------|-------|
| AMD-{N} | {title} | {apply / defer / dismiss} | {reason} |
