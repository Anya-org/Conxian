# Staking Module

## Overview (Explanation)
The Staking module manages the protocol's participation in the Stacks Nakamoto stacking and the native Conxian dual-staking model. It allows users to lock CXS or STX to secure the protocol and earn yield in CXD or sBTC.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern:
- **Orchestrator**: `dual-stacking-orchestrator.clar` manages the logic for simultaneous STX and CXS locking.
- **Operators**: `native-stacking-operator.clar` interfaces with the Stacks PoX-4 contract.
- **Traits**: Implements `staking-trait` for universal yield eligibility.

## Core Contracts (Reference)

### `dual-stacking-orchestrator.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `stake-dual` | `(amount-stx uint) (amount-cxs uint)` | Locks both assets for a specific period. |
| `unstake` | `(stake-id uint)` | Unlocks assets after the cooldown period. |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |

### `native-stacking-operator.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `stack-stx` | `(amount uint) (pox-addr { version: (buff 1), hashbytes: (buff 20) })` | Proxies stacking to PoX-4. |
| `set-admin` | `(new-admin principal)` | Updates the administrator (Admin only). |

## Jargon (Accessibility)
- **Dual Stacking**: The process of locking both STX and native CXS tokens to maximize yield and governance weight.
- **PoX-4**: Proof of Transfer version 4, the Nakamoto-era consensus mechanism for Stacks.
- **Cooldown Period**: A mandatory waiting time between initiating an unstake and when assets become liquid.
- **Slashing Protection**: Mechanisms implemented in BitVM2 to prevent or penalize malicious behavior by validators.
- **Yield Eligibility**: A status that determines if a staked position is qualified to receive protocol emissions based on BME rules.

## Testing (How-to)
`npx vitest run tests/staking`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
