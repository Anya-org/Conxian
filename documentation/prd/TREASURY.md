# Conxian PRD: Treasury & Reserve

| | |
|---|---|
| **Status** | ✅ Stable |
| **Version** | 1.2 |
| **Owner** | Treasury WG |
| **Last Updated** | 2025-08-26 |
| **References** | [AIP-3](...), [`treasury.clar`](../../contracts/treasury.clar) |

---

## 1. Summary & Vision

The Conxian Treasury is the central contract responsible for managing all protocol-controlled value (PCV). It serves as the secure vault for assets generated from fees, buybacks, and other protocol activities. The Treasury is governed by a combination of multi-signature and DAO controls, ensuring a robust and decentralized approach to fund management. The vision is to create a transparent, resilient, and community-owned treasury that supports the long-term growth and sustainability of the Conxian ecosystem.

## 2. Goals / Non-Goals

### Goals
- **Security**: To secure protocol assets against unauthorized access through multi-layered controls (Multi-sig + DAO).
- **Transparency**: To provide a clear, on-chain record of all fund inflows and outflows.
- **Controlled Disbursements**: To ensure that funds are only spent according to rules set by the DAO and executed by a multi-signature committee.
- **Sustainability**: To accumulate resources that can fund future development, security audits, community grants, and other ecosystem initiatives.

### Non-Goals
- **Active Asset Management**: The treasury is a holding contract; it does not perform active investment or yield farming with its assets.
- **Direct Fee Collection**: The treasury does not pull fees; other contracts (e.g., Vault, DEX) push fees into it.

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| TRE-US-01 | Protocol | To deposit collected fees into a secure contract | The protocol's revenue is safely stored and managed. | P0 |
| TRE-US-02 | DAO | To propose and approve large disbursements | We can fund strategic initiatives like grants or new development. | P0 |
| TRE-US-03 | Multi-sig Member | To execute smaller, operational payments or DAO-approved transfers | We can manage day-to-day expenses and execute the will of the DAO. | P0 |
| TRE-US-04 | Community Member | To view the balance and transaction history of the treasury | I can have confidence that protocol funds are being managed transparently. | P0 |

## 4. Functional Requirements

| ID | Requirement | Test Case |
|---|---|---|
| TRE-FR-01 | The treasury must be able to receive and store any SIP-010 compliant FT token. | `receive-ft-succeeds` |
| TRE-FR-02 | All outbound transfers must be authorized by a multi-signature check (`m-of-n` signers). | `unauthorized-transfer-fails` |
| TRE-FR-03 | The DAO must be able to propose, vote on, and approve disbursements that exceed a certain threshold. | `dao-disbursement-succeeds` |
| TRE-FR-04 | The multi-sig committee must be able to execute DAO-approved proposals from the treasury. | `execute-dao-proposal-succeeds` |
| TRE-FR-05 | The DAO must be able to add or remove members of the multi-sig committee. | `update-multisig-members-succeeds` |
| TRE-FR-06 | An emergency pause (AIP-1), triggered by a separate guardian multi-sig, must be able to halt all disbursements. | `disbursement-fails-when-paused` |
| TRE-FR-07 | Emit standardized events for all critical operations: `deposit`, `disbursement`, `multisig-change`. | `events-are-emitted` |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| TRE-NFR-01 | **Security** | The contract must be audited by a reputable third party. No single point of failure for fund access. |
| TRE-NFR-02 | **Auditability** | A complete and immutable history of all transactions must be available on-chain. |
| TRE-NFR-03 | **Reliability** | The contract must have 99.99% uptime and be resilient to network congestion. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| TRE-INV-01 | **Asset Conservation** | The balance of any asset in the treasury can only decrease through a successfully authorized disbursement. |
| TRE-INV-02 | **Multi-sig Integrity** | No transfer can be executed with fewer than the required `m` signatures. |
| TRE-INV-03 | **DAO Supremacy** | The multi-sig committee cannot override a decision made by the DAO. |

## 7. Data Model / State & Maps

```clarity
;; Conceptual State
(define-map balances principal uint) ;; asset contract -> balance
(define-map multisig-members principal bool)
(define-data-var multisig-threshold uint)
(define-data-var dao-address principal)
(define-data-var paused bool)
```

