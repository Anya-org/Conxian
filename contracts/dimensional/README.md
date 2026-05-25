# Dimensional Module

## Overview (Explanation)

The Dimensional module enables multi-dimensional leveraged trading and position management within the Conxian Protocol. It allows users to open isolated or **cross-margin positions** on various assets. Cross-margin positions are trading positions that use the entire available account balance as collateral, rather than a specific allocated amount. The module utilizes the protocol's deep liquidity and autonomous risk management systems to provide professional-grade trading tools while maintaining decentralized sovereignty.

## Architecture (Explanation)

The module follows a strictly decoupled architecture separating position tracking, execution, and risk assessment:

- **Core Logic**: `dimensional-core.clar` manages the lifecycle of leveraged positions, including creation, closure, and liquidation triggers for **undercollateralized positions**. An undercollateralized position is one where the collateral value has dropped below the required threshold to maintain the position's safety.
- **Protocol Facade**: `dimensional-engine.clar` (located in `contracts/core/`) acts as the primary entry point for users and integrators, coordinating between positions, collateral, and risk units.
- **Position NFTs**: `position-nft.clar` represents active positions as SIP-009 assets, enabling positions to be transferable or used as collateral in other protocol layers.
- **Automation**: `dim-oracle-automation.clar` ensures that price feeds for dimensional assets are updated consistently.
- **Governance**: `governance.clar` handles module-specific parameters and upgrades.

## Core Contracts (Reference)

### `dimensional-core.clar`

The engine managing position lifecycles.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-position` | `(create-position (asset <sip-010-ft-trait>) (amount uint) (duration uint))` | Initializes a new leveraged position. |
| `close-position` | `(close-position (position-id uint))` | Settles and closes an active position. |
| `liquidate-position` | `(liquidate-position (owner principal) (position-id uint) (oracle principal))` | Forces closure of undercollateralized positions. |
| `get-position` | `(get-position (owner principal) (position-id uint))` | Returns detailed data for a specific position. |
| `is-paused` | `(is-paused)` | Returns whether the contract or global protocol is currently paused. |

### `dimensional-engine.clar` (Core Facade)

The primary interface for external interactions.

| Function | Signature | Description |
|----------|-----------|-------------|
| `open-position` | `(open-position (position-manager <position-orchestrator-trait>) (token principal) (amount uint) (leverage uint) (long bool) (slippage-limit (optional uint)) (metadata (optional (string-utf8 1024))))` | High-level call to open a position via the orchestrator. |
| `close-position` | `(close-position (position-manager <position-orchestrator-trait>) (position-id uint) (token principal) (slippage-limit (optional uint)))` | High-level call to close a position. |

## Integration Examples (How-to)

### Opening a Leveraged Position

To open a position through the dimensional facade:

```clarity
(contract-call? .dimensional-engine open-position
  .position-orchestrator
  .cxd-token
  u1000000
  u200 ;; 2.0x Leverage
  true ;; Long Bias
  none ;; Slippage Limit
  none ;; Metadata
)
```

### Querying Position Details

```clarity
(let ((position-data (unwrap-panic (contract-call? .dimensional-core get-position tx-sender u1))))
  (print position-data)
)
```

## Testing (How-to)

Validation is performed using Vitest and the Clarinet SDK.

1. **Setup**: Run `npm install`.
2. **Execution**: Run `npx vitest run tests/dimensional` to verify position lifecycles and risk parameters.

## Status (Reference)

- **Implementation**: Production-Ready (v1.2.0)
- **Audit Status**: Internally Verified
- **Leverage Caps**: Up to 10x (Configurable)
- **Standard Compliance**: Clarity 4, BIP-341, Hexagonal Architecture
