# CXIP-013: Sovereign BME Revenue Model (Apex Upgrade)

## Overview
This proposal defines the transition from the legacy Fiscal Dam to the **Apex Burn-Mint Equilibrium (BME)** model. In this model, 100% of collected protocol fees are autonomously converted into CXD tokens for burning or vault recycling, while new CXD is emitted meritocratically based on activity markers.

## Allocation Blueprint (BME Activity Markers)
| Marker | Emission Weight | Purpose |
|-------------|------------------|---------|
| **DEX Liquidity** | **45%** | Incentivizing deep books and volume. |
| **Bounty Completion** | **30%** | Funding protocol maintenance and R&D. |
| **Governance Staking** | **15%** | Rewarding long-term alignment. |
| **Strategic Grants** | **10%** | Ecosystem expansion. |

## Buy-Back and Burn Protocol
- **Lending Fees**: 100% swap-to-CXD and burn.
- **Swap Fees**: 100% swap-to-CXD and burn.
- **Registration Fees**: 100% vault recycling.

## Dynamic Performance Trigger
- **Performance State**: If TVL growth > 12% MoM, emission rate increases by 5% to the Bounty Pool to support accelerated development.

## Implementation
- **bme-engine.clar**: Orchestrates meritocratic minting and epoch updates.
- **revenue-distributor.clar**: Routes 100% of revenue to the BME Engine.
- **swap-router.clar**: Executes the automated buy-backs via the Universal Router.

## Implementation Status (March 2026)
- **Verified**: Apex BME logic verified via `tests/csf-full-system.test.ts`.
- **Interoperability**: Native yield routing for stSTX and sBTC fully implemented.
