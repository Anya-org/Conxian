# Automation Module

## Overview (Explanation)
The Automation module provides the "Heartbeat" of the Conxian Protocol. It coordinates recurring tasks, such as parameter updates, epoch transitions, and incentive distributions, ensuring the protocol operates autonomously 24/7.

## Architecture (Explanation)
The module follows a Keeper-driven model where the protocol rewards external "workers" for triggering necessary on-chain actions.
- **Automation Manager**: Orchestrates the global status and execution of jobs.
- **Batch Processor**: Enables efficient execution of multiple operations in a single block.
- **Office Manager**: Manages the registration and payment of authorized workers (housed in `core`).

## Core Contracts (Reference)

### `automation-manager.clar`
The primary controller for protocol automation jobs.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-automation` | `(job-id uint)` | Triggers an automation job by its ID. |
| `set-automation-active` | `(active bool)` | Sets the global status of the automation engine. Admin only. |

### `batch-processor.clar`
Helper contract for batching transactions.

| Function | Signature | Description |
|----------|-----------|-------------|
| `batch-call` | `(calls (list 10 { target: principal, payload: (buff 1024) }))` | Executes multiple contract calls in a single transaction. |

## Integration Examples (How-to)

### Batching Automation Jobs
Using the batch processor to trigger multiple jobs efficiently:
```clarity
(contract-call? .batch-processor batch-call (list { target: .automation-manager, payload: 0x... }))
```

### Triggering a Job
```clarity
(contract-call? .automation-manager trigger-automation u1)
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/automation`

## Status (Reference)
- Implementation: Active Development (v1.2.0)
- Audit Status: Internally Verified
- Protocol Incentive: Dynamic (managed by `office-manager`)
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, Keeper-Driven
