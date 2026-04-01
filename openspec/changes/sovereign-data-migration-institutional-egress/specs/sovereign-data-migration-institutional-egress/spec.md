# Sovereign Data Migration & Institutional Egress Specification

## 0. Conventions & Definitions

This specification uses requirement keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) as described in RFC 2119 and RFC 8174.

- **SAB**: Conxian Sovereign Autonomous Business.
- **Canonical system of record**: authoritative source for correctness (Stacks L1).
- **Derived dataset / read model**: a deterministic projection derived from canonical truth.
- **Glass Node**: a read-only system that exposes derived datasets and proofs of correctness.
- **Institutional egress**: standardized read-only export of accounting-relevant datasets to external subledgers.
- **External subledger**: any external accounting system ingesting Conxian datasets (ERP subledger, auditor subledger, reporting pipeline).
- **Proof/visual-proof flow**: any workflow that presents derived analytics as evidence (dashboards, reports, attestations).

## 1. Purpose

Define Phase 5 "clean break" constraints for Supabase and Neon, and define institutional accounting egress as standardized read-only subledger export. This spec synthesizes and sharpens existing SAB migration and treasury/oracle work without creating a duplicate execution lane.

## 2. Scope

In scope:
- Supabase phase-out requirements for proof/visual-proof analytics.
- Neon phase-out requirements for `conxian-nexus` transactional persistence.
- Institutional egress policy and verifiability requirements for external settlement logs and ISO 20022 outputs.

Out of scope:
- Implementation details for any specific ERP vendor.
- Any write-path integration from external subledgers back into Conxian.

## 3. Requirements

### 3.1 Phase 5 clean-break constraints

1. **Canonical truth**: Stacks L1 **MUST** remain the canonical system of record for SAB-critical business state.
2. **Replaceability**: Any off-chain datastore that is not the canonical system of record **MUST** be replaceable without changing truth, by rebuilding from Stacks L1 events/state.
3. **Correctness isolation**: Supabase and Neon **MUST NOT** be required for protocol correctness, final auditability, or institutional accounting truth.

### 3.2 Supabase phase-out (proof/visual-proof analytics)

1. **No correctness dependency**: Supabase **MUST NOT** be treated as an authoritative source for any proof/visual-proof dataset.
2. **Verifiable analytics layer**: Proof/visual-proof flows **SHOULD** move to a verifiable analytics layer (e.g., Space and Time) or an equivalent system that can be treated as a derived query layer.
3. **Deterministic snapshots**: For any proof/visual-proof dataset, a deterministic snapshot export **MUST** be defined (schema + canonical ordering + serialization format).
4. **On-chain checkpointing**: Proof/visual-proof datasets **MUST** be checkpointed on-chain using a deterministic scheme (for example the SAB-CHECKPOINT-V1 scheme defined in the [SAB Datastore Mapping Specification](../../../../specs/sab-datastore-mapping/spec.md)).

### 3.3 Neon phase-out (sovereign transactional SQL for Nexus)

1. **Sovereign baseline**: `conxian-nexus` persistence **MUST** have a sovereign/self-hostable PostgreSQL baseline.
2. **No Neon-only assumptions**: Nexus persistence logic **MUST NOT** rely on Neon-only behaviors (branching workflows, proprietary pooling semantics, hosted-only extensions).
3. **Local development parity**: Local development **MUST** be able to run Nexus with Postgres + Redis using developer-controlled infrastructure (docker-compose or equivalent).
4. **Compatibility checklist**: Before cutover, compatibility checks **MUST** explicitly cover:
   - PostgreSQL version and extension set.
   - Schema migration tooling and ownership.
   - Backup and restore semantics.
   - Connection pooling and TLS requirements.

### 3.4 Institutional egress policy (read-only subledger export)

1. **Read-only framing**: Institutional egress **MUST** be treated as a standardized read-only export of derived datasets.
2. **No write-path coupling**: External subledgers **MUST NOT** be required (or trusted) to write data back into Conxian for correctness.
3. **Nexus as Glass Node**: `conxian-nexus` **SHOULD** be the primary producer of egress datasets as a Glass Node (derived datasets + proofs).
4. **Gateway as institutional API**: `conxian-gateway` **SHOULD** be the institutional interface for:
   - serving egress datasets,
   - serving verification materials,
   - rendering standardized message formats (e.g., ISO 20022) over verifiable datasets.
5. **Burn-block anchoring**: Egress datasets **MUST** identify finality using Bitcoin-anchored height (`burn-block-height`) wherever final settlement interpretation is required.
6. **No secret egress**: Egress datasets **MUST NOT** contain:
   - seed phrases, signing keys, enclave-only secrets, or any reversible key material,
   - private identity disclosures.

### 3.5 Egress dataset verifiability

1. **Dataset identity**: Every egress dataset **MUST** define a stable `dataset_id`.
2. **Deterministic record identity**: Each exported record **MUST** include enough identifiers to trace it back to canonical truth (for example `(block_height, tx_index, event_index, txid, contract_id)` or an equivalent deterministic identifier).
3. **Checkpoint verification**: External subledgers **MUST** be able to verify a snapshot by:
   - discovering the latest checkpoint root on-chain for a dataset, and
   - recomputing the dataset root from the snapshot using the published canonicalization.
4. **Mismatch handling**: Any snapshot that fails checkpoint validation **MUST** be treated as invalid and rejected/rebuilt.

## 4. Open Questions & Unsettled Decisions

| Question | Context | Impact |
| :--- | :--- | :--- |
| Verifiable analytics provider | Is Space and Time the target, or a different proof-carrying analytics layer? | Medium: affects implementation surface, but not dataset truth model. |
| Sovereign Postgres baseline | What is the Phase 5 baseline deployment target for Nexus Postgres (self-hosted, managed-but-dedicated, etc.)? | High: affects infra, local dev parity, and cutover risk. |
| Egress dataset schema | What is the minimal external settlement log schema required by CON-161/CON-164 and what is its dataset_id? | High: locks the contract for downstream subledgers. |

## 5. Acceptance Criteria

- [x] No duplicate execution lane is created; work maps to existing SAB migration and treasury/oracle issues.
- [x] Supabase and Neon phase-out work is linked to explicit pilot and cutover decisions.
- [x] Institutional egress is defined as standardized read-only subledger export with checkpoint verification.
- [x] `conxian-nexus` is positioned as the Glass Node producer for verifiable egress datasets.
