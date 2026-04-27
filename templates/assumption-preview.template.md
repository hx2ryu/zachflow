# Assumption Preview: {ScreenName}

> Document of assumptions and design choices the Design Engineer surfaces before Step C (HTML generation).
> Sprint Lead presents this to the user for early approval or correction.
> YAML / tables only — no prose.

## Meta

```yaml
task_id: "{task-id}"
screen_name: "{ScreenName}"
generated_at: "{ISO8601}"
spec_fabrication_risk: "{none | low | medium}"
spec_context_coverage: "{why_linked ratio}"
```

## Inferred Layout Decisions

Component placement / hierarchy decisions DE inferred without explicit PRD/task guidance. Each item must list rationale and alternatives.

```yaml
inferred_layout:
  - decision: "{layout decision summary}"
    rationale: "{why — citation: DESIGN.md §N or pattern {key}}"
    alternatives:
      - "{alternative 1 — what the user might pick if this assumption is wrong}"
      - "{alternative 2}"
    would_break_if: "{rework scope if this assumption is wrong — e.g. 'Body scroll structure full rebuild'}"
```

## Placeholder / Content Choices

Locations DE filled with placeholders or sample data because real content isn't available. Mark where real content is required.

```yaml
placeholders:
  - component_id: "{#html-id}"
    kind: "{image | text | avatar | list-item | ...}"
    current: "{summary of placeholder value}"
    source: "{context-engine.assets.{key} | hardcoded | pattern-default}"
    needs_real_content: "{true | false}"
    note: "{notable details}"
```

## Interactions Not In PRD

Screen Spec interactions that aren't directly derived from PRD ACs. DE added these by pattern/convention.

```yaml
implicit_interactions:
  - interaction: "{summary of trigger+target+action from spec interactions[]}"
    rationale: "{why added — e.g. 'pull-to-refresh is conventional for lists'}"
    removable: "{true | false — can the user ask to remove this?}"
```

## Anti-Slop Pre-Check (predicted)

Items DE self-flags as likely to fail Pass 6 audit.

```yaml
anti_slop_risks:
  - item: "{checklist number 1~7}"
    risk: "{predicted failure cause}"
    mitigation: "{how to resolve before Pass 6}"
```

## Gate Questions for Sprint Lead

Questions to ask the user (Sprint Lead summarises and surfaces).

```yaml
gate_questions:
  - "{question 1 — yes/no or a/b/c form}"
  - "{question 2}"
```

## User Action

| Choice | Effect |
|--------|--------|
| **proceed** | Continue to Step C (HTML generation). All assumptions approved. |
| **adjust** | Direct change to specific `inferred_layout` or `placeholder` items. DE updates Screen Spec, then re-emits the preview. |
| **stop** | Halt prototype generation for this screen. PRD reinforcement needed — Sprint Lead triggers a PRD Amendment. |
