# ADR-0001: Adopt OKF-Compatible Local Product KB Subset

**Date**: 2026-06-24
**Status**: accepted
**Deciders**: zachflow maintainers

## Context

zachflow's KB currently preserves learning memory: defect patterns, evaluator rubrics, and sprint reflections. Sprint retrospectives also produce durable product facts such as features, APIs, policies, decisions, and terminology, but there is no validated long-term place to store them. The upstream Open Knowledge Format (OKF) provides useful file-format conventions, while Google Cloud Knowledge Catalog and related enrichment tools would add external infrastructure that conflicts with zachflow's local Git-based embedded KB model.

## Decision

We adopt an OKF-compatible local product KB subset under `.zachflow/kb/products/`. The subset uses Markdown bodies, YAML frontmatter, `index.md`, stable path-like resource IDs, tags, source sprint citations, source file citations, and cross-links. We do not adopt Google Cloud Knowledge Catalog, BigQuery crawlers, Vertex AI enrichment, or remote OKF pull/push as core dependencies.

## Alternatives Considered

### Full Google Cloud Knowledge Catalog Adoption

- **Pros**: Managed metadata tooling, cloud-native enrichment path, closer alignment with the upstream reference implementation.
- **Cons**: Requires cloud services and credentials for a core workflow that is currently local and repository-native.
- **Why not**: It would make embedded KB usage heavier and would violate the goal that zachflow works with local Git files and no external network dependency.

### Keep Product Knowledge Outside The KB

- **Pros**: No schema or workflow changes.
- **Cons**: Product facts remain scattered across PRDs, contracts, retrospectives, and sprint artifacts, making future sprint context brittle.
- **Why not**: The Sprint workflow needs durable product/domain memory, not only failure-pattern memory.

### Add A SQLite Or Vector Database Backend

- **Pros**: Faster querying and richer retrieval could be added later.
- **Cons**: Adds a second source of truth and migration burden before the document format is stable.
- **Why not**: Markdown plus YAML frontmatter is enough for the first product KB foundation and keeps review/audit in normal Git diffs.

## Consequences

### Positive

- Product facts can be validated, reviewed, versioned, and cited like other KB content.
- Sprint workflows can later read product context through `zachflow-kb:*` protocols instead of direct ad hoc filesystem scans.
- The core remains cloud-independent while still using OKF-compatible conventions.

### Negative

- zachflow must maintain local schemas and workflow docs for its OKF subset.
- Product KB write paths need deduplication rules so agents update by stable `resource` instead of creating near-duplicates.

### Risks

- Inferred facts could pollute the KB; mitigate with `confidence`, required source citations, and retrospective candidate review.
- Upstream OKF may evolve; mitigate by documenting this as an OKF-compatible subset rather than full compliance.
