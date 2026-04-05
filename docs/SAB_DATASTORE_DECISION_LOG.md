# SAB domain-to-datastore decision log

This log records target-state datastore decisions (or explicit open questions) by SAB data domain.

Baseline direction is defined in:

- [SAB datastore mapping spec](../openspec/specs/sab-datastore-mapping/spec.md)

This log exists to prevent "implicit decisions" from being made ad hoc inside migrations.

## Status and review cadence

**Last reviewed:** 2026-04-05

**Canonical live status:** https://linear.app/conxian-labs/issue/CON-329/create-sab-migration-control-plane-and-dependency-inventory

**Review cadence:** at least monthly (aligned with `SAB_MIGRATION_CONTROL_PLANE.md`), and additionally within the same PR/commit whenever a decision status changes.

Update convention: on every review, bump `Last reviewed` in the same PR/commit that updates decisions (or a dedicated PR if no other content changes are needed).

## Decision log

Status meanings:

- **Accepted**: target-state decision is made and should be implemented
- **Open**: decision still under evaluation
- **Rejected**: candidate is explicitly out-of-scope or conflicts with constraints

| Decision ID | Domain | Candidate | Status | Fit notes / constraints | Owner | Next review |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| SAB-DS-001 | Transactional application state (derived read model) | Sovereign/self-hostable PostgreSQL | Accepted | Canonical truth remains Stacks L1; Postgres is derived-only, checkpoint-validated, and rebuildable. Neon is treated as a temporary hosted deployment, not a product dependency. | Botshelo Mokoka | 2026-05-04 (update when W1 pilot scope is committed) |
| SAB-DS-008 | Transactional application state (derived read model) | Neon (hosted PostgreSQL) | Rejected | Current-state only. Must not be treated as a long-horizon dependency; avoid Neon-only behaviors (branching workflows, proprietary pooling semantics, hosted-only extensions). | Botshelo Mokoka | 2026-05-04 (revisit only if a sovereign Postgres baseline cannot be established) |
| SAB-DS-002 | Proof/visual-proof analytics (derived datasets) | Space and Time | Open | Candidate for verifiable analytics surfaces. Must satisfy: deterministic rebuild from L1 + checkpoint validation + sovereign hosting baseline. Evaluate whether proof model aligns with SAB checkpoint scheme (SAB-CHECKPOINT-V1) and whether operational control can be retained. | Botshelo Mokoka | 2026-05-04 (after https://linear.app/conxian-labs/issue/CON-331/pilot-proof-carrying-analytics-for-treasury-and-oracle-workflows) |
| SAB-DS-003 | Proof/visual-proof analytics (derived datasets) | Supabase (current) | Rejected | Treated as current-state only. Must not be correctness-critical, must not be treated as canonical, and must be phase-out compatible. | Botshelo Mokoka | 2026-05-04 (revisit only for short-lived transitional needs) |
| SAB-DS-004 | Governance + audit mirror (public discoverability) | Tableland | Open | Acceptable only as an optional mirror of on-chain audit registries; must never be required for correctness. Confirm which audit datasets benefit from decentralized SQL discoverability. | Botshelo Mokoka | 2026-05-04 (update after audit dataset inventory is complete) |
| SAB-DS-005 | Governance + audit ledger (append-only, queryable) | Fluree | Open | Candidate for governance/audit querying where "append-only + provenance" properties matter. Must remain derived from on-chain truth and must not introduce secret-bearing state. | Botshelo Mokoka | 2026-05-04 (after https://linear.app/conxian-labs/issue/CON-333/define-governance-and-immutable-record-architecture-for-sab) |
| SAB-DS-006 | Derived query layer (decentralized SQL) | Kwil | Open | Candidate for decentralized SQL query surfaces. Must not become an availability dependency for correctness; evaluate whether it should be limited to mirrors and public query ergonomics. | Botshelo Mokoka | 2026-05-04 (update when domain mappings are committed) |
| SAB-DS-007 | Institutional egress datasets (read-only subledger export) | Postgres views + deterministic exports | Accepted | Egress is read-only and proof-carrying: datasets are produced by Nexus as a Glass Node and are verifiable via on-chain checkpoints. | Botshelo Mokoka | 2026-05-04 (update after first dataset list is finalized) |

## Open questions (cross-domain)

| Question | Impact | Notes |
| :--- | :--- | :--- |
| Which domains require a decentralized/public SQL mirror vs. "Nexus query API + proofs" being sufficient? | Medium/High | This affects whether Tableland/Kwil are optional accelerators or unnecessary complexity. |
| What is the sovereign baseline for analytics workloads (compute + storage) if Space and Time is not selected? | High | Needs to reconcile verifiability, query ergonomics, and operational control. |
| What is the sovereign baseline for Postgres deployments (single-tenant managed vs. self-hosted vs. dedicated metal)? | High | Drives local-dev parity, uptime, and rollback strategy for Nexus/Gateway. |
