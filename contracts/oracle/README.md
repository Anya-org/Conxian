# Oracle Module

## Overview (Explanation)
The Oracle module provides reliable, manipulation-resistant price feeds for the Conxian Protocol. It aggregates data from multiple sources, including external adapters and on-chain monitors, to provide accurate asset valuations for lending, swaps, and risk assessment.

## Architecture (Explanation)
The module utilizes an aggregator-adapter pattern:
- **Aggregator**: `oracle-aggregator.clar` collects and filters prices from various sources using deviation guards and stale thresholds.
- **Adapters**: Concrete implementations like `federated-oracle-adapter.clar` and `external-oracle-adapter.clar` interface with off-chain providers.
- **Specialized Oracles**: `points-oracle.clar` manages protocol-specific metrics like reputation or loyalty points.

## Core Contracts (Reference)

### `oracle-aggregator.clar`
The primary interface for price data consumption.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-price` | `(submit-price (asset principal) (price uint))` | Submit price from an authorized source. |
| `register-asset` | `(register-asset (asset principal) (tier uint) (is-yield-bearing bool))` | Register a 2026 Ecosystem Asset (sBTC, stSTX, etc). |
| `get-price` | `(get-price (asset principal))` | Returns the aggregated price for a specific asset. |
| `set-source-authorized` | `(set-source-authorized (source principal) (authorized bool))` | Authorize or deauthorize a price source. |
| `set-volatility-index` | `(set-volatility-index (new-vol uint))` | Update the protocol volatility index. |
| `set-circuit-breaker` | `(set-circuit-breaker (cb-contract principal))` | Set dynamic circuit breaker contract. |
| `report-circuit-state` | `(report-circuit-state (open bool))` | Update circuit state (push pattern). |
| `set-price` | `(set-price (asset principal) (price uint))` | Manually set an asset price (Emergency only). |

### `federated-oracle-adapter.clar`
Enables a council of trusted sources to submit prices.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-price` | `(submit-price (asset (string-ascii 32)) (price uint) (source principal))` | Submits a new price observation. |
| `add-oracle-source` | `(add-oracle-source (source principal) (weight uint))` | Adds a new authorized oracle source. |
| `remove-oracle-source` | `(remove-oracle-source (source principal))` | Removes an authorized oracle source. |

### `points-oracle.clar`
Manages reputation and loyalty points.

| Function | Signature | Description |
|----------|-----------|-------------|
| `award-points` | `(award-points (user principal) (amount uint) (source (string-ascii 16)))` | Award points to a user. |
| `burn-points` | `(burn-points (amount uint) (reason (string-ascii 16)))` | Burn points from user balance. |
| `transfer-points` | `(transfer-points (to principal) (amount uint))` | Transfer points to another user. |
| `claim-reward` | `(claim-reward (reward-id (string-ascii 32)))` | Spend points to claim a reward. |
| `create-reward` | `(create-reward (reward-id (string-ascii 32)) (name (string-ascii 64)) (description (string-ascii 256)) (points-cost uint) (reward-type (string-ascii 16)) (max-claims uint))` | Create a new claimable reward. |
| `apply-points-decay` | `(apply-points-decay)` | Apply points decay logic globally. |
| `set-decay-enabled` | `(set-decay-enabled (enabled bool))` | Enable or disable points decay. |
| `emergency-reset-user-points` | `(emergency-reset-user-points (user principal))` | Emergency reset of a user's points balance. |
| `deactivate-reward` | `(deactivate-reward (reward-id (string-ascii 32)))` | Deactivate a reward to prevent further claims. |

### `dimensional-oracle.clar`
Stub oracle for the dimensional engine.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-price` | `(get-price (asset principal))` | Returns the aggregated price for a specific asset. |
| `fetch-price` | `(fetch-price (asset principal))` | Fetch price (alias). |

## Integration Examples (How-to)

### Fetching a Verified Price
```clarity
(let ((price (unwrap! (contract-call? .oracle-aggregator get-price .cxd-token) (err u404))))
  (print price)
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/oracle`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Sources: Aggregated (Pyth, Federated)
- Standard: Hexagonal, Deviation-Guarded
- BIP Compliance: BIP-341, BIP-342, BIP-174
