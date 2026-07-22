# Conxian Protocol Economics & Founder Rights

## 1. Protocol Fee Structure
As of April 2026, the Conxian Sovereign Autonomous Business (SAB) implements a mandatory protocol-level fee extraction:
- **Base Fee**: 100 bps (1%) on all core value transfers.
- **Enforcement**: Managed by `revenue-automation.clar`.
- **Distribution**: 100% of collected fees flow to the Burn-Mint Equilibrium (BME) engine via `revenue-distributor.clar`.

### Integration Fees (STX-first MVP)
Registered integrations may use `integration-fee-collector.clar` for:

- **Per-use billing (`u1`)**: each reporter-authorized usage record accrues
  the configured fee multiplied by usage units.
- **Monthly billing (`u2`)**: usage is audited throughout a period derived
  from `burn-block-height / 4320`; the fixed monthly fee becomes settleable
  only after that period closes.
- **Settlement**: the configured payer must settle the exact outstanding STX
  amount. The collector invokes the existing `distribute-stx` route under
  contract context, so one hundred percent enters `revenue-distributor.clar`;
  no partner split and no direct operational-treasury bypass are introduced.

API keys are authenticated off-chain and represented on-chain only by SHA-256
hashes for lifecycle and audit purposes. The MVP trusts a configured reporter
per integration. Generic FT settlement and payer-signed usage attestations are
future extensions, not part of this STX-first contract path.

### Registration fees — not implemented

No registration-fee manager currently accepts or escrows payment for user,
protocol, or integration registration. The Phase 3 Issue #504 candidate adds
only a canonical, fail-closed compliance read-only gate in
`compliance-manager.clar`; it does not select fee amounts, refund rules,
activation timing, or a revenue split. Until those decisions are approved,
[`CXIP-013.md`](../CXIP-013.md) remains the repository's authoritative policy
language for registration-fee destination: 100% vault recycling. The earlier
issue wording about bounty/operations distribution must not be treated as
implemented economics. The read-only gate itself requires a fresh
`compliance-manager` record and matching authoritative `kyc-registry` evidence
(record presence, minimum tier, and `is-sanctioned == false`); it does not use
the legacy `sanctions-checked` boolean as a substitute for registry evidence.

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
- **Bootstrap Wallet**: Designated via the principal registry key `founder-cut-beneficiary` (set in `operational-treasury.clar`), pending the activation of the SAB-owned production multisig.

## 4. Governance Boundaries
- **SAB-Owned Wallets**: All protocol-controlled funds are held in smart-contract vaults (e.g., `conxian-vaults.clar`).
- **DAO Approval**: Major rebalancing (>500 bps shift) or allocation policy changes require Board (Community) approval via the `voting.clar` engine.
- **Agent Autonomy**: Risk and Treasury agents have executive authority over operational flows within the defined policy bounds.
