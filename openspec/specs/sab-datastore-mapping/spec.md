# SAB Datastore Mapping Specification

## 0. Conventions & Definitions

This specification uses requirement keywords (**MUST**, **MUST NOT**, **SHOULD**, **MAY**) as described in RFC 2119 and RFC 8174 to reduce implementation drift.

- **Canonical system of record**: The authoritative system for correctness.
- **Derived / query layer**: A non-authoritative replica optimized for read/query ergonomics.
- **SAB**: Conxian Sovereign Autonomous Business.
- **ZSE**: Zero Secret Egress.
- **Nexus**: Indexing and orchestration layer that consumes Stacks L1 state/events and maintains derived read models.
- **Gateway**: Service/API layer that exposes query endpoints over derived state and relays L1 interactions.
- **MMR node**: Merkle Mountain Range node used to create verifiable history for indexed state.
- **DID**: Decentralized identifier.
- **DID-ZK disclosures**: DID-associated zero-knowledge attestations; private inputs remain enclave-only.
- **Conxius Wallet**: End-user wallet product that may cache non-canonical state for offline UX continuity.
- **Wallet cache directory**: The on-device directory containing the wallet cache SQLite database file(s) and any associated files created/managed alongside them.
- **SQLite sidecar files**: Any SQLite-generated files associated with a given database file, including (but not limited to) WAL/SHM files, rollback journals, statement journals, and other temporary artifacts (e.g., `-wal`, `-shm`, `-journal`, `-mj*`, `-stmtjrnl`).

## 1. Purpose

This specification translates the Conxian Sovereign Autonomous Business (SAB) current-state inventory into target-state datastore decisions. It defines the mapping of major data domains to canonical on-chain systems of record and derived query layers.

## 2. Scope

- Mapping transactional application state.
- Mapping proof-oriented analytics.
- Mapping immutable governance and audit records.
- Identifying central versus edge responsibilities.

## 3. Requirements

### 3.1. Major Data Domain Mappings

The long-horizon direction is to make all non-secret SAB-critical business state fully on-chain. Off-chain systems may exist for performance and query ergonomics, but they **MUST** be treated as derived/indexed replicas rather than the authoritative system of record.

Secrets and signing keys **MUST** remain exclusively in hardware enclaves (ZSE). Only public identifiers (e.g., public keys, key IDs, and attestation commitments) **MUST** be anchored on-chain.

All non-enclave datastores (including PostgreSQL, Supabase, Tableland, Redis, and local SQLite) **MUST NOT** store seed phrases, signing keys, or enclave-only secrets in any reversible form.

