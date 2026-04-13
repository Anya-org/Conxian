# Automation Module

## Overview (Explanation)
The Automation module provides the "Heartbeat" of the Conxian Protocol. It coordinates recurring tasks, such as parameter updates, epoch transitions, and incentive distributions, ensuring the protocol operates autonomously 24/7.

## Architecture (Explanation)
The module follows a Keeper-driven model where the protocol rewards external "workers" for triggering necessary on-chain actions.
- **Automation Manager**: Orchestrates the global status and execution of jobs.
- **Batch Processor**: Enables efficient execution of multiple operations in a single block.
- **Office Manager (The Payroll)**: Manages the registration and payment of authorized workers who execute the protocol's tasks.

## Core Contracts (Reference)

### `automation-manager.clar`
The primary controller for protocol automation jobs.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trigger-automation` | `(trigger-automation (job-id uint))` | Triggers a specific automation job by its ID. |
| `set-automation-active` | `(set-automation-active (active bool))` | Sets the global status of the automation engine. Admin only. |

### `batch-processor.clar`
Helper contract for batching transactions.

| Function | Signature | Description |
|----------|-----------|-------------|
| `batch-call` | `(batch-call (calls (list 10 { target: principal, payload: (buff 1024) })))` | Executes multiple contract calls in one transaction. |

### `office-manager.clar`
Coordinates worker incentives and payments.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-agent-status` | `(set-agent-status (agent principal) (active bool))` | Updates the authorization status of an agent. Owner only. |
| `is-authorized-agent` | `(is-authorized-agent (agent principal))` | Checks if an agent is authorized to trigger payouts. |
| `register-worker` | `(register-worker (worker principal))` | Registers a new worker in the payroll system. Owner only. |
| `remove-worker` | `(remove-worker (worker principal))` | Removes a worker from the payroll system. Owner only. |
| `is-worker-active` | `(is-worker-active (worker principal))` | Checks if a worker is currently active in the registry. |
| `fund-payroll` | `(fund-payroll (amount uint))` | Deposits STX into the payroll balance for future worker payments. |
| `withdraw-payroll` | `(withdraw-payroll (amount uint))` | Withdraws STX from the payroll balance to the owner's account. Owner only. |
| `payout` | `(payout (worker principal) (amount uint))` | Called by an Authorized Agent to pay the Worker who did the job. |
| `has-role` | `(has-role (user principal) (role-id uint))` | Checks if a user has a specific role. |
| `grant-role` | `(grant-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))` | Grants a role to a user. Owner only. |
| `revoke-role` | `(revoke-role (user principal) (role-id uint) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))` | Revokes a role from a user. Owner only. |
| `verify-passkey-signature` | `(verify-passkey-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))` | Verifies a passkey/biometric signature (stubbed). |

## Integration Examples (How-to)

### Registering as a Worker
To start performing jobs for the protocol, a principal must first be registered by the owner:
```clarity
(contract-call? .office-manager register-worker tx-sender)
```

### Funding the Payroll
Authorized agents need a funded payroll to pay workers:
```clarity
(contract-call? .office-manager fund-payroll u1000000)
```

### Batching Automation Jobs
Using the batch processor to trigger multiple jobs efficiently:
```clarity
(contract-call? .batch-processor batch-call (list { target: .automation-manager, payload: 0x... }))
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/automation`

## Status (Reference)
- Implementation: Active Development (v1.2.0)
- Audit Status: Internally Verified
- Protocol Incentive: Dynamic (managed by `office-manager`)
- BIP Compliance: BIP-341 (Taproot), BIP-342 (Taproot Scripts), BIP-174 (PSBT)
- Standard: Hexagonal, Keeper-Driven
