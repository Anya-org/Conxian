---
layout: default
title: Core Module
permalink: /modules/core/
---

# Core Module

## Overview

The Core Module is the foundational layer and central nervous system of the Conxian Protocol. It manages global state, system-wide security, and routes all core user and administrative interactions. The architecture is designed for security, clarity, and gas efficiency by separating responsibilities into distinct, single-purpose contracts.

## Architecture: A Three-Contract System

The module operates on a three-contract model that separates administrative authorization, protocol state, and user-facing operations.

1. **`admin-facade.clar` (Authorization Hub)**: This contract is the **single source of truth for all authorization and access control**. It manages roles (e.g., `ROLE_GLOBAL_ADMIN`, `ROLE_EMERGENCY_PAUSE`) and provides a centralized point for other contracts to verify permissions.

2. **`conxian-protocol.clar` (Protocol State Coordinator)**: This contract manages the global state of the protocol. Its primary responsibilities include managing the system-wide emergency pause switch, maintaining a registry of all authorized module contracts, and handling contract ownership. It **delegates all authorization checks** to the `admin-facade.clar` contract.

3. **`dimensional-engine.clar` (User Facade)**: The primary user entry point for dimensional trading. It acts as a simplified interface that delegates complex operations to underlying contracts like `position-manager.clar` and `risk-manager.clar`. It handles pre-flight checks (pauses, module status) before executing trades.

4. **`ops-engine.clar` (The Heartbeat)**: Coordinates the protocol heartbeat by triggering Fast Path and Slow Path logic updates (CXIP-012). It incentivizes external keepers to maintain protocol health.

### Control Flow Diagram

```mermaid
graph TD
    subgraph "Admin Actions"
        A[Administrator] --> B{admin-facade.clar};
        B -- Authorizes Role --> B;
        C[conxian-protocol.clar] -- 1. Checks Role --> B;
        A -- 2. `set-paused(true)` --> C;
    end

    subgraph "User Actions"
        D[User] --> E{dimensional-engine.clar};
        E -- 1. Pre-flight: Check Pause Status --> C;
        E -- 2. Delegate `open-position` --> F[position-manager.clar];
    end

    subgraph "Dependencies"
        F
    end
```

## Core Contracts & Public Functions

### `admin-facade.clar` (Authorization Hub)

#### Authorization

- `is-global-admin()`: (Read-Only) Checks if the caller is the global administrator.
- `is-authorized(role uint)`: (Public) Checks if the caller is the global admin or has the specified role.
- `is-authorized-to-pause(sender principal)`: (Read-Only) Checks if a given principal has permission to pause the protocol.

#### Role Management

- `set-role(user principal, role uint, enabled bool)`: (Global Admin Only) Grants or revokes a specific role for a user.
- `batch-update-roles(updates (list 100 {user: principal, role: uint, active: bool}))`: (Global Admin Only) Updates multiple user roles in a single transaction.

#### Emergency Functions

- `set-emergency-pause(paused bool)`: (Emergency Role or Global Admin) Sets the local emergency pause status.
- `pause-contract(target principal)`: (Emergency Role Only) Requests to pause a specific target contract.
- `unpause-contract(target principal)`: (Global Admin Only) Requests to unpause a specific target contract.

#### Configuration

- `set-global-admin(new-admin principal)`: (Global Admin Only) Transfers the global admin role to a new principal.
- `transfer-global-admin-to-timelock()`: (Global Admin Only) Transfers the global admin role to the protocol timelock.
- `set-rbac-contract(new-contract principal)`: (Global Admin Only) Sets the address of the RBAC contract.
- `batch-admin-operations(operations (list 200 {type: uint, params: (list 5 principal)}))`: (Global Admin Only) Executes multiple administrative operations in a single transaction.

### `ops-engine.clar` (The Heartbeat)

