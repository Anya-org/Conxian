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
| `get-price` | `(get-price (asset principal))` | Returns the aggregated price for a specific asset. |
| `get-volatility-index` | `(get-volatility-index)` | Returns a composite volatility score for system-wide fee adjustment. |
| `set-source` | `(set-source (asset principal) (source principal) (weight uint))` | Registers a new price source. Admin only. |

### `federated-oracle-adapter.clar`
Enables a council of trusted sources to submit prices.

| Function | Signature | Description |
|----------|-----------|-------------|
| `submit-price` | `(submit-price (asset principal) (price uint))` | Submits a new price observation. Authorized sources only. |

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
