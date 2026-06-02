# SAB domain-to-datastore decision log

This log records target-state datastore decisions (or explicit open questions) by SAB data domain.

Baseline direction is defined in:

- [SAB datastore mapping spec](../openspec/specs/sab-datastore-mapping/spec.md)

This log exists to prevent "implicit decisions" from being made ad hoc inside migrations.

## Decision log

Status meanings:

- **Accepted**: target-state decision is made and should be implemented
- **Open**: decision still under evaluation
- **Rejected**: candidate is explicitly out-of-scope or conflicts with constraints

| Decision ID | Domain | Candidate | Status | Fit notes / constraints | Owner | Next review |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| SAB-DS-001 | Transactional application state (derived read model) | Sovereign/self-hostable PostgreSQL | Accepted | Canonical truth remains Stacks L1; Postgres is derived-only, checkpoint-validated, and rebuildable. Neon is treated as a temporary hosted deployment, not a product dependency. | Botshelo Mokoka | Update after CON-330 pilot scope is finalized |
| SAB-DS-008 | Transactional application state (derived read model) | Neon (hosted PostgreSQL) | Rejected | Current-state only. Must not be treated as a long-horizon dependency; avoid Neon-only behaviors (branching workflows, proprietary pooling semantics, hosted-only extensions). | Botshelo Mokoka | Revisit only if a sovereign baseline cannot be established |
| SAB-DS-002 | Proof/visual-proof analytics (derived datasets) | Space and Time | Open | Candidate for verifiable analytics surfaces. Must satisfy: deterministic rebuild from L1 + checkpoint validation + sovereign hosting baseline. Evaluate whether proof model aligns with SAB checkpoint scheme (SAB-CHECKPOINT-V1) and whether operational control can be retained. | Botshelo Mokoka | After CON-334 domain mapping pass |
| SAB-DS-003 | Proof/visual-proof analytics (derived datasets) | Supabase (current) | Rejected | Treated as current-state only. Must not be correctness-critical, must not be treated as canonical, and must be phase-out compatible. | Botshelo Mokoka | Revisit only for short-lived transitional needs |
| SAB-DS-004 | Governance + audit mirror (public discoverability) | Tableland | Open | Acceptable only as an optional mirror of on-chain audit registries; must never be required for correctness. Confirm which audit datasets benefit from decentralized SQL discoverability. | Botshelo Mokoka | After audit dataset inventory is complete |
| SAB-DS-005 | Governance + audit ledger (append-only, queryable) | Fluree | Open | Candidate for governance/audit querying where "append-only + provenance" properties matter. Must remain derived from on-chain truth and must not introduce secret-bearing state. | Botshelo Mokoka | After governance/audit record flow mapping |
| SAB-DS-006 | Derived query layer (decentralized SQL) | Kwil | Open | Candidate for decentralized SQL query surfaces. Must not become an availability dependency for correctness; evaluate whether it should be limited to mirrors and public query ergonomics. | Botshelo Mokoka | After CON-334 domain mapping pass |
| SAB-DS-007 | Sovereign egress datasets (read-only subledger export) | Postgres views + deterministic exports | Accepted | Egress is read-only and proof-carrying: datasets are produced by Nexus as a Glass Node and are verifiable via on-chain checkpoints. | Botshelo Mokoka | Update after first dataset list is finalized |

### SAB-DS-002

Proof/visual-proof analytics (derived datasets) — Space and Time (Open). See the `SAB-DS-002` row in the decision table above for constraints and next review.

## Open questions (cross-domain)

| Question | Impact | Notes |
| :--- | :--- | :--- |
| Which domains require a decentralized/public SQL mirror vs. "Nexus query API + proofs" being sufficient? | Medium/High | This affects whether Tableland/Kwil are optional accelerators or unnecessary complexity. |
| What is the sovereign baseline for analytics workloads (compute + storage) if Space and Time is not selected? | High | Needs to reconcile verifiability, query ergonomics, and operational control. |
| What is the sovereign baseline for Postgres deployments (single-tenant managed vs. self-hosted vs. dedicated metal)? | High | Drives local-dev parity, uptime, and rollback strategy for Nexus/Gateway. |
