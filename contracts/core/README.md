# Core Module

## Overview (Explanation)
The central nervous system of Conxian.

## Core Contracts (Reference)

### `ops-engine.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-epoch-update` | `()` | Synchronizes protocol-wide state. |
| `get-protocol-status` | `()` | Returns heartbeat metadata. |

### `office-manager.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `is-agent-authorized` | `(agent principal)` | Verifies system agent authority. |
| `fund-payroll` | `(amount uint)` | Adds STX to the incentive pool. |

## Status (Reference)
- Implementation: Apex v1.1.0 (Nakamoto-Aligned)
