# Integrations Module

## Overview (Explanation)
The Integrations module provides standardized adapters for external data sources and protocols. It ensures that the Conxian Protocol can consume high-fidelity price feeds and liquidity from the wider Stacks and Bitcoin ecosystem while maintaining sovereign autonomy.

## Architecture (Explanation)
Adapters implement the `oracle-trait` defined in `contracts/traits/defi-traits.clar`. This allows the `oracle-aggregator` to treat all sources polymorphically.
- **Pull Models**: Pyth and Redstone (not fully implemented in core).
- **Push Models**: Chainlink and DIA.
- **Internal Models**: TWAP Oracle based on DEX observations.

## Integration Fee Billing (STX-first MVP)
`integration-registry.clar` and `integration-fee-collector.clar` provide the
commercial integration-fee path:

- The registry controls integration ownership, payer, reporter, fee, billing
  mode, status, and API-key lifecycle. Raw API keys are authenticated
  off-chain; only their SHA-256 `(buff 32)` commitments are stored on-chain.
- The collector records reporter-authorized usage against replay-protected
  `(buff 32)` usage IDs and maintains per-integration, per-period audit ledgers.
- When a period ledger is first created it snapshots `billing-mode`,
  `fee-per-unit`, and `monthly-fee`. Later registry changes affect only a new
  period; they cannot reinterpret usage already accrued in the open ledger.
- Billing mode `u1` is per-use. Billing mode `u2` is monthly, with the period
  calculated as `burn-block-height / 4320`. A monthly period must close before
  it can be settled.
- Deactivation blocks new usage records but does not strand an existing
  ledger; its configured payer can still settle the outstanding snapshot.
- Payers settle the exact outstanding STX amount. The collector routes 100% of
  the payment by invoking the existing `distribute-stx` function under
  contract context, preserving the swap-router/BME/CXIP-013 path and adding
  no partner split or distributor-specific integration setter.

The MVP trusts one configured reporter principal per integration. Payer-signed
usage attestations are a later hardening step. Generic FT settlement is also
future work: it will require a two-step deposit-and-route flow rather than
accepting an FT directly in this STX-first collector.

## Dormant Partner Policy Registry

`partner-policy-registry.clar` is a schema/control surface for a future,
separately versioned partnership route. It is intentionally excluded from the
checked-in testnet and mainnet release plans and has no usage, custody, payout,
or settlement functions.

- Policy records are append-only by `(policy-id, version)`. Versions are
  sequential, use non-overlapping burn-block effective periods, and preserve
  immutable hashes, modes, splits, and period settings after publication.
- Dormant v1 accepts only native STX in microSTX, per-use accounting, the
  accepted/settled fee base, `floor(fee / 2)` partner allocation with the
  protocol receiving the remainder, 4,320-burn-block periods, append-only
  pre-settlement corrections, and future-period compensating entries after
  settlement. The contract exposes this math only as a read-only preview.
- Partner registrations separate owner, payer, beneficiary, and reporter.
  Reporters cannot select the beneficiary, asset, split, billing mode, policy,
  or any jurisdictional value. Beneficiary changes create a new registration
  version and retain the preceding record.
- Authorization resolves the `partner-policy-admin` and
  `partner-policy-registrar` principals through `operational-treasury`. The
  publish-time bootstrap principal can configure those routes, then finalize
  the fallback permanently.
- Validation fails closed for inactive registrations and missing, mismatched,
  future, expired, revoked, or unsupported policy references.
- Only public-safe hashes and bounded identifiers belong on-chain. Raw KYC,
  tax, legal, sanctions, jurisdiction, and customer data remain out of scope.

See [`docs/PARTNER_POLICY_REGISTRY.md`](../../docs/PARTNER_POLICY_REGISTRY.md)
for lifecycle and activation boundaries. The existing
`integration-fee-collector.settle-period` path remains the unchanged
100%-protocol route.

## Core Contracts (Reference)

### `chainlink-adapter.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price` | `(asset principal) (price uint) (round-id uint)` | Update the price feed for a specific asset. |
| `get-price` | `(asset principal)` | Get the cached price for an asset. |

### `dia-oracle-adapter.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price` | `(asset principal) (price uint) (signature (buff 65))` | Update the DIA price feed with signature. |
| `get-price` | `(asset principal)` | Get the cached price for an asset. |

### `twap-oracle.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price-observation` | `(asset principal) (price uint)` | Record a price observation at the current block. |
| `get-price` | `(asset principal)` | Calculate average price over the TWAP window. |
| `set-twap-window` | `(new-window uint)` | Set a nonzero TWAP window; `u1` is the minimum. |
| `get-twap-window` | `()` | Read the configured TWAP window. |
| `set-price-decimals` | `(new-decimals uint)` | Declare the source price precision for facade validation. |
| `get-price-decimals` | `()` | Read the optional declared source price precision. |

The DEX oracle facade requires `oracle-aggregator` and `twap-oracle` to declare
the same price precision before it compares or returns canonical policy prices.
The metadata is validation-only: no implicit conversion factor is applied.

## Testing (How-to)
`bash scripts/run-tests.sh tests/partner-policy-registry.test.ts tests/integration-fees.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Compliance: BIP-341, BIP-342
