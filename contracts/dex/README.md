# DEX Module

## Overview (Explanation)
The DEX module provides high-efficiency trading and liquidity provision for the Conxian ecosystem. In 2026, it evolved into a **Universal Routing Layer** powered by the Apex Router and the Common Settlement Framework (CSF).

### Key Concepts

- **Concentrated Liquidity**: A system where liquidity providers (LPs) can specify the price range in which their capital is used, significantly increasing capital efficiency.
- **Universal Routing Layer**: An abstraction layer that allows users to swap assets across any CSF-compliant protocol (e.g., Bitflow, Alex) through a single entry point.
- **Common Settlement Framework (CSF)**: A standardized interface that enables different DeFi protocols to interact seamlessly, allowing for unified liquidity discovery and execution.
- **Apex Router**: The core routing engine that dynamically dispatches trades to the most efficient liquidity source available in the CSF network.

## Architecture (Explanation)
The DEX follows a dynamic routing architecture designed for maximum interoperability:
- **Universal Router** (`swap-router.clar`): Handles dynamic dispatch to any CSF-compliant liquidity source. It acts as the primary user-facing entry point for all swap operations.
- **Protocol Registry** (`dex-factory.clar`): Maintains the list of permitted external protocol integrations and manages native pool discovery.
- **Native Engine** (`concentrated-liquidity-pool.clar`): Provides high-efficiency native Stacks liquidity using a concentrated liquidity model.
- **Swap Aggregator** (`swap-aggregator.clar`): A specialized adapter for sovereign, non-custodial Bitcoin-native swaps.

## Core Contracts (Reference)

### `swap-router.clar`
The Apex Universal Router.

| Function | Signature | Description |
|----------|-----------|-------------|
| `csf-swap` | `(liquidity-source <csf-liquidity-trait>) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (min-amount-out uint)` | Executes a swap through any registered CSF source. |
| `claim-external-yield` | `(liquidity-source <csf-liquidity-trait>) (reward-token <sip-010-ft-trait>) (amount uint)` | Bridges rewards from third-party protocols to the user. |
| `update-volatility-fees` | `()` | Update the protocol fees based on current market volatility. |
| `exact-input-single` | `(pool-id uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (min-amount-out uint)` | Execute a swap on a single pool with exact input amount. |
| `get-protocol-status` | `()` | Get the current operational status of the swap router. |

### `dex-factory.clar`
CSF Discovery and Registry.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-pool` | `(token-a principal) (token-b principal) (type uint) (pool-contract principal)` | Registers a new liquidity pool in the factory. |
| `register-csf-protocol` | `(protocol principal) (name (string-ascii 256))` | Registers a CSF-compliant external contract for discovery. |
| `toggle-csf-protocol` | `(protocol principal)` | Toggle the active state of a registered CSF protocol. |
| `get-pool` | `(token0 principal) (token1 principal) (type uint)` | Returns the contract principal for a specific pool. |
| `get-pool-count` | `()` | Returns the total number of registered pools. |
| `get-csf-protocol` | `(protocol principal)` | Returns metadata for a registered external protocol. |
| `get-csf-registry-count` | `()` | Returns the total number of registered CSF protocols. |
| `get-csf-protocol-by-index` | `(index uint)` | Returns the protocol principal at a specific registry index. |

### `concentrated-liquidity-pool.clar`
Native High-Efficiency Liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-liquidity-marker` | `(marker (string-ascii 256))` | Register a liquidity marker for the protocol. |
| `execute-csf-swap` | `(token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (recipient principal)` | Execute a swap through the Common Settlement Framework. |
| `request-flash-liquidity` | `(token <sip-010-ft-trait>) (amount uint) (payload (buff 32))` | Request flash liquidity from the pool. |
| `settle-arbitrage` | `(token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount uint) (route (list 10 principal))` | Settle an arbitrage path through the CSF. |
| `claim-conxian-yield` | `(reward-token <sip-010-ft-trait>) (amount uint) (recipient principal)` | Claim protocol yield through the CSF. |
| `get-csf-health` | `()` | Get the health metrics of the CSF integration. |
| `swap` | `(pool-id uint) (is-token-0 bool) (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (recipient principal)` | Execute a swap in a concentrated liquidity pool. |
| `create-pool` | `(token-0 principal) (token-1 principal) (fee uint) (initial-price uint) (initial-tick int)` | Create a new concentrated liquidity pool. |
| `collect-protocol-fees` | `(token <sip-010-ft-trait>)` | Collect accumulated protocol fees. |
| `get-protocol-status` | `()` | Get the status of the CL pool contract. |

### `liquidity-manager.clar`
Liquidity Provision Management.

| Function | Signature | Description |
|----------|-----------|-------------|
| `open-position` | `(pool-id uint) (tick-lower int) (tick-upper int) (liquidity uint)` | Open a new liquidity position in a pool. |

### `route-manager.clar`
Multi-hop Swap Routing.

| Function | Signature | Description |
|----------|-----------|-------------|
| `swap-route` | `(amount-in uint) (amount-out-min uint) (token-in <sip-010-trait>) (token-out <sip-010-trait>) (route (list 5 principal))` | Execute a multi-hop swap route. |

### `oracle.clar`
DEX Price Oracle.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-price` | `(token principal) (price uint)` | Set the price for a specific token. |
| `get-price` | `(token principal)` | Get the price for a specific token. |
| `fetch-price` | `(token principal)` | Fetch the latest price for a token. |
| `transfer-ownership` | `(new-owner principal)` | Transfer contract ownership to a new principal. |

## Integration Examples (How-to)

### Routing through an External Protocol (e.g. Bitflow)
```clarity
(contract-call? .swap-router csf-swap
  .bitflow-csf-adapter
  .stx-token
  .usda-token
  u1000000
  u990000
)
```

## Testing (How-to)
Comprehensive validation is performed via `tests/csf-full-system.test.ts`.

## Status (Reference)
- Implementation: Apex v1.1.0 Ready
- Audit Status: Internally Verified (March 2026)
- Standard: CSF Dynamic Dispatch, 100% Fee Buy-back
