# Agents Module

## Overview (Explanation)
The Agents module provides autonomous intelligence for risk and treasury management. It serves as the protocol's decision-making layer, utilizing real-time telemetry and control theory to maintain stability and optimize fiscal policy.

## Architecture (Explanation)
The module follows an autonomous intelligence loop:
- **Predictive Risk**: `agent-risk.clar` monitors system-wide health and calculates stability adjustments using a PID controller.
- **Sovereign Treasury**: `agent-treasury.clar` orchestrates revenue routing and buy-back strategies based on growth metrics.
- **Cybernetic Intel**: Agents share telemetry through a common interface to ensure coordinated responses to market volatility.

## Core Contracts (Reference)

### `agent-risk.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `assess-system-risk` | `()` | Returns the current global risk score. |
| `get-cybernetic-intel` | `()` | Returns combined telemetry (GCR, Fee, Risk). |
| `update-pid-rates` | `()` | Heartbeat for PID controller updates. |

### `agent-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `run-fiscal-strategy` | `(pool-trait <csf-trait>) (pools (list 50 principal)) (cxd <sip-010-trait>)` | Orchestrates revenue routing. |
| `calculate-performance-adjustment` | `()` | Returns the current growth-based multiplier. |

## Integration Examples (How-to)

### Accessing Risk Telemetry
Integrated modules can query the risk agent for system status:
```clarity
(let ((intel (unwrap-panic (contract-call? .agent-risk get-cybernetic-intel))))
  (print intel)
)
```

## Testing (How-to)
`npx vitest run tests/aye-engine.test.ts`

## Status (Reference)
- Implementation: Apex v1.1.0 Ready
