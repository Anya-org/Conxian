# Nexus and Gateway Universal Chain Architecture

## Purpose

Define how Conxian should evolve `conxian-nexus` and `conxian-gateway` to support blockchain-universal service coverage while preserving the sovereignty-first ethos.

## Executive direction

- `conxian-nexus` should become the chain-agnostic state, proof, ordering, and trust-classification plane.
- `conxian-gateway` should become the policy, capability, transaction-preparation, and integration-routing plane.
- Signing must remain outside both services in wallet, enclave, or HSM boundaries.
- “Universal” should mean universal identifiers, universal capability contracts, and explicit trust tiers — not pretending all chains behave the same.

## Repo-aligned model

### Nexus owns
- chain ingestion
- reorg handling
- state roots
- sequencing
- proof generation
- drift and safety monitoring
- canonical multichain state attestations

### Gateway owns
- public integration APIs
- policy and compliance enforcement
- prepared transaction generation
- proof verification surfaces
- settlement routing
- chain-family capability negotiation

## Required normalization layer

Nexus and Gateway should both align on a shared normalized model:

- `chain_id`
- `account_id`
- `asset_id`
- `tx_id`
- `block_ref`
- `event_ref`
- `proof_type`
- `trust_tier`
- `finality_class`
- `freshness_window`
- `adapter_family`

## Adapter-family strategy

Build by chain family, not chain by chain first:

1. EVM family
2. Bitcoin / UTXO family
3. Cosmos / IBC family
4. Solana / SVM family
5. Move family
6. Substrate family

Each family adapter should declare:
- supported address/account formats
- fee model
- nonce/sequence model
- finality model
- replay-protection model
- proof model
- transaction-construction model
- event/indexing model
- bridge/messaging support model

## Trust and proof model

Every chain interaction should be classified explicitly as one of:

- `native_observation`
- `proof_verified`
- `attester_verified`
- `observer_only`

Additional metadata:
- proof source
- verifier implementation
- finality assumptions
- reorg risk window
- freshness timeout

## Nexus target modules

### 1. `chain-registry`
Canonical registry of supported chains and chain families.

### 2. `account-registry`
Normalized account/address layer across chains.

### 3. `asset-registry`
Canonical asset identity and mapping layer.

### 4. `proof-registry`
Registry of proof systems and verifier backends.

### 5. `finality-engine`
Per-chain/family finality and reorg semantics.

### 6. `state-attestation-service`
Canonical signed statement of off-chain observed state.

### 7. `drift-and-safety`
Universal mismatch and stale-state detection.

## Gateway target surfaces

### 1. `capabilities` API
Return what a chain/family supports.

### 2. `prepare_unsigned_transfer`
Family-specific unsigned transaction preparation.

### 3. `prepare_unsigned_contract_call`
Family-specific prepared execution payload.

### 4. `verify_proof`
Gateway-facing proof verification endpoint consuming Nexus proof metadata.

### 5. `route_or_submit`
Controlled submission pipeline with policy checks.

### 6. `watch_state` / `watch_finality`
Webhook or stream interface for clients and services.

### 7. `bridge_or_message`
Explicit bridge and interop routing surface with declared trust profile.

## Policy model

Gateway policy should operate on normalized entities, not raw chain strings whenever possible.

## Ethos guardrails

- Nexus does not own keys.
- Gateway does not own keys.
- No adapter may silently downgrade trust from `proof_verified` to `observer_only`.
- Bridged or attester-based assets must always carry explicit trust metadata.
- Public messaging must distinguish implemented, simulated, and production-enforced states.

## 90-day implementation order

### Phase 1
- define shared normalized schemas
- implement `chain-registry`
- implement `account-registry`
- implement `asset-registry`
- define trust-tier enum and proof-type enum

### Phase 2
- add family adapters for EVM, Bitcoin/UTXO, and Cosmos/IBC
- implement Nexus `finality-engine`
- implement Gateway `capabilities` API
- implement prepared unsigned transfer flows for top three families

### Phase 3
- implement `proof-registry`
- implement `state-attestation-service`
- implement Gateway `verify_proof`
- add policy evaluation using normalized entities

### Phase 4
- add Solana/SVM and Move families
- add bridge/message routing with explicit trust metadata
- add environment-backed verification and readiness gates

## Open questions

- Which three families are Tier 1 for execution?
- Does Nexus also own the cross-chain event bus, or only the proof/state layer?
- Which bridge/messaging systems are approved by trust tier?
- Which signer backends are allowed for production by family?
