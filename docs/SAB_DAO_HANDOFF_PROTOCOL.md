# SAB/DAO handoff protocol (CON-423)

This document defines the staged handoff protocol from personal bootstrap control to the Sovereign Advisory Board (SAB) and finally to the Decentralized Autonomous Organization (DAO).

## Handoff stages

### Stage 1: Personal bootstrap (Initial Deployment)
- **Status:** Current (Bootstrap-only).
- **Custodian:** Developer / Operator personal address.
- **Authority:** Full administrative control for deployment, initialization, and testnet validation.
- **Risk:** High centralization / single-point-of-failure.
- **Exit criterion:** Core protocol contracts deployed and verified on mainnet.

### Stage 2: SAB-controlled custody (Operational Launch)
- **Status:** Target for Initial Mainnet Release.
- **Custodian:** SAB-controlled multi-sigs and system-controlled agents.
- **Authority:** Operational execution, parameter adjustments within defined bounds, and initial fee capture.
- **Handoff action:** Transfer contract-owner roles to the appropriate SAB multi-sigs (e.g., `SAB-TREASURY-MS`, `BOUNTY-PAYOUT-MS`).
- **Exit criterion:** Payouts enabled and protocol fees provably accruing to SAB-owned vaults.

### Stage 3: DAO-aligned governance (Long-term Decentralization)
- **Status:** Post-launch maturity.
- **Custodian:** Community-governed DAO and automated policy engines.
- **Authority:** Root policy control, treasury rebalancing, and fee rate setting.
- **Handoff action:** Transfer root administrative authority to the DAO-controlled executor contract and timelock.
- **Verification:** Continuous on-chain audit of state updates and policy changes.

## Step-by-step handoff procedure

| Step | Action | Responsibility | Verification |
| :--- | :--- | :--- | :--- |
| **P-1** | Define the canonical mainnet principal for every required SAB wallet. | Operator | Publicly document in `docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md`. |
| **P-2** | Replace hardcoded principals in Clarinet plans and deployment scripts with the target SAB principals. | Dev | Pass CI verification for mainnet deployment plans. |
| **H-1** | Deploy and initialize the `governance-handover` contract. | Operator | Verify contract on Stacks Explorer. |
| **H-2** | Execute the `set-pending-owner` transaction on all core contracts, pointing to the SAB Multi-sig. | Bootstrap Wallet | Confirm transaction status on-chain. |
| **H-3** | Call `claim-ownership` from the target SAB Multi-sig (requires quorum). | SAB Signers | Confirm final owner update. |
| **V-1** | Verify that no bootstrap or personal address remains as a privileged role or recipient in the protocol. | Auditor | Successful `verify_handoff.sh` run. |

## Rollback authority (Emergency Action)
During the transition between Stage 2 and Stage 3, a **rollback authority** is maintained by the **Emergency Control** wallet class to revert changes if critical bugs are found. Once Stage 3 is fully achieved, this authority is strictly bounded by the DAO-controlled timelock (default 144 blocks).

## DAO policy handoff
After the custody handoff, the **Policy Handoff** ensures the DAO controls the parameters.
1. The **SAB** remains the executor of the protocol.
2. The **DAO** controls the policy (the "What") by setting parameters in the governance layer.
3. The **Agents** execute the policy (the "How") via the BOS automation loop.
