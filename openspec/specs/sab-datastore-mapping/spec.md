# SAB Datastore Mapping Specification

## 1. Purpose
This specification translates the Conxian Sovereign Autonomous Business (SAB) current-state inventory into target-state datastore decisions. It defines the mapping of major data domains to canonical on-chain systems of record and derived query layers.

## 2. Scope
- Mapping transactional application state.
- Mapping proof-oriented analytics.
- Mapping immutable governance and audit records.
- Identifying central versus edge responsibilities.

## 3. Requirements

### 3.1. Major Data Domain Mappings

The long-horizon direction is to make all non-secret SAB-critical business state fully on-chain. Off-chain systems may exist for performance and query ergonomics, but they must be treated as derived/indexed replicas rather than the authoritative system of record. Secrets and signing keys remain exclusively in hardware enclaves (ZSE), referenced on-chain by identifiers only.

| Data Domain | Canonical System of Record | Derived / Query Layer (Non-authoritative) | Notes |
| :--- | :--- | :--- | :--- |
| **Transactional Application State** | **Stacks L1 (Clarity contracts)** | **PostgreSQL** (currently **Neon**, later sovereign/self-hosted) | Write-path is on-chain. Postgres is a materialized read model for Nexus/Gateway sync, MMR node indexing, and service-level query performance. |
| **Proof-Oriented Analytics** | **Stacks L1 (events + state roots)** | **Supabase** (or equivalent SQL analytics layer) | Analytics datasets are derived from the on-chain event stream. Verification is anchored by on-chain checkpoints/hashes of derived datasets; canonical truth is always the raw L1 events/state. |
| **Immutable Governance & Audit** | **Stacks L1 (event log + audit registry contract)** | **Tableland** (optional mirror) | Default is on-chain auditability. Tableland is an optional public mirror when decentralized SQL materially improves discoverability without becoming a dependency for correctness. |
| **Hardware-Anchored Identity** | **StrongBox / Secure Enclave** | N/A | Mandated for Zero Secret Egress (ZSE). Private keys and DID-ZK disclosures are derived and stored in hardware, never leaving the device. |
| **High-Frequency Caching** | N/A | **Redis** | Volatile cache for millisecond-latency session management, real-time mempool tracking, and telemetry buffering. |
| **Offline Wallet Cache** | N/A | **Local SQLite** | Offline lookups and UX continuity. Must be treated as a local cache; canonical state remains on-chain. |

#### 3.1.1. Data Flow & Verification

1. **Stacks L1 emits canonical state transitions** via contract state + events.
2. **Indexers derive replicas** (Postgres/Supabase/Tableland) by consuming L1 events and projecting them into query-optimized schemas.
3. **Verification** is performed by anchoring periodic dataset checkpoints on-chain (e.g., a hash of normalized events / materialized views) and requiring indexers/clients to match those checkpoints.
4. **Mismatch handling**: any replica that fails checkpoint validation is treated as stale/corrupted and must be rebuilt from the on-chain event stream.

### 3.2. Central vs. Edge Responsibilities

#### Central Datastores (PostgreSQL, Supabase)
- **Aggregation**: Consolidating data from multiple Nexus instances.
- **Historical Persistence**: Maintaining long-term records for reporting and institutional compliance as query-optimized replicas; all compliance evidence must remain provably derivable from on-chain state and published checkpoints.
- **Query Acceleration**: Serving as derived read models for inter-module communication (e.g., Nexus to Gateway) without becoming the source of truth.

#### Edge Datastores (Enclave, Redis, Local SQLite)
- **Identity & Security**: Managing the critical path for signing and identity verification (ZSE).
- **Latency Sensitivity**: Handling high-frequency updates that would bottleneck central databases.
- **Offline Capability**: Ensuring the Conxius Wallet remains functional for local lookups without network connectivity.

### 3.3. Conditional Datastores
- **Tableland**: Identified as **Conditional**. It is acceptable only as a non-authoritative mirror of on-chain audit state and must not be required for protocol correctness.

## 4. Open Questions & Unsettled Decisions

| Question | Context | Impact |
| :--- | :--- | :--- |
| **Yield Rebalancing State** | Should yield rebalancing triggers execute fully on-chain, or remain off-chain (keeper/agent) with on-chain commitments? | High: Affects <= 5 minutes end-to-end trigger-to-finality latency targets under load. |
| **Principal Locking** | Should `cxn_locked_principal` move entirely to L1 (Stacks), with off-chain replicas derived from events, or remain hybrid during the transition? | Critical: Security of user funds vs. operational flexibility. |
| **Tableland Mirror** | Is a decentralized SQL mirror necessary once on-chain audit registries are in place, or can this be replaced by indexer-backed query endpoints with checkpoint verification? | Strategic: Operational complexity vs. public discoverability. |

## 5. Acceptance Criteria
- [x] Each major data domain (Transactional, Analytical, Audit) has a documented canonical record and derived query mapping.
- [x] Rationale for each decision is explicitly captured.
- [x] Central vs. Edge responsibilities are clearly delineated.
- [x] Conditional status of non-authoritative datastores (e.g., Tableland mirror) is identified.
