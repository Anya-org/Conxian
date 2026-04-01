# Design: Phase 5 Sovereign Data Migration & Institutional Egress

## 1. Architectural framing

### 1.1 Canonical truth
- **Canonical system of record** remains Stacks L1 (Clarity state + events).
- All off-chain stores are **derived** and must be deterministic rebuilds.

### 1.2 Derived read models
- **`conxian-nexus`** is the primary derived read model ("Glass Node").
  - Maintains verifiable history primitives (e.g., MMR persistence) and exposes proof surfaces.
- **PostgreSQL persistence** must be sovereign/self-hostable.
  - SaaS-hosted Postgres is acceptable only if it is not correctness-critical and can be replaced without data loss or trust assumptions.

### 1.3 Proof/visual-proof analytics
- "Visual proof" outputs (treasury dashboards, oracle reports) are treated as **presentations of derived datasets**.
- The analytics layer must be verifiable by:
  - deterministic dataset construction from L1 events/state, and
  - on-chain checkpoint anchoring (e.g., SAB-CHECKPOINT-V1).

### 1.4 Institutional egress (subledger)
- Institutional accounting egress is a **read-only export** of standardized datasets.
- External subledgers are consumers:
  - they ingest snapshots,
  - they verify them against on-chain checkpoints,
  - they do not participate in the Conxian write-path.

## 2. Phase 5 clean-break constraints

### 2.1 Supabase phase-out
- Supabase must not be a dependency for correctness, availability, or final auditability.
- Proof/visual-proof flows should target a verifiable analytics layer (e.g., Space and Time) or an equivalent that can:
  - serve read-only queries,
  - produce reproducible snapshots,
  - and support checkpoint verification.

### 2.2 Neon phase-out
- `conxian-nexus` persistence must not rely on Neon-specific features (branching, proprietary pooling, hosted-only extensions).
- Compatibility checks are explicitly required around:
  - supported PostgreSQL versions and extensions,
  - migrations and schema ownership,
  - local development orchestration (docker-compose or equivalent),
  - and backup/restore semantics.

## 3. Minimal data-flow

1. **Stacks L1** emits canonical events and state transitions.
2. **Nexus** ingests events and materializes datasets into sovereign Postgres.
3. **Checkpoints** for each dataset are anchored on-chain (audit/checkpoint registry).
4. **Gateway** exposes institutional read endpoints and ISO 20022 renderers over Nexus-derived datasets.
5. **External subledgers** ingest verified snapshots (read-only egress).

## 4. Decision gates (no new execution lane)

This spec does not introduce a separate delivery track. It introduces explicit decision gates that should be resolved inside the existing SAB migration and treasury/oracle issues:

- **Supabase cutover decision**: which dataset(s) must be served by a verifiable analytics layer and what proof/checkpoint scheme is required.
- **Neon cutover decision**: which Postgres deployment becomes sovereign baseline for `conxian-nexus` (and how local dev matches it).
- **Egress dataset definition**: what "external settlement logs" mean as a standardized subledger dataset and how they are checkpointed.
