# Conxian Protocol Economics & Founder Rights

## 1. Protocol Fee Structure
As of April 2026, the Conxian Sovereign Autonomous Business (SAB) implements a mandatory protocol-level fee extraction:
- **Base Fee**: 100 bps (1%) on all core value transfers.
- **Enforcement**: Managed by `revenue-automation.clar`.
- **Distribution**: 100% of collected fees flow to the Burn-Mint Equilibrium (BME) engine via `revenue-distributor.clar`.

## 2. Revenue Split (CXIP-013)
The protocol treasury (`cxd-treasury.clar`) manages the allocation of collected revenue based on the following target baseline:
- **Treasury (SAB Operations)**: 45.0%
- **Bounties (Community Development)**: 30.0%
- **Liquidity Incentives (LP)**: 15.0%
- **Grants & Ecosystem**: 5.0%
- **Buyback & Burn (CXD)**: 5.0%
- **Insurance Fund**: Dynamic (Default 0%)

## 3. Founder & Operator Rights
Founder royalties and operator entitlements are structured to ensure long-term alignment without compromising protocol autonomy:
- **Founder's Cut**: A prioritized 10% carve-out from the **Treasury (SAB Operations)** share.
- **Entitlement Type**: CXD-denominated and NFT-based rights for governance participation.
- **Bootstrap Wallet**: Configured via the Operational Treasury principal registry (key: `founder-cut-beneficiary`) pending activation of the SAB-owned production multisig.

## 4. Governance Boundaries
- **SAB-Owned Wallets**: All protocol-controlled funds are held in smart-contract vaults (e.g., `conxian-vaults.clar`).
- **DAO Approval**: Major rebalancing (>500 bps shift) or allocation policy changes require Board (Community) approval via the `voting.clar` engine.
- **Agent Autonomy**: Risk and Treasury agents have executive authority over operational flows within the defined policy bounds.
