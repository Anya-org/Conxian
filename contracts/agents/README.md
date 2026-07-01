# Agents Module

## Overview (Explanation)
The Agents module implements autonomous "Fiscal Agents" that manage protocol risk, treasury health, and automated payments. These agents operate based on Grounded Telemetry and Unified Theory variables (C_R, V_X, A_S).

## Architecture (Explanation)
- **Risk Agent**: `agent-risk.clar` calculates cybernetic risk scores for lending and liquidity.
- **Treasury Agent**: `agent-treasury.clar` manages protocol-owned liquidity (POL).
- **Orchestrator**: `fiscal-orchestrator.clar` dispatches jobs to specialized agents.

## Core Contracts (Reference)

### `agent-risk.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `get-risk-score` | `()` | Returns the current system-wide risk score. |
| `assess-system-risk` | `(metrics-ref <finance-metrics-trait>)` | Evaluates protocol health and updates score (Public). |
| `set-stability-fee` | `(fee uint)` | Updates the PID stability fee (Admin only). |
| `set-risk-score` | `(score uint)` | Manually overrides the risk score (Admin only). |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |

### `agent-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `execute-rebalance` | `()` | Triggers POL rebalancing based on finance-metrics. |
| `calculate-performance-adjustment` | `(metrics <finance-metrics-trait>)` | Computes yield adjustments based on Unified Theory metrics. |
| `set-allocation-target` | `(target uint)` | Sets the target allocation for a specific asset (Admin only). |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |

## Jargon (Accessibility)
- **Fiscal Agent**: An autonomous smart contract program designed to execute financial policies without human intervention.
- **Grounded Telemetry**: The practice of using live, on-chain protocol metrics (like TVL or utilization) to drive agentic decisions.
- **Cybernetic Risk Score**: A dynamic value representing the safety of a position, calculated using feedback loops from market data.
- **System Autonomy (A_S)**: A Unified Theory variable measuring the degree of protocol independence from manual intervention.
- **Execution Velocity (V_X)**: A measure of how quickly the protocol processes transactions and state transitions.
- **Cost of Reproduction (C_R)**: The theoretical cost to replicate the protocol's state and liquidity on a new chain.

## Testing (How-to)
`npx vitest run tests/agents`

## Status (Reference)
- Implementation: Production-Ready (v1.1.0)
- Nakamoto Standards: Compliant
