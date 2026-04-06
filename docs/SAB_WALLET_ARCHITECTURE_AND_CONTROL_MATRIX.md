# SAB-owned BOS wallet architecture and control matrix (CON-423)

This document defines the canonical wallet-control model for the Conxian Business Operations System (BOS). It ensures that system automation and financial flows are system-controlled and auditable, moving away from personal or bootstrap control.

## Wallet classifications

| Class | Primary role | Typical owner | Authority type |
| :--- | :--- | :--- | :--- |
| **Execution (Agent)** | Routine automation, oracle reporting, and status updates. | System-controlled (Agent-specific) | Narrow / Functional |
| **Treasury (Vault)** | Passive asset custody, protocol fee accumulation, and reserve management. | Contract-controlled (Vault Principal) | Immutable / Rules-based |
| **Payout** | Distribution of bounties, royalties, and contributor incentives. | Multi-sig (SAB-controlled) | Approved / Threshold-based |
| **Signer Authority** | Root of trust for TEE attestations and multi-sig authorizations. | TEE / Hardware-backed Multi-sig | Authoritative / Signer-only |
| **Emergency Pause (Guardian)** | Emergency pause and circuit-breaking. | Multi-sig (Guardian) | Override / Veto-only |

## Control matrix

| Wallet identifier | Purpose | Signer model | Quorum | Spending limits | Allowed actions |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BOS-KEEPER-MAIN** | Main loop automation | 1/1 (System Agent) | N/A | Low (Gas-only) | Oracle updates, tx triggers |
| **TREASURY-VAULT** | Protocol fee capture | Contract (None) | N/A | None (Inbound-only) | Passive collection |
| **SAB-TREASURY-MS** | Operational treasury | Multi-sig (SAB) | 3 of 5 | Medium | Ops funding, conversion |
| **DAO-TREASURY-MS** | Long-term reserves | Multi-sig (DAO) | 5 of 7 | High | Reserve rebalancing, large spends |
| **BOUNTY-PAYOUT-MS** | Contributor payouts | Multi-sig (Maintainer) | 2 of 3 | Low/Medium | Bounty settlement |
| **PROTOCOL-PAUSE-MS** | Emergency pause and circuit-breaking | Multi-sig (Guardian) | 2 of 3 | N/A | Contract pause/isolate, circuit-breaking |

**Note:** `PROTOCOL-PAUSE-MS` maps to `SAB_EMERGENCY_PAUSE_MULTISIG` in [`BOS_WALLET_CONTROL_MODEL.md`](./BOS_WALLET_CONTROL_MODEL.md) and is pause/isolation-only. Administrative recovery (including unpause, key rotation, role revokes, and rollback) must use `SAB_EMERGENCY_RECOVERY_MULTISIG` (higher quorum; see that doc) and/or the `DAO_TIMELOCK` contract.

## Governance and authority boundaries

### SAB (Sovereign Advisory Board) authority
- **Domain:** Execution, operational treasury, and routine maintenance.
- **Responsibility:** Ensure the system runs according to the programmed policy.
- **Limit:** Cannot change protocol-level fee rates, royalty splits, or the underlying DAO policy.

### DAO (Decentralized Autonomous Organization) authority
- **Domain:** Policy, root governance, and long-term reserve management.
- **Responsibility:** Set the high-level economic and governance rules.
- **Limit:** Does not participate in routine execution; acts as the final arbiter and policy source.

## Approval policies

1. **Automation Approval:** Any action triggered by an **Execution Wallet** must be provable against the BOS state layer or an authorized TEE attestation.
2. **Threshold Spends:** Any spend exceeding the defined **Spending Limit** for a wallet class requires promotion to a higher-quorum wallet (e.g., SAB -> DAO).
3. **Emergency Pause:** Emergency pause authority is decentralized across the **Guardian** set to prevent single-point-of-failure censorship.

## Enforcement rules

- **No personal dependency:** No launch-critical automation or production payout path may depend on a single personal wallet after the handoff.
- **Principals over addresses:** All protocol-level recipient logic must use contract principals or resolved role-based principals via `conxian-access`.
- **ZSE Compliance:** Signing keys for system wallets are never stored in plain text or tracked in public repositories.
