# DEX Module

## Overview (Explanation)
The DEX module provides high-efficiency trading and liquidity provision for the Conxian ecosystem. It supports concentrated liquidity (similar to Uniswap V3), predictive routing, and multi-asset swaps.

## Architecture (Explanation)
The DEX follows a layered approach:
- **Facade**: `dex-facade.clar` provides a unified entry point for pool management.
- **Routing**: `swap-router.clar` handles path-finding and multi-hop swaps.
- **Engine**: `concentrated-liquidity-pool.clar` manages the core math, ticks, and liquidity of individual pairs.

## Core Contracts (Reference)

### `swap-router.clar`
The primary interface for user trades.

| Function | Signature | Description |
|----------|-----------|-------------|
| `exact-input-single` | `(exact-input-single (amount-in uint) (min-amount-out uint) (pool principal) (token-in principal) (token-out principal))` | Executes a swap through a specific pool. |
| `swap-direct` | `(swap-direct (amount-in uint) (min-amount-out uint) (pool principal) (token-in principal) (token-out principal))` | Executes a direct swap between two tokens in a pool. |
| `update-volatility-fees` | `(update-volatility-fees)` | Dynamically updates swap fees based on market volatility. |

### `concentrated-liquidity-pool.clar`
The engine for concentrated liquidity pairs.

| Function | Signature | Description |
|----------|-----------|-------------|
| `swap` | `(swap (pool-id uint) (zero-for-one bool) (amount-in uint) (token0-trait <sip-010-ft-trait>) (token1-trait <sip-010-ft-trait>))` | Performs a swap within a specific pool using tick-based liquidity. |
| `mint` | `(mint (pool-id uint) (tick-lower int) (tick-upper int) (amount uint))` | Adds liquidity within a specific price range. |
| `collect-protocol-fees` | `(collect-protocol-fees (token-trait <sip-010-ft-trait>))` | Transfers accumulated protocol fees to the treasury. |

### `dex-facade.clar`
Administrative and registry facade for the DEX.

| Function | Signature | Description |
|----------|-----------|-------------|
| `add-authorized-pool` | `(add-authorized-pool (pool principal))` | Registers a new liquidity pool as authorized for the protocol. |
| `pool-exists` | `(pool-exists (pool principal))` | Returns whether a specific principal is a registered DEX pool. |

## Integration Examples (How-to)

### Executing a Swap
To trade tokens via the router:
```clarity
(contract-call? .swap-router exact-input-single
  u1000000 ;; 1 STX
  u990000  ;; 0.99 CXD (1% slippage)
  .stx-cxd-pool
  .stx-token
  .cxd-token
)
```

### Adding Concentrated Liquidity
LP providers can specify their price range:
```clarity
(contract-call? .concentrated-liquidity-pool mint
  u1     ;; Pool ID
  i-1000 ;; Lower Tick
  i1000  ;; Upper Tick
  u5000000
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/dex`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Standard: Hexagonal, Concentrated Liquidity
