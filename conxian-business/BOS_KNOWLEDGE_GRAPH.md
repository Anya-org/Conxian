# BOS Typed Knowledge Graph Specification
**Status:** DRAFT (Alignment with Agentic OS standards)

## 1. Overview
The Conxian BOS Knowledge Graph provides a structured layer above flat Markdown pages, enabling precise navigation, discovery, and impact analysis for autonomous agents.

## 2. Entity Schema
All entities in the BOS Knowledge Graph MUST be typed and categorized:

| Type | Description | Attributes |
| :--- | :--- | :--- |
| **Person** | Individual actor/stakeholder | `id`, `name`, `role`, `opinions` |
| **Project** | A discrete objective or initiative | `id`, `title`, `owner_id`, `status`, `timeline` |
| **Library** | Reusable code or protocol module | `id`, `name`, `version`, `repository` |
| **Concept** | Theoretical or domain-specific idea | `id`, `definition`, `origin` |
| **File** | A physical artifact in the codebase | `path`, `purpose`, `owners` |
| **Decision** | An architectural or operational choice | `id`, `summary`, `rationale`, `status` |

## 3. Relationship Schema
Relationships between entities carry semantic weight and confidence scores:

| Predicate | Inverse | Description |
| :--- | :--- | :--- |
| **uses** | **used_by** | A depends on B for functionality. |
| **depends_on** | **dependency_of** | A requires B to be present/completed. |
| **contradicts** | **contradicts** | A claims something incompatible with B. |
| **caused** | **resulted_from** | A was the primary driver for B. |
| **fixed** | **fixed_by** | A resolved the issue/bug B. |
| **supersedes** | **superseded_by** | A replaces and invalidates B. |

### Metadata Fields
- **Source**: URI or file path where the relationship was discovered.
- **Confidence**: 0.0 to 1.0 (0.9+ for verified source truth).
- **Timestamp**: ISO-8601 creation/update date.

## 4. Extraction Workflow (Crystallization)
When an agent completes a session, it MUST:
1. **Identify Entities**: Extract new or existing entities mentioned.
2. **Assign Relationships**: Map connections with appropriate predicates.
3. **Score Quality**: Assign a quality score (>0.8 required for auto-filing).
4. **Flag Contradictions**: Alert if new data contradicts existing graph nodes.

## 5. Implementation (Sovereign Mirror)
- **Primary (Search)**: Vector search (Postgres/pgvector) for semantic retrieval.
- **Secondary (Structure)**: JSON-LD export for graph traversal.
- **Anchor**: State roots of the knowledge graph are anchored to Stacks/Bitcoin.

---
*Inspired by Andrej Karpathy's LLM Wiki and agentmemory.*
