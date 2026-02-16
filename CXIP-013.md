# CXIP-013: Bounty-Driven Revenue-Distribution Model

## Overview
This proposal defines a transparent, on-chain revenue-splitting mechanism for Conxian, favoring the Bounty Pool to incentivize contributors.

## Allocation Blueprint (Equilibrium)
| Destination | Baseline % (bps) | Purpose |
|-------------|------------------|---------|
| **Core Treasury** | **45%** (4500 bps) | Protocol development & 5% safety buffer. |
| **Bounty Pool** | **30%** (3000 bps) | Labor fund for staff, auditors, and devs. |
| **LP / Validator** | **15%** (1500 bps) | Auto-compounded staking rewards. |
| **Community / Grant** | **5%** (500 bps) | DAO ecosystem grants. |
| **Buy-Back & Burn** | **5%** (500 bps) | CXD token price support. |

## Dynamic Performance Adjustment
- **Trigger**: TVL growth > 12% MoM OR Bounty completion rate > 95%.
- **Action**: Shift +5% (500 bps) from **Core Treasury** to **Bounty Pool**.
- **Reversion**: Automatic reversion to baseline if trigger fails.

## Implementation
- **cxd-treasury.clar**: Stores the 6-way split and supports rebalancing.
- **revenue-distributor.clar**: Executes the distribution to 6 distinct vaults.
- **agent-risk.clar**: Provides performance metrics (TVL growth, Bounty rate).
- **agent-treasury.clar**: Orchestrates the Fiscal Dam V4 logic including CXIP-013 adjustments.

## Implementation Status (Feb 2026)
- **Verified**: Revenue distribution logic (Fiscal Dam V4) verified via `cybernetic-revenue.test.ts`.
- **Coordination**: Integration with `ops-engine` heartbeat verified via `full-protocol-journey.test.ts`.
