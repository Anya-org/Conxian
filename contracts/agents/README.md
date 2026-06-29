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
| `get-cybernetic-intel` | `(metrics-ref <finance-metrics-trait>)` | Returns combined telemetry (GCR, Fee, Risk). |
| `update-pid-rates` | `()` | Heartbeat for PID controller updates. |
| `initialize` | `(new-admin principal)` | Initializes the risk agent with a designated administrator. |
| `get-risk-score` | `()` | Returns the current system risk score. |
| `get-gcr` | `(metrics-ref <finance-metrics-trait>)` | Retrieves the Global Collateralization Ratio (GCR) from metrics. |
| `get-protocol-status` | `()` | Returns the current operational status and version. |
| `set-risk-score` | `(new-score uint)` | Updates the current system risk score (Admin only). |
| `get-stability-fee` | `()` | Returns the current stability fee percentage. |
| `set-stability-fee` | `(new-fee uint)` | Updates the global stability fee (Admin only). |

### `agent-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `run-fiscal-strategy` | `(pool-trait <csf-trait>) (pools (list 50 principal)) (cxd <sip-010-trait>)` | Orchestrates revenue routing. |
| `calculate-performance-adjustment` | `()` | Returns the current growth-based multiplier. |

## Jargon & Terminology (Layer 6)
- **PID Controller**: Proportional-Integral-Derivative controller, a control loop mechanism that continuously calculates an error value and applies a correction based on proportional, integral, and derivative terms.
- **GCR (Global Collateralization Ratio)**: The total value of collateral across the protocol divided by the total value of outstanding debt.
- **Telemetry**: Automated measurement and transmission of data from remote sources.
- **Cybernetic Intelligence**: Intelligence derived from the study of control and communication in complex systems.
- **Apex BME**: The specific implementation of the Burn-Mint Equilibrium for the Conxian Apex protocol.

## Integration Examples (How-to)

### Accessing Risk Telemetry
Integrated modules can query the risk agent for system status:
```clarity
(let ((intel (unwrap-panic (contract-call? .agent-risk get-cybernetic-intel .finance-metrics))))
  (print intel)
)
```

## Testing (How-to)
`npx vitest run tests/aye-engine.test.ts`

## Status (Reference)
- Implementation: Apex v1.1.0 Ready