## 8. Public Interface (Contract Functions / Events)

### Functions
- `deposit(token: principal, amount: uint)`: Deposits a given amount of a token into the treasury.
- `propose-disbursement(recipient: principal, token: principal, amount: uint)`: (Multi-sig) Initiates a disbursement proposal.
- `approve-disbursement(proposal-id: uint)`: (Multi-sig) Adds a signature to an existing proposal.
- `execute-disbursement(proposal-id: uint)`: (Multi-sig) Executes a fully signed proposal.
- `execute-dao-disbursement(...)`: (Multi-sig) Executes a disbursement previously approved by a DAO vote.
- `set-paused(is-paused: bool)`: (Guardian) Pauses or unpauses the contract.

### Events
- `(print (tuple 'event "deposit" ...))`
- `(print (tuple 'event "disbursement" ...))`

## 9. Core Flows (Sequence Narratives)

### Fee Deposit Flow
1. An external protocol contract (e.g., Vault) collects a fee.
2. The contract calls the `deposit` function on the Treasury contract, transferring the asset.
3. The Treasury's balance for that asset is updated. An event is emitted.

### DAO-Governed Disbursement Flow
1. **DAO Proposal**: The DAO creates and passes a proposal to spend >X amount of Asset Y to Recipient Z.
2. **Execution Call**: A multi-sig member calls `execute-dao-disbursement`, referencing the passed DAO proposal.
3. **Validation**: The Treasury contract verifies with the DAO contract that the proposal was indeed passed and is valid.
4. **Transfer**: The Treasury transfers Asset Y to Recipient Z.
5. **Event**: A `disbursement` event is emitted.

## 10. Edge Cases & Failure Modes

- **Multi-sig Collusion**: `m` members of the multi-sig committee could collude to steal funds.
- **Loss of Quorum**: If too many multi-sig members lose their keys, it may become impossible to reach the required signature threshold, effectively freezing funds.
- **DAO Capture**: A malicious actor gaining control of the DAO could vote to drain the treasury.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Private Key Compromise** | Multi-sig means a single compromised key is insufficient. Keys should be held in secure, geographically distributed locations. A key rotation plan should be in place (AIP-3). |
| **DAO Governance Attack** | The timelock on DAO proposals provides a window to detect and react to a malicious proposal targeting the treasury. |
| **Operational Failure** | If the multi-sig committee becomes unresponsive, the DAO has the power to vote in a new set of members. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| TRE-M-01 | **Total Value of Treasury** | The total USD-denominated value of all assets held in the treasury. |
| TRE-M-02 | **Asset Composition** | A breakdown of the treasury's holdings by asset. |
| TRE-M-03 | **Inflow/Outflow Rate** | The rate at which assets are entering and leaving the treasury over time. |
| TRE-M-04 | **Burn Rate** | The operational spending of the treasury, used to project financial runway. |

## 13. Rollout / Migration Plan

- **Initial Deployment**: The treasury address will be hardcoded into the initial set of fee-generating contracts at launch.
- **Upgrades**: Due to its simplicity, the treasury contract is unlikely to require frequent upgrades. If an upgrade is needed, a new treasury will be deployed, and the DAO will vote to redirect all fee streams to the new contract address.

## 14. Monitoring & Observability

- A public dashboard will provide real-time tracking of the treasury's balance and transaction history.
- Off-chain alerts will be configured to notify the team and community of any outflow from the treasury.

## 15. Open Questions

- What is the optimal `m-of-n` ratio for the multi-sig committee? (Initial decision: 3-of-5).
- Should the treasury diversify its holdings into stablecoins periodically? (Future consideration for the DAO).

## 16. Changelog & Version Sign-off

- **v1.2 (2025-08-26)**:
    - Expanded the PRD into the full 16-point standard format.
    - Added detailed sections on goals, user stories, risks, and monitoring.
    - Updated content to align with the full system context from `FULL_SYSTEM_INDEX.md`.
- **v1.1 (2025-08-18)**:
    - Validated SDK 3.5.0 compliance and confirmed production readiness.
- **v1.0 (2025-08-17)**:
    - Initial minimal PRD created.

**Approved By**: Treasury Team, Protocol WG
**Mainnet Status**: **APPROVED FOR DEPLOYMENT**