- `trigger-epoch-update()`: (Public) Incentivized function to trigger Anti-LVR updates (Fast Path) and Fiscal Dam/PID updates (Slow Path). **Note**: Requires the `ops-engine` contract to be an authorized minter in `cxd-token` to pay keeper rewards.
- `process-signal(proposal-id uint, proposal-contract <proposal-trait>)`: (Operator Only) Executes governance signals.
- `trigger-emergency-pause()`: (Operator Only) Triggers a protocol-wide emergency pause.
- `get-last-action()`: (Read-Only) Returns the timestamp of the last administrative action.
- `get-engine-status()`: (Read-Only) Returns the current operational status of the heartbeat engine.

### `conxian-protocol.clar` (Protocol State Coordinator)

#### Global State

- `set-paused(new-paused bool)`: (Admin Only) Pauses or unpauses all state-changing protocol functions.
- `pause()`: (Public) Convenience function to pause the protocol.
- `is-paused()`: (Read-Only) Returns the current pause status of the protocol.
- `get-protocol-status()`: (Read-Only) Returns a comprehensive status of the protocol, including Nakamoto tenure ID.

#### Module Registry

- `register-module(name (string-ascii 32), contract principal)`: (Admin Only) Adds a new module contract to the protocol registry.
- `batch-register-modules(entries (list 50 {name: (string-ascii 32), contract: principal}))`: (Admin Only) Registers multiple modules in a single transaction.
- `batch-set-module-active(entries (list 50 {name: (string-ascii 32), active: bool}))`: (Admin Only) Updates activation status for multiple modules.
- `get-module(name (string-ascii 32))`: (Read-Only) Retrieves the address and status of a registered module.

#### Ownership

- `set-contract-owner(new-owner principal)`: (Admin Only) Transfers ownership of the protocol coordinator to a new address.
- `get-admin()`: (Read-Only) Returns the current owner of the protocol.
- `get-protocol-admin()`: (Read-Only) Returns the current owner of the protocol.

### `dimensional-engine.clar` (User Facade)

- `open-position(position-manager <position-manager-trait>, token principal, amount uint, leverage uint, long bool, slippage-limit (optional uint), metadata (optional (string-utf8 1024)))`: Opens a new trading position.
- `close-position(position-manager <position-manager-trait>, position-id uint, token principal, slippage-limit (optional uint))`: Closes an existing position.
- `deposit-funds(collateral-manager <collateral-manager-trait>, amount uint, token-trait <sip-010-trait>)`: Deposits funds into the collateral manager.
- `withdraw-funds(collateral-manager <collateral-manager-trait>, amount uint, token-trait <sip-010-trait>)`: Withdraws funds from the collateral manager.
- `check-position-health(risk-manager <risk-manager-trait>, position-id uint)`: Queries position health via the risk manager.
- `liquidate-position(risk-manager <risk-manager-trait>, position-id uint)`: Triggers liquidation of an unhealthy position.

## Integration Examples

### Checking Authorization
```clarity
;; Check if tx-sender has ROLE_OPERATOR (u4)
(contract-call? .admin-facade is-authorized u4)
```

### Triggering Heartbeat (Keeper)
```clarity
;; Trigger epoch update and receive 5 CXD reward
(contract-call? .ops-engine trigger-epoch-update)
```

### Querying Protocol Status
```clarity
;; Get comprehensive protocol status
(contract-call? .conxian-protocol get-protocol-status)
```

## Testing

To run the core module tests, use the following command:

```bash
npx vitest run tests/core-contracts.test.ts
```

Ensure your environment is configured for Clarity 4 (Epoch 3.0) execution as per the Nakamoto upgrade standards.

## BIP Compliance

The Core Module ensures alignment with the following Bitcoin Improvement Proposals (BIPs):
- **BIP 341 (Taproot)**: Integration hooks for Taproot-based transaction validation.
- **BIP 342 (Taproot Scripts)**: Support for advanced script execution in anchored transactions.
- **BIP 174 (PSBT)**: Standards for Partially Signed Bitcoin Transactions in cross-chain operations.

## Status

**Aligned**: The Core module implementation matches the PRD architecture. The separation of concerns between authorization (`admin-facade`), state (`conxian-protocol`), and user interaction (`dimensional-engine`) is enforced across all core primitives.
