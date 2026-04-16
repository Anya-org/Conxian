# Monitoring Module

## Overview (Explanation)
The Monitoring module provides real-time telemetry and health assessment for the Conxian Protocol. It tracks financial metrics, protocol usage, and stability indicators to provide a transparent view of the protocol's state for agents and users.

## Architecture (Explanation)
The module acts as the protocol's "Observability Layer":
- **Metrics**: `finance-metrics.clar` aggregates TVL and solvency data across all modules using the oracle aggregator.
- **Analytics**: `analytics-aggregator.clar` tracks swap frequency and fee generation.
- **Dashboard**: `monitoring-dashboard.clar` provides human-readable health statuses.

## Core Contracts (Reference)

### `finance-metrics.clar`
Aggregates protocol-wide financial data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-protocol-tvl` | `()` | Returns the total system TVL (normalized to u8) from Lending and Dimensional modules. |
| `get-protocol-gcr` | `()` | Returns the Global Collateral Ratio (GCR) as a percentage. |
| `get-protocol-metrics` | `()` | Returns detailed solvency (GCR), TVL, active positions, and 24h volume metrics. |
| `set-admin` | `(new-admin principal)` | Sets a new administrative principal for the metrics contract. |
| `set-tracked-assets` | `(new-assets (list 10 principal))` | Updates the list of assets tracked for TVL calculation. |

### `monitoring-dashboard.clar`
Calculates high-level system status.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-protocol-health` | `()` | Returns a status string based on GCR and volatility. |
| `get-module-status` | `(module-principal principal)` | Returns the operational status of a specific module. |
| `get-system-health-summary` | `()` | Returns a comprehensive health summary for the entire protocol. |

## Integration Examples (How-to)

### Querying Protocol TVL
```clarity
(let ((tvl (unwrap-panic (contract-call? .finance-metrics get-protocol-tvl))))
  (print tvl)
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/monitoring`

## Status (Reference)
- Implementation: Production-Ready (v1.2.1)
- Audit Status: Internally Verified (April 2026)
- Telemetry: Real-time (Pull-based)
- Standard: Hexagonal Architecture, Diátaxis Compliant
