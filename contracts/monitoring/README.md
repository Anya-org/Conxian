# Monitoring Module

## Overview (Explanation)
The Monitoring module provides real-time telemetry and health assessment for the Conxian Protocol. It tracks financial metrics, protocol usage, and stability indicators to provide a transparent view of the protocol's state for agents and users.

## Architecture (Explanation)
The module acts as the protocol's "Observability Layer":
- **Metrics**: `finance-metrics.clar` aggregates TVL and solvency data across all modules using the oracle aggregator.
- **Analytics**: `analytics-aggregator.clar` tracks swap frequency and fee generation.
- **Persistence**: `tableland-sync.clar` added for decentralized state archival (CON-69).
- **Dashboard**: `monitoring-dashboard.clar` provides human-readable health statuses.

## Core Contracts (Reference)

### `finance-metrics.clar`
Aggregates protocol-wide financial data and Unified Theory variables.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-protocol-tvl` | `()` | Returns the total system TVL (normalized to u8) from Lending and Dimensional modules. |
| `get-protocol-gcr` | `()` | Returns the Global Collateral Ratio (GCR) as a percentage. |
| `get-cost-of-reproduction` | `()` | Returns the Cost of Reproduction (C_R) theory variable. |
| `get-execution-velocity` | `()` | Returns the Execution Velocity (V_X) theory variable. |
| `get-system-autonomy` | `()` | Returns the System Autonomy (A_S) theory variable. |
| `get-protocol-status` | `()` | Returns detailed solvency (GCR), TVL, and Unified Theory metrics. |
| `update-theory-metrics` | `(uint uint uint)` | Updates C_R, V_X, and A_S variables (Admin only). |

### `tableland-sync.clar`
Tableland state persistence bridge.

| Function | Signature | Description |
|----------|-----------|-------------|
| `commit-state-to-tableland` | `(uint (string-ascii 256))` | Commits on-chain state transition to Tableland for archival. |

### `monitoring-dashboard.clar`
Calculates high-level system status.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-protocol-health` | `()` | Returns a status string based on GCR and volatility. |
| `get-module-status` | `(module-principal principal)` | Returns the operational status of a specific module. |
| `get-system-health-summary` | `()` | Returns a comprehensive health summary for the entire protocol. |

## Integration Examples (How-to)

### Querying Unified Theory Metrics
```clarity
(let ((theory (unwrap-panic (contract-call? .finance-metrics get-protocol-status))))
  (print (get theory theory))
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/monitoring`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified (June 2026)
- Telemetry: Real-time (Pull-based)
- Standard: Hexagonal Architecture, Diátaxis Compliant, Tableland Integration, Unified Theory v2.0
