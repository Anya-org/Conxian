# Cross-chain Module

## Overview (Explanation)
The Cross-chain module enables the Conxian Protocol to interact with assets and state from other blockchains. It provides hooks for bridge providers and supports multi-chain asset wrapping, expanding the protocol's liquidity beyond the Stacks ecosystem.

## Architecture (Explanation)
The module acts as an interoperability gateway:
- **Wormhole**: Integrates with Wormhole core handlers for cross-chain messaging.
- **BTC Adapter**: Specialized logic for bridging Bitcoin assets (sBTC) into the protocol.
- **Gateways**: Manages the minting and burning of wrapped cross-chain assets.

## Core Contracts (Reference)
*Note: This module currently contains several placeholder implementations awaiting final bridge mainnet releases.*

### `btc-adapter.clar`
Bridge for Bitcoin-native assets.

| Function | Signature | Description |
|----------|-----------|-------------|
| `mint-sbtc` | `(mint-sbtc (amount uint) (recipient principal))` | Mints wrapped sBTC on Stacks. Authorized bridge only. |

## Integration Examples (How-to)

### Checking Cross-chain Message Status
```clarity
(contract-call? .wormhole-inbox get-message-status 0x1234...)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/cross-chain`

## Status (Reference)
- Implementation: **BETA (v0.8.0)**
- Audit Status: PENDING
- Standards: Wormhole, sBTC
- Standard: Hexagonal Architecture
