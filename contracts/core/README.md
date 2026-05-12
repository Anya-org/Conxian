# Core Module

## Overview (Explanation)
The Core module serves as the central nervous system of the Conxian Protocol. It manages the registry of authorized modules, orchestrates system-wide updates, and enforces global security invariants through the Apex Heartbeat.

## Architecture (Explanation)
The core architecture follows a hub-and-spoke model for authority and execution:
- **Registry & Authority**: `conxian-protocol.clar` acts as the root of trust, managing authorized contract principals and versions.
- **Heartbeat & Updates**: `ops-engine.clar` triggers epoch-based state transitions and synchronizes global parameters.
- **Access Control**: `conxian-access.clar` provides unified RBAC across the entire protocol ecosystem.
- **Self-Launch & Funding**: `self-launch-coordinator.clar` handles the protocol's bootstrap and initial liquidity orchestration.

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

## Integration Examples (How-to)

### Checking Global Protocol Status
External callers can verify the protocol's operational state:
```clarity
(let ((status (unwrap-panic (contract-call? .ops-engine get-protocol-status))))
  (print status)
)
```

## Testing (How-to)
Core validation is performed through the root system tests:
`npx vitest run tests/core-system.test.ts`

## Status (Reference)
- Implementation: Apex v1.1.0 (Nakamoto-Aligned)
