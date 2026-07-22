# Core Module

## Overview (Explanation)
The Core module serves as the central nervous system of the Conxian Protocol. It manages the registry of authorized modules, orchestrates system-wide updates, and enforces global security invariants through the Apex Heartbeat.

## Architecture (Explanation)
The core architecture follows a hub-and-spoke model for authority and execution:
- **Registry & Authority**: `conxian-protocol.clar` acts as the root of trust, managing authorized contract principals and versions.
- **Heartbeat & Updates**: `ops-engine.clar` triggers epoch-based state transitions and synchronizes global parameters.
- **Access Control**: `conxian-access.clar` provides unified RBAC across the entire protocol ecosystem.
- **Self-Launch & Funding**: `self-launch-coordinator.clar` handles the protocol's bootstrap and initial liquidity orchestration.
- **Risk Ownership**: `risk-unit.clar` is the canonical health, cache, score, and liquidation authorization unit. `risk-manager.clar` remains a compatibility facade; its privileged methods fail closed and new integrations should use `risk-unit`.

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

### `risk-unit.clar` (Canonical Risk Unit)
| Function | Signature | Description |
|----------|-----------|-------------|
| `calculate-health-factor` | `(collateral-value uint, total-debt uint)` | Returns the direct health-factor math result; `u10000` is `1.0x`. |
| `get-health-factor` | `(position-id uint)` | Refreshes the burn-block-based position cache. |
| `get-health-factor-read-only` | `(position-id uint)` | Reads only fresh cached health data. |
| `get-position-health` | `(position-id uint)` | Exposes cached health, update height, and freshness. |
| `get-risk-config` | `()` | Exposes thresholds, score bounds, configured callers, and cache age. |
| `get-system-risk-score` | `()` | Returns the canonical `0..10000` system score. |
| `is-liquidatable` | `(position-id uint)` | Fails closed on absent/stale cache and preserves exact-threshold health. |
| `liquidate` | `(position-id uint)` | Canonical authorized liquidation control path. |

See [`docs/RISK_MANAGEMENT.md`](../../docs/RISK_MANAGEMENT.md) for the
authorization matrix, initialization order, agent publication, and the
dimensional-core placeholder limitation.

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
