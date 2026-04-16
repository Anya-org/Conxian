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
| `buy` | `(buy (uint uint) (response bool uint))` | Purchases CXD tokens from the curve. |
| `sell` | `(sell (uint uint) (response bool uint))` | Sells CXD tokens back to the curve. |
| `get-buy-quote` | `(get-buy-quote (uint) (response uint uint))` | Returns the expected token output for a given STX input. |
| `get-sell-quote` | `(get-sell-quote (uint) (response uint uint))` | Returns the expected STX output for a given token input. |

### `bond-factory.clar`
The factory for creating ecosystem bonds.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-bond` | `(create-bond (principal uint uint) (response uint uint))` | Creates a new bond position for a user. |
| `transfer` | `(transfer (uint principal principal (optional (buff 34))) (response bool uint))` | Standard SIP-010 transfer. |

### `bond-token.clar`
Standardized bond asset implementation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(transfer (uint principal principal (optional (buff 34))) (response bool uint))` | Standard SIP-010 transfer. |
| `mint` | `(mint (uint principal) (response bool uint))` | Mint new bond tokens (Authorized). |
| `burn` | `(burn (uint principal) (response bool uint))` | Burn bond tokens. |
| `set-contract-owner` | `(set-contract-owner (principal) (response bool uint))` | Update contract administrator. |

## Integration Examples (How-to)

### Buying CXD via the Curve
```clarity
(contract-call? .cxd-bonding-curve-amm buy u1000000 u90000000)
```

## Testing (How-to)
Validation is performed via integration tests.
1. Run system tests: `npx vitest tests/csf-full-system.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal Architecture
