# Dimensional Module

## Overview (Explanation)
The Dimensional module enables multi-dimensional leveraged trading and position management. It allows users to open isolated or cross-margin positions on various assets, utilizing the protocol's deep liquidity and autonomous risk management.

## Architecture (Explanation)
The module separates position tracking from execution:
- **Core**: `dimensional-core.clar` (aliased or integrated with engines) manages the lifecycle of leveraged positions.
- **NFTs**: `cxlp-position-nft.clar` (in tokens) represents these positions as SIP-009 assets for transferability and composability.
- **Risk**: Positions are continuously monitored by the `risk-manager.clar` (in core).

## Core Contracts (Reference)

### `dimensional-engine.clar` (Core)
The primary facade for position operations.

| Function | Signature | Description |
|----------|-----------|-------------|
| `open-position` | `(open-position (manager <trait>) (token principal) (amount uint) (leverage uint) (long bool))` | Opens a new leveraged position. |
| `close-position` | `(close-position (position-id uint))` | Settles and closes an active position. |
| `liquidate-position` | `(liquidate-position (position-id uint))` | Forces closure of an undercollateralized position. |

## Integration Examples (How-to)

### Opening a 2x Long Position
```clarity
(contract-call? .dimensional-engine open-position
  .position-manager
  .cxd-token
  u1000000
  u200 ;; 2.0x
  true ;; Long
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/dimensional`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Leverage: Up to 10x
- Standard: Hexagonal, Isolated/Cross-Margin
