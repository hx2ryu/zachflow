# Variant Comparison: {ScreenName}

> 3-DE-variant comparison gate. Sprint Lead surfaces this to the user.

## Inputs

```yaml
task_id: "{task-id}"
screen_name: "{ScreenName}"
generated_at: "{ISO8601}"
trigger: "{fabrication_risk_medium | variants_required | user_request}"
shared_snapshot_hash: "{hash of Frozen Snapshot — proves identical inputs}"
```

## Variants

```yaml
variants:
  - id: A
    directive: Conservative
    prototype_path: "runs/{sprint-id}/prototypes/app/{task-id}/variants/A/prototype.html"
    spec_path:      "runs/{sprint-id}/prototypes/app/{task-id}/variants/A/screen-spec.yaml"
    quality_score:
      anti_slop_audit: passed | partial | failed
      fabrication_risk: none | low | medium
      file_size_bytes: {N}
    diff_highlights:
      - "{one-liner — the most prominent difference vs other variants}"
      - "{another}"
  - id: B
    # same structure
  - id: C
    # same structure
```

## Side-by-Side Screenshot

```
runs/{sprint-id}/prototypes/app/{task-id}/variants/_comparison.png
```
3-up horizontal layout (A | B | C). capture-screenshots.ts auto-composites when it detects a variants directory.

## User Decision

| Choice | Effect |
|--------|--------|
| **A** / **B** / **C** | Promote the chosen variant to `prototype.html` (parent of variants/). The other two move to `variants/_archive/`. |
| **mix** | User specifies what they want from each ("A's header + B's card layout"). Spawn a fresh DE instance with the mix instructions and regenerate in single mode. |
| **stop** | None of the three is acceptable. Possible PRD gap — Sprint Lead adds the gap to prd-gaps.md and triggers Phase 3.4 Amendment. |
