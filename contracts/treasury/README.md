---
layout: default
title: Treasury Module
permalink: /modules/treasury/
---

# Treasury Module

## Overview

The Treasury Module manages the protocol's capital allocation and revenue distribution. It has been upgraded to an **Intelligence-Led Adaptive Yield Engine (AYE)** as per CXIP-011, moving away from static payout models to a dynamic, risk-aware system.

## Architecture

The module is centered around the transition from manual allocation to autonomous, intelligence-driven rebalancing.

-   **`cxd-treasury.clar`**: The core of the Adaptive Yield Engine. It maintains the current revenue split percentages, enforces governance-defined safety bounds, and tracks "Accrued Claims" for governance participants.
-   **`revenue-distributor.clar`**: The operational contract that executes the actual movement of funds (STX and SIP-010 tokens) based on the policy defined in `cxd-treasury`.

## Core Contracts

### `cxd-treasury.clar` (Adaptive Yield Engine)

This contract implements the logic for dynamic fiscal policy.

-   `rebalance(staking uint, dev uint, insurance uint)`: Updates the revenue shares. Called by `agent-treasury` or Admin.
-   `record-diverted-claim(token principal, amount uint)`: Automatically records "Priority Claims" for stakers when yield is diverted.
-   `get-allocation-percentages()`: (Read-Only) Returns the current active revenue split (Basis points: 10000 = 100%).
-   `set-bounds(min-staking uint, max-insurance uint)`: (Admin Only) Sets the safety rails for autonomous agents.
-   `backfill-claims(token principal, amount uint)`: (Admin Only) Deducts from recorded claims once they are backfilled.

### `revenue-distributor.clar`

Responsible for the automated distribution of protocol income.

-   `distribute-stx(amount uint)`: Splits STX revenue according to the AYE policy and records claims if necessary.
-   `distribute-token(token <sip-010-ft-trait>, amount uint)`: Splits token revenue and records claims.

## Integration Examples

### Querying Current Allocations

```clarity
(contract-call? .cxd-treasury get-allocation-percentages)
```

### Checking Accrued Claims

```clarity
(contract-call? .cxd-treasury get-accrued-claim .cxd-token)
```

## Testing

Treasury tests are located in `tests/aye-engine.test.ts`.

```bash
npm test -- tests/aye-engine.test.ts
```

## Status

**Active (CXIP-011)**: The treasury has been fully migrated to the Adaptive Yield Engine model with Nakamoto-era Clarity 4 compatibility.
