# Conxian DAO Interoperability Blueprint (March 2026)

## Executive Summary
This blueprint architecturally unifies governance across the Conxian ecosystem and external DAO frameworks. By leveraging sovereign identity (D.ID) and hardware-enclosed signing (StrongBox), Conxian enables users to participate in global governance without compromising asset security or privacy.

---

## 1. Universal Governance Adapters
**Objective**: Aggregated governance visibility through a unified data model.

- **Immediate Updates**:
    - `conxian-gateway`: New `internal/api/src/governance.rs`.
- **Data Schemas (UniversalProposal)**:
    ```rust
    pub struct UniversalProposal {
        pub id: String,
        pub source: String, // "Snapshot", "Aragon", "StacksOrbit"
        pub title: String,
        pub description: String,
        pub voting_type: String, // "SingleChoice", "Weighted"
        pub options: Vec<String>,
        pub end_time: u64,
        pub weight_logic: String, // "BTC-POS", "STX-Voting-Power"
    }
    ```
- **Rollout**:
    - **Phase 1**: Snapshot API adapter implementation in Rust (Gateway).
    - **Phase 2**: Aragon contract event listener integration.
    - **Phase 3**: Unified "Senate" portal release in Conxius UI.

---

## 2. Sovereign Vote Signing
**Objective**: TEE-backed voting with off-chain "Proof of Weight".

- **Immediate Updates**:
    - `conxius-wallet`: Integration of governance voting UI.
    - `lib-conxian-core`: New `src/protocol/governance.rs` for weight proofs.
- **Cryptographic Flow**:
    - **Signing**: TEE-anchored `signNative` using `did:pkh:btc`.
    - **Proof**: Merkle inclusion proof of asset ownership (BTC/STX) at a specific block height, attested by `conxian-nexus`.
- **Rollout**:
    - **Phase 1**: Enable governance-specific signing paths in `conxius-wallet`.
    - **Phase 2**: Implementation of "Proof of Weight" (PoW-Weight) attestations in the SDK.
    - **Phase 3**: Integration of ZK-proofs for privacy-preserving voting power.

---

## 3. Cross-DAO Treasury Execution
**Objective**: Trigger external treasury actions based on internal governance decisions.

- **Immediate Updates**:
    - `conxian-business`: New `TreasuryBridge` module.
    - `stacksorbit`: Timelock monitoring enhancements.
- **Rollout**:
    - **Phase 1**: Timelock event listener for Stacks-native governance.
    - **Phase 2**: Implementation of "Cross-Chain Attestation" broadcaster in the Gateway.
    - **Phase 3**: Deployment of external `ConxianRelayer` contracts for Ethereum/L2 interoperability.

---

## 4. Sequence Diagram: Cross-Chain DAO Vote
```text
User (Conxius Wallet)      Gateway (Adapter)       External DAO       Nexus (State)
|                          |                       |                  |
|-- 1. Fetch Proposals ---->|                       |                  |
|                          |-- 2. Fetch Data ----->|                  |
|<- 3. Aggregated List ----|                       |                  |
|                          |                       |                  |
|-- 4. Select Choice ----->|                       |                  |
|                          |-- 5. Request Weight ->|                  |
|                          |<- 6. Asset Context ---|                  |
|                          |                       |-- 7. Get Proof ->|
|                          |                       |<- 8. Merkle Proof|
|<- 9. Signing Request ----|                       |                  |
|                          |                       |                  |
|-- 10. TEE Signed Vote -->|                       |                  |
|                          |-- 11. Broadcast ----->|                  |
|                          |                       |                  |
|                          |<- 12. Confirmation ---|                  |
|<- 13. Success Notification|                      |                  |
```

---
© 2026 Conxian. Sovereign Autonomous Business.
