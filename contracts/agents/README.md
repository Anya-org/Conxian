# Agents Module

## Overview (Explanation)
The Agents module provides autonomous intelligence for risk and treasury management.

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

## Testing (How-to)
`npx vitest run tests/aye-engine.test.ts`

## Status (Reference)
- Implementation: Apex v1.1.0 Ready
