# Automation Module

## Overview (Explanation)
The Automation module provides the "Heartbeat" of the Conxian Protocol. It coordinates recurring tasks, such as parameter updates, epoch transitions, and incentive distributions, ensuring the protocol operates autonomously 24/7.

## Architecture (Explanation)
The module follows a Keeper-driven model:
- **Engine**: `ops-engine.clar` is the central coordinator for all scheduled work.
- **Jobs**: Defined via the `office-job-trait` in modules like `agents` and `monitoring`.
- **Incentives**: Keepers are rewarded in CXD for successfully executing "jobs" that the protocol deems necessary.

## Core Contracts (Reference)

### `ops-engine.clar`
The central heartbeat coordinator.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-epoch-update` | `(trigger-epoch-update)` | Checks all registered jobs and executes those where `work-needed` is true. |
| `register-job` | `(register-job (name (string-ascii 32)) (contract principal))` | Adds a new autonomous job to the heartbeat loop. |
| `get-job-status` | `(get-job-status (name (string-ascii 32)))` | Returns the last execution height and status for a job. |

## Integration Examples (How-to)

### Registering a New Agent Task
To add a new task to the protocol heartbeat:
```clarity
(contract-call? .ops-engine register-job "risk-update" .agent-risk)
```

### Triggering the Protocol Heartbeat
External keepers call this to process all pending work:
```clarity
(contract-call? .ops-engine trigger-epoch-update)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/automation`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- Protocol Incentive: 5 CXD per Heartbeat
- Standard: Hexagonal, Keeper-Driven
