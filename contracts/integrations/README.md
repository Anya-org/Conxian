# Integrations Module

## Overview (Explanation)
The Integrations module provides standardized adapters for external data sources and protocols. It ensures that the Conxian Protocol can consume high-fidelity price feeds and liquidity from the wider Stacks and Bitcoin ecosystem while maintaining sovereign autonomy.

## Architecture (Explanation)
Adapters implement the `oracle-trait` defined in `contracts/traits/defi-traits.clar`. This allows the `oracle-aggregator` to treat all sources polymorphically.
- **Pull Models**: Pyth and Redstone (not fully implemented in core).
- **Push Models**: Chainlink and DIA.
- **Internal Models**: TWAP Oracle based on DEX observations.

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

## Testing (How-to)
`npx vitest run tests/security-hardening.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Compliance: BIP-341, BIP-342
