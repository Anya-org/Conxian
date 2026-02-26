# Monitoring Module

## Overview (Explanation)
The Monitoring module provides real-time telemetry and health assessment for the Conxian Protocol. It tracks financial metrics, protocol usage, and stability indicators to provide a transparent view of the protocol's state for agents and users.

## Architecture (Explanation)
The module acts as the protocol's "Observability Layer":
- **Metrics**: `finance-metrics.clar` aggregates TVL and volume data across all vaults and pools.
- **Analytics**: `analytics-aggregator.clar` tracks swap frequency and fee generation.
- **Dashboard**: `monitoring-dashboard.clar` provides human-readable health statuses (e.g., "HEALTHY", "CRISIS").

## Core Contracts (Reference)

### `finance-metrics.clar`
Aggregates protocol-wide financial data.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-total-value-locked` | `(get-total-value-locked)` | Returns the total USD-equivalent value held in the protocol. |
| `get-utilization-ratio` | `(get-utilization-ratio (asset principal))` | Returns the ratio of borrowed vs deposited assets. |

### `monitoring-dashboard.clar`
Calculates high-level system status.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-protocol-health` | `(get-protocol-health)` | Returns a status string based on GCR and volatility. |

## Integration Examples (How-to)

### Querying Protocol TVL
```clarity
(let ((tvl (contract-call? .finance-metrics get-total-value-locked)))
  (print tvl)
)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/monitoring`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Telemetry: Real-time
- Standard: Hexagonal Architecture
