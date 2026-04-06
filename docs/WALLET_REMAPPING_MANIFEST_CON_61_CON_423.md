# Wallet remapping manifest (CON-61, CON-423)

This manifest maps the required SAB-owned BOS wallets to specific contract roles, configuration variables, and runtime paths in the existing codebase. It serves as the technical guide for the remediation of centralization risk (CON-61) and the implementation of the SAB-owned architecture (CON-423).

## 1. Protocol admin roles (CON-61 Remediation)

| Target SAB Wallet | Affected Contract(s) | Current Hardcoded Principal | Role / Variable Name |
| :--- | :--- | :--- | :--- |
| **SAB-TREASURY-MS** | `automation-manager.clar`, `office-manager.clar`, `governance-token.clar`, `yield-optimizer.clar`, `revenue-automation.clar` | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` | `admin`, `contract-owner`, `protocol-wallet` |
| **PROTOCOL-PAUSE-MS** | `upgrade-controller.clar`, `timelock.clar`, `circuit-breaker.clar` | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` | `governance`, `admin`, `guardian` |
| **BOS-KEEPER-MAIN** | `pyth-oracle-adapter.clar`, `twap-oracle.clar`, `chainlink-adapter.clar`, `redstone-oracle-adapter.clar` | `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` | `admin`, `conxian-protocol-contract`, `redstone-verifier` |

## 2. Payout and revenue paths (CON-423 Alignment)

| Target SAB Wallet | Affected Contract(s) | Role / Variable Name | Current Status |
| :--- | :--- | :--- | :--- |
| **TREASURY-VAULT** | `revenue-distributor.clar`, `revenue-automation.clar` | `protocol-wallet`, `treasury-vault` | Placeholder / Stubbed |
| **BOUNTY-PAYOUT-MS** | `revenue-distributor.clar`, `bounty-escrow.clar` | `payout-wallet`, `escrow-admin` | Not implemented |
| **SAB-TREASURY-MS** | `founder-vault.clar`, `opex-vault.clar` | `founder-recipient`, `opex-admin` | Hardcoded testnet principal |

## 3. Tooling and configuration remapping

| Tool / Config File | Variable to Remap | Required Action |
| :--- | :--- | :--- |
| **Clarinet.toml** | `deployer` | Change to the mainnet SAB-owned deployer address. |
| **deployments/*.yaml** | `expected-sender` | Replace `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM` with the target SAB principal. |
| **conxius-wallet/services/ntt.ts** | `Stacks` address | Replace hardcoded testnet sBTC-token anchor with the mainnet SAB-owned equivalent. |
| **conxian-ui/src/lib/contracts.ts** | `devnet` address | Replace with the resolved mainnet SAB principal. |

## 4. Execution priorities

1. **Phase 1: Dynamic RBAC Implementation.** Replace hardcoded `(define-data-var admin principal 'ST...)` with a dynamic `set-admin` path gated by the current owner.
2. **Phase 2: Registry-based Resolution.** Transition to `conxian-access` for all role checks (`is-authorized-executor`, `is-authorized-payout-signer`).
3. **Phase 3: Mainnet Plan Finalization.** Finalize the mainnet deployment plans in `Conxian/deployments/` with the confirmed SAB-owned principals.

## 5. ZSE Audit Checklist

- [ ] Confirm no private keys for SAB-owned wallets are tracked in public repositories.
- [ ] Verify that all bootstrap address references in tests and demo-data are explicitly labeled as `devnet-only` or `testnet-only`.
- [ ] Ensure any remaining hardcoded principals are replaced with environment variables or resolved from the access-registry at runtime.
