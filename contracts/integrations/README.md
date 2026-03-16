# Integrations Module

## Overview (Explanation)
The Integrations module is a critical component of the Conxian Protocol, handling specialized operations for integrations. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the integrations system:

### `chainlink-adapter.clar`
Adapts Chainlink price feeds to the Conxian Oracle Trait.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price` | `(update-price (asset principal) (price uint) (round-id uint))` | Update the price feed for a specific asset. |
| `get-price` | `(get-price (asset principal))` | Get the cached price for an asset. |

### `dia-oracle-adapter.clar`
Adapts DIA decentralized price feeds.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price` | `(update-price (asset principal) (price uint) (signature (buff 65)))` | Update the DIA price feed with signature. |
| `get-price` | `(get-price (asset principal))` | Get the cached price for an asset. |

### `pyth-oracle-adapter.clar`
Efficient pull-model adapter for Pyth Network.

| Function | Signature | Description |
|----------|-----------|-------------|
| `update-price-feed` | `(update-price-feed (vaa (buff 2048)) (pyth <pyth-core-trait>))` | Updates the price feed with a VAA. |
| `get-price` | `(get-price (asset principal))` | Fetches the normalized price from Pyth. |
| `set-pyth-provider` | `(set-pyth-provider (new-provider principal))` | Admin function to switch the Pyth provider. |

### `redstone-oracle-adapter.clar`
Redstone oracle data adapter.

| Function | Signature | Description |
|----------|-----------|-------------|
| `verify-data-package` | `(verify-data-package (package (buff 1024)))` | Verify Redstone data package. |
| `get-price` | `(get-price (asset principal))` | Get price from Redstone. |

### `switchboard-oracle-adapter.clar`
Switchboard V2 adapter for Conxian.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-price` | `(get-price (asset principal))` | Get last reported price from Switchboard. |
| `update-price` | `(update-price (asset principal) (price uint) (confidence uint))` | Update the Switchboard price feed. |

### `twap-oracle.clar`
Calculates Time-Weighted Average Prices from historical observations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `record-price` | `(record-price (asset principal) (price uint))` | Record a price observation. |
| `get-price` | `(get-price (asset principal))` | Calculate TWAP from recorded observations. |


## Integration Examples (How-to)
### Calling Integrations from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "integrations")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/integrations`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
