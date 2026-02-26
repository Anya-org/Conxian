# Bonding Module

## Overview (Explanation)
The Bonding module provides specialized AMMs and capital-raising mechanisms for the Conxian ecosystem. It allows the protocol to sell tokens along a mathematical curve, ensuring continuous liquidity and efficient price discovery.

## Architecture (Explanation)
The module implements high-precision curves:
- **AMM**: `cxd-bonding-curve-amm.clar` manages the primary trading curve for CXD.
- **Factory**: `bond-factory.clar` enables the creation of custom bond tokens for ecosystem projects.
- **Tokens**: `bond-token.clar` provides a template for SIP-010 compliant bond assets.

## Core Contracts (Reference)

### `cxd-bonding-curve-amm.clar`
The protocol's internal price discovery engine.

| Function | Signature | Description |
|----------|-----------|-------------|
| `buy` | `(buy (amount-stx uint) (min-tokens uint))` | Purchases CXD tokens from the curve. |
| `sell` | `(sell (amount-tokens uint) (min-stx uint))` | Sells CXD tokens back to the curve. |
| `get-buy-quote` | `(get-buy-quote (amount-stx uint))` | Returns the expected token output for a given STX input. |

## Integration Examples (How-to)

### Buying CXD via the Curve
```clarity
(contract-call? .cxd-bonding-curve-amm buy u1000000 u90000000)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/bonding`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Curve Type: Linear / Exponential
- Standard: Hexagonal Architecture
