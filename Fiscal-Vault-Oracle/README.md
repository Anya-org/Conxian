# Fiscal Vault Oracle

> Current workspace release: **v1.8.2** (see [`CHANGELOG.md`](../CHANGELOG.md))

The **Fiscal Vault Oracle** is the treasury and policy coordination layer of the Conxian Business Operations System (BOS).

This repository is public. Detailed treasury operations, vendor integrations, and financial instrument terms are maintained in Linear:

- https://linear.app/conxian-labs
- https://linear.app/conxian-labs/issue/CON-256

## Purpose

- Coordinating treasury policy and execution constraints.
- Maintaining boundaries between public specifications and internal operational material.

## Key Components

- **[BOS integration map](./BOS_INTEGRATION_MAP.md)**
- **[Bitcoin bond details](./BITCOIN_BOND_DLC.json)**

## DLC Bond principal custody model

The DLC bond lifecycle contract (`dlc-bond.clar`) defaults to a **fully-collateralized** model:

- `subscribe` escrows principal sBTC into the contract.
- `redeem` returns principal sBTC from the contract once matured (or earlier if defaulted).

This design keeps redemptions solvent on-chain, but it also means there is no implicit "capital formation" drawdown.

For cases where principal must leave the contract (e.g., executor-controlled deployment), `dlc-bond.clar` supports an **opt-in** principal drawdown mode that must be enabled *before issuance* via `enable-principal-drawdown` (one-shot; errors if already enabled). In that mode, the issuer can draw down principal via `drawdown-principal` only while:

- `active = false`
- `defaulted = false`
- `coupon-index = 0`
- `burn-block-height < next-coupon-height`

Drawdowns are capped in aggregate at the current `dlc-bond` total supply; remaining drawdown capacity is `get-principal-drawdown-capacity`. Returning sBTC to the contract does not increase remaining drawdown capacity.

If the oracle does **not** declare default, the issuer/executor must restore sufficient sBTC liquidity to the contract before maturity for `redeem` to succeed.

If `principal-drawdown-enabled` is set and the oracle declares default, `redeem` switches to a recovery path that pays out the remaining in-contract sBTC **pro-rata** and disables coupon claiming in that state. Any previously accrued/unclaimed coupon amounts are not paid separately; all remaining in-contract sBTC (including any coupon funding) is distributed pro-rata based on `dlc-bond` burned.

Since payouts are integer-based, very small positions may need to consolidate before redeeming.

## Governance

This module is part of the Conxian Sovereign Autonomous Business (SAB).

See [`GOVERNANCE.md`](../GOVERNANCE.md) for CONTRIBUTING, SECURITY, and LICENSE.
