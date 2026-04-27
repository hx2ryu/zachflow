> When writing a PRD, copy this template to `docs/prds/PRD-{project}-{number}-{slug}.md`.
> Naming example: PRD-<example-sprint-id>-2-feed-interaction.md

---

```yaml
title: "(PRD title)"
domain: <project>
status: pending  # pending | in-progress | done
description: "(One-line summary — core scope and prerequisites)"
kpi: "(metric → causal link → business impact)"
notion_url: (link to Notion source, if any)
```

---

# (PRD title)

> 📋 (For multi-part PRD series) List related PRDs and their development order.
>
> 1. (PRD 1 title) — (order/condition)
> 2. (PRD 2 title) — (order/condition)

## Cross-reference rules

- (Specify what this PRD implements vs what other PRDs implement)
- (Example: "Follower count UI is built in this PRD, follow functionality itself is in PRD 3")

---

## Overview

(Describe the system/feature this PRD builds — 1–2 sentences capturing the big picture)

### Implementation scope

- (Scope item 1)
- (Scope item 2)

---

## User Stories & Acceptance Criteria

### US1: (story title)

As a (role), I want to (action) so that I get (value).

### AC 1.1: (condition name)

- Given (precondition)
- When (action)
- Then (expected result)

---

## Business rules

### (Domain rule group name)

1. (Rule 1)
2. (Rule 2)

---

## Boundary

### ALWAYS DO

1. (Things that must always be observed)

### NEVER DO

1. (Things explicitly out of scope for this version)