| Data Domain | Canonical System of Record | Derived / Query Layer (Non-authoritative) | Notes |
| :--- | :--- | :--- | :--- |
| **Transactional Application State** | **Stacks L1 (Clarity contracts)** | **PostgreSQL** (currently **Neon**, later sovereign/self-hosted) | Write-path is on-chain. Postgres is a materialized read model for Nexus/Gateway sync, MMR node indexing, and service-level query performance. |
| **Proof-Oriented Analytics** | **Stacks L1 (events + state roots)** | **Supabase** (or equivalent SQL analytics layer) | Analytics datasets are derived from the on-chain event stream. Verification is anchored by on-chain checkpoints/hashes of derived datasets; canonical truth is always the raw L1 events/state. |
| **Immutable Governance & Audit** | **Stacks L1 (event log + audit registry contract)** | **Tableland** (optional mirror) | Default is on-chain auditability. Tableland is an optional public mirror when decentralized SQL materially improves discoverability without becoming a dependency for correctness. |
| **Hardware-Anchored Identity** | **Stacks L1 (public key registry + enclave key identifiers + attestation commitments)** | N/A | Mandated for Zero Secret Egress (ZSE). Private keys remain enclave-only; only public keys, key IDs, and attestations are anchored on-chain. |
| **High-Frequency Caching** | N/A | **Redis** | Volatile cache for millisecond-latency session management, real-time mempool tracking, and telemetry buffering. |
| **Offline Wallet Cache** | N/A | **Local SQLite** | Offline lookups and UX continuity. See [Offline Wallet Cache (SQLite) encryption key material handling](#offline-wallet-cache-sqlite-encryption-key-material-handling). |

<a id="offline-wallet-cache-sqlite-encryption-key-material-handling"></a>

#### 3.1.1. Offline Wallet Cache (SQLite) Semantics & Encryption Key Material Handling

This subsection defines conformance requirements for any SQLite-backed offline wallet cache.

In this subsection, “key” refers to cryptographic key material (e.g., KEKs/DEKs), not cache lookup keys.

1. **Local-cache semantics**: SQLite **MUST** be treated as a local cache; canonical state remains on-chain.
2. **No secret storage**: Wallet caches **MUST NOT** store seed phrases, signing keys, or enclave-only secrets in any form, even encrypted.
3. **At-rest protection for cached user-sensitive data**: If user-sensitive non-secret data is cached, it **MUST** be protected at rest (OS/hardware-backed storage encryption is acceptable; otherwise use application-level encryption).
4. **Application-level encryption keys**: If application-level encryption is used to protect cached data, the encryption keys **MUST** be generated and retained by the enclave/secure element (or an OS keychain/keystore backed by it) such that key material is non-exportable.
5. **Prohibited key material locations**: Any secret cryptographic key material (including key-encryption keys (KEKs) and data-encryption keys (DEKs), in raw or wrapped form) **MUST NOT** be stored anywhere under the wallet cache directory, including:
   - the SQLite database file, or
   - any SQLite sidecar files (as defined in the terminology list above).
6. **Permitted key references**: Non-secret key identifiers/aliases (e.g., OS keychain/keystore key IDs) that reference an OS keychain/keystore entry and contain neither raw keys nor wrapped key blobs **MAY** be stored in SQLite as part of the cache metadata.
7. **Removability**: Cached data **SHOULD** be treated as removable/invalidatable.

#### 3.1.2. Data Flow & Verification

1. **Stacks L1 emits canonical state transitions** via contract state + events.
2. **Indexers derive replicas** (Postgres/Supabase/Tableland) by consuming L1 events and projecting them into query-optimized schemas.
3. **Verification** is performed by anchoring periodic dataset checkpoints on-chain (a deterministic root hash over a defined canonicalization and hashing scheme) and requiring indexers/clients to match those checkpoints.
4. **Mismatch handling**: any replica that fails checkpoint validation is treated as stale/corrupted and **MUST** be rebuilt from the on-chain event stream.

##### 3.1.2.1. MVP checkpoint specification (deterministic)

To avoid incompatible hashing implementations, checkpoints **MUST** use a deterministic event-canonicalization and hashing scheme.

**Checkpoint interval**

- A checkpoint **MUST** be anchored every **144 Stacks blocks** (by `block-height`) for each dataset.

**Hashed material (event stream canonicalization)**

For a dataset checkpoint over a block-height range `[start, end]` (inclusive), the hashed material is the ordered list of L1 events in that range, normalized into *event records* with the following fields:

- `burn_block_height` (uint)
- `block_height` (uint)
- `tx_index` (uint; the transaction’s index within the block)
- `txid` (32-byte hex, lowercase)
- `event_index` (uint; the event’s index within the transaction)
- `contract_id` (string; `SP<address>.contract-name`)
- `event_type` (string)
- `payload_hex` (hex-encoded payload bytes, lowercase)

Event records **MUST** be sorted by:

1. `block_height` ascending
2. `tx_index` ascending
3. `event_index` ascending

Each record **MUST** be encoded as a single UTF-8 line with `|` separators and a trailing `\n`:

`burn_block_height|block_height|tx_index|txid|event_index|contract_id|event_type|payload_hex\n`

**Hash function and domain separation**

- Hash function: `sha256`.
- Domain separation prefix (UTF-8): `SAB-CHECKPOINT-V1|<dataset_id>|<start>|<end>\n`.
- The checkpoint root is `sha256(prefix || concatenated_event_record_lines)`.

**On-chain anchoring and discovery**

- Checkpoints **MUST** be anchored on Stacks L1 in a dedicated registry contract (e.g., an audit/checkpoint registry) that records at least: `dataset_id`, `start`, `end`, `root_sha256`, and `scheme_id`.
- Clients/indexers **MUST** discover the latest checkpoint for a dataset by reading from that registry contract on-chain (not by trusting an off-chain API).

#### 3.1.3. Constraints for Non-authoritative Query Layers

Any non-authoritative central derived or query layer that is used as a shared read model (including PostgreSQL read models, Supabase or equivalent analytics layers, and optional mirrors such as Tableland) **MUST** satisfy the following constraints.

These constraints do not apply to ephemeral caches (e.g., Redis) or device-local wallet caches, which may hold only non-canonical, non-secret convenience state.

1. **Deterministic rebuild**: the dataset **MUST** be rebuildable solely from Stacks L1 events/state and the published on-chain checkpoint history.
2. **Checkpoint validation**: before a replica is treated as trusted for serving requests, its current dataset version **MUST** be validated against the latest on-chain checkpoint.
3. **Correctness isolation**: derived/query layers **MUST NOT** be required for protocol correctness; on mismatch or unavailability, clients/services **MUST** fall back to Stacks L1 and/or rebuild the dataset.

### 3.2. Central vs. Edge Responsibilities

#### Central Datastores (PostgreSQL, Supabase)

- **Aggregation**: Consolidating materialized views derived from on-chain state across multiple Nexus instances.
- **Historical Persistence**: Maintaining long-term records for reporting and institutional compliance as query-optimized replicas; all compliance evidence **MUST** remain provably derivable from on-chain state and published checkpoints.
- **Query Acceleration**: Serving as derived read models for inter-module communication (e.g., Nexus to Gateway) without becoming the source of truth.

#### Edge Datastores (Enclave, Redis, Local SQLite)

- **Identity & Security**: Managing the critical path for signing and identity verification (ZSE).
- **Latency Sensitivity**: Handling high-frequency updates that would bottleneck central databases.
- **Offline Capability**: Ensuring the Conxius Wallet remains functional for local lookups without network connectivity.

### 3.3. Conditional Datastores

- **Tableland**: Identified as **Conditional**. It is acceptable only as a non-authoritative mirror of on-chain audit state and **MUST NOT** be required for protocol correctness.

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
- [x] Conventions/definitions are explicit to reduce interpretation drift.
- [x] Checkpointing requirements include a deterministic canonicalization/hashing scheme.
