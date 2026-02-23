# Agents Module

## Overview (Explanation)
The Agents module provides sovereign autonomous intelligence to the Conxian Protocol. It includes predictive risk assessment (AYE) and automated fiscal management (The Fiscal Dam). These agents ensure the protocol remains stable and solvent without human intervention.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern.
- **Ports**: Defined via traits in `contracts/traits/conxian-service-trait.clar`.
- **Logic**: Specialized agents like `agent-risk.clar` (Risk & PID) and `agent-treasury.clar` (Fiscal Policy).
- **Automation**: Integrated with `ops-engine.clar` for recurring tasks.

## Core Contracts (Reference)

### `agent-risk.clar`
The Predictive Risk Agent (AYE) responsible for monitoring system health and calculating dynamic parameters.

| Function | Signature | Description |
|----------|-----------|-------------|
| `assess-system-risk` | `(assess-system-risk)` | Returns the current global risk score based on volatility and depth. |
| `get-performance-metrics` | `(get-performance-metrics)` | Returns MoM TVL growth and bounty completion rates. |
| `get-cybernetic-intel` | `(get-cybernetic-intel)` | Returns detailed telemetry for the AYE decision engine. |
| `update-pid-rates` | `(update-pid-rates)` | Recalculates PID controller outputs for stability fees. |
| `set-tvl` | `(set-tvl (new-tvl uint) (new-last-month uint) (new-bounty-rate uint))` | Updates TVL and performance metrics. Admin only. |
| `get-health-factor` | `(get-health-factor (position-id uint))` | Calculates the specific health factor for a leveraged position. |

### `agent-treasury.clar`
The Fiscal Management Agent responsible for implementing the Fiscal Dam (CXIP-013).

| Function | Signature | Description |
|----------|-----------|-------------|
| `run-fiscal-strategy` | `(run-fiscal-strategy)` | Orchestrates the periodic review and adjustment of revenue routing. |
| `apply-fiscal-dam` | `(apply-fiscal-dam)` | Triggers the actual distribution of funds based on the current policy. |
| `get-fiscal-status` | `(get-fiscal-status)` | Returns the current revenue split percentages and GCR state. |
| `calculate-cybernetic-policy` | `(calculate-cybernetic-policy)` | Determines the optimal revenue split based on risk and growth. |

## Integration Examples (How-to)

### Querying System Risk
Core engines can query the risk agent before allowing high-leverage operations:
```clarity
(let ((risk (unwrap! (contract-call? .agent-risk assess-system-risk) (err u999))))
  (asserts! (< risk u500) (err u4003)) ;; Reject if risk is too high
)
```

### Executing Fiscal Policy
The `ops-engine` heartbeat triggers the fiscal dam:
```clarity
(contract-call? .agent-treasury apply-fiscal-dam)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/agents`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342
- Standard: Hexagonal, CXIP-013 (Fiscal Dam V4)
