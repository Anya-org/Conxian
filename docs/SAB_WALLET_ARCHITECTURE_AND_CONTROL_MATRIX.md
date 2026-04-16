# SAB-owned BOS wallet architecture and control matrix (CON-423)

This document defines the canonical wallet-control model for the Conxian Business Operations System (BOS). It ensures that system automation and financial flows are system-controlled and auditable, moving away from personal or bootstrap control.

## Wallet classifications

| Class | Primary role | Typical owner | Authority type |
| :--- | :--- | :--- | :--- |
| **Execution (Agent)** | Routine automation, oracle reporting, and status updates. | System-controlled (Agent-specific) | Narrow / Functional |
| **Treasury (Vault)** | Passive asset custody, protocol fee accumulation, and reserve management. | Contract-controlled (Vault Principal) | Immutable / Rules-based |
| **Payout** | Distribution of bounties, royalties, and contributor incentives. | Multi-sig (SAB-controlled) | Approved / Threshold-based |
| **Signer Authority** | Root of trust for TEE attestations and multi-sig authorizations. | TEE / Hardware-backed Multi-sig | Authoritative / Signer-only |
| **Emergency Pause (Guardian)** | Emergency pause and isolation actions (veto-only; recovery/unpause via `SAB_EMERGENCY_RECOVERY_MULTISIG` in [`BOS_WALLET_CONTROL_MODEL.md`](./BOS_WALLET_CONTROL_MODEL.md)). | Multi-sig (Guardian set; DAO-aligned) | Override / Veto-only |

## Control matrix

| Wallet identifier | Purpose | Signer model | Quorum | Spending limits | Allowed actions |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **BOS-KEEPER-MAIN** | Main loop automation | 1/1 (System Agent) | N/A | None (Gas-only) | Oracle updates, tx triggers |
| **TREASURY-VAULT** | Protocol fee capture | Contract (None) | N/A | None (Inbound-only) | Passive collection |
| **SAB-TREASURY-MS** | Operational treasury | Multi-sig (SAB) | 3 of 5 | Medium | Ops funding, conversion |
| **DAO-TREASURY-MS** | Long-term reserves | Multi-sig (DAO) | 5 of 7 | High | Reserve rebalancing, large spends |
| **BOUNTY-PAYOUT-MS** | Contributor payouts | Multi-sig (Maintainer) | 2 of 3 | Medium | Bounty settlement (caps defined in the custody system of record) |
| **PROTOCOL-PAUSE-MS** | Emergency pause (veto-only; maps to custody identifier `SAB_EMERGENCY_PAUSE_MULTISIG` in [`BOS_WALLET_CONTROL_MODEL.md`](./BOS_WALLET_CONTROL_MODEL.md)) | Multi-sig (Guardian) | 2 of 3 | None | Contract pause/isolation actions; enable-only circuit breakers; MUST NOT sign unpause/resume operations or value-bearing transfers |

**Note:** This control matrix is the canonical definition for `PROTOCOL-PAUSE-MS` and its custody identifier `SAB_EMERGENCY_PAUSE_MULTISIG`. [`BOS_WALLET_CONTROL_MODEL.md`](./BOS_WALLET_CONTROL_MODEL.md) provides broader custody + governance context and MUST remain consistent with this table. Administrative recovery (including unpause, key rotation, role revokes, and rollback) must use `SAB_EMERGENCY_RECOVERY_MULTISIG` (higher quorum; see that doc) and/or the `DAO_TIMELOCK` contract. `PROTOCOL-PAUSE-MS` MUST NOT be granted unpause/resume or value-bearing transfer permissions in any deployed contract.

## Spending limit tier definitions

Spending limits are defined as a per-transaction maximum, expressed in STX-equivalent value transferred.
Concrete numeric caps per wallet, and the pricing source and timing used to value non-STX transfers, are recorded in the custody system of record outside Git (public-safe pointer stub: [`admin/SECRETS.md`](../admin/SECRETS.md)).

These tiers apply to value-bearing transfers (network gas fees excluded). Parenthetical notes in the control matrix (for example: `None (Gas-only)` or `None (Inbound-only)`) are operational constraints, not separate tiers.

- **None:** No value-bearing outbound transfers are permitted from this wallet. Wallets may still pay network gas fees. Any permitted contract calls MUST be non-value-bearing. They also MUST NOT confer or modify any authority that would allow other contracts or actors to move funds from this wallet (for example: granting withdrawal roles, changing payout parameters, or triggering execution paths that can debit this wallet). Gas-only wallets are therefore always classified as `None`.
- **Low:** Minimal value-bearing transfers only (for example: dust-level operational transfers or small top-ups).
- **Medium:** Budgeted operational or contributor payout transfers.
- **High:** Large treasury movements, reserve rebalancing, or cross-asset conversion.

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
