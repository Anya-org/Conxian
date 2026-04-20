# Sbtc Module

## Overview (Explanation)
The Sbtc module is a critical component of the Conxian Protocol, handling specialized operations for Bitcoin-anchored assets (sBTC). It implements sovereign autonomous logic for DLC (Discreet Log Contracts) bonds, enabling trust-minimized debt instruments on Stacks.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern.
- **Bonds**: `dlc-bond.clar` manages the lifecycle of individual Bitcoin debt instruments (CON-72).
- **Orchestration**: `dlc-orchestrator.clar` coordinates bond issuance and coupon distribution.
- **Integrations**: `dlc-manager.clar` acts as the bridge to sBTC and BitVM2 verification floors.

## Core Contracts (Reference)

### `dlc-bond.clar`
Manages the issuance, tracking, and redemption of DLC bonds.

| Function | Signature | Description |
|----------|-----------|-------------|
| `initialize-bond` | `(initialize-bond (principal-amount uint) (coupon-rate uint) (maturity-blocks uint) (token principal))` | Creates a new bond with principal, rate, maturity, and token. |
| `distribute-coupon` | `(distribute-coupon (bond-id uint))` | Distributes yield to bond holders. |
| `redeem-bond` | `(redeem-bond (bond-id uint))` | Handles redemption at maturity. |
| `get-bond-data` | `(get-bond-data (bond-id uint))` | Returns detailed bond data. |
| `get-admin` | `(get-admin)` | Returns the current admin principal. |
| `get-protocol-status` | `(get-protocol-status)` | Returns the protocol status and version. |
| `set-admin` | `(set-admin (new-admin principal))` | Updates the admin principal. |

### `dlc-manager.clar`
Bridge to sBTC and BitVM2 verification floors.

| Function | Signature | Description |
|----------|-----------|-------------|
| `create-dlc` | `(create-dlc (amount uint))` | Creates a new DLC commitment for Bitcoin settlement. |
| `verify-bitvm2-root` | `(verify-bitvm2-root (root (buff 32)) (proof (buff 1024)))` | Verifies a BitVM2 state root proof. |
| `get-protocol-status` | `(get-protocol-status)` | Returns the protocol status and version. |
| `set-admin` | `(set-admin (new-admin principal))` | Updates the admin principal. |

### `dlc-orchestrator.clar`
Executive layer for batch processing DLC events.

| Function | Signature | Description |
|----------|-----------|-------------|
| `orchestrate-bond-launch` | `(orchestrate-bond-launch (bond-contract <dlc-bond-trait>) (amount uint) (rate uint) (maturity uint) (token principal))` | Atomically launches and registers a new bond. |
| `process-coupon-cycle` | `(process-coupon-cycle (bond-contract <dlc-bond-trait>) (bond-ids (list 20 uint)))` | Triggers coupon payments for a list of bonds. |
| `get-protocol-status` | `(get-protocol-status)` | Returns the protocol status and version. |
| `set-admin` | `(set-admin (new-admin principal))` | Updates the admin principal. |

## Integration Examples (How-to)

### Launching a Bitcoin Bond
```clarity
(contract-call? .dlc-orchestrator orchestrate-bond-launch .dlc-bond u100000000 u450 u1440 .cxd-token)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/bitvm2-bridge.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.1)
- Audit Status: Internally Verified (April 2026)
- BIP Compliance: BIP-341, BIP-342, BIP-174 (DLC Standard)
- Standard: Hexagonal, BitVM2 Verification Ready
