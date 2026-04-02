# Conxian Finance Protocol

[![Status](https://img.shields.io/badge/Status-Apex_CSF_Active-green.svg)](https://conxian.io)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Nakamoto](https://img.shields.io/badge/Nakamoto-Aligned-green.svg)](docs/CLARITY4_MIGRATION_TRACKING.md)

## Purpose

Ship the Conxian Finance Protocol smart contracts (Clarity), including CSF interfaces, core execution engines, and governance primitives.

## Status

Active development (alpha). Not production-ready; expect breaking changes.

For a dated snapshot, see [Status (March 2026)](#status-march-2026). For ongoing changes, see [CHANGELOG.md](CHANGELOG.md).

## Audience

- Clarity engineers integrating with CSF standards and Conxian primitives.
- Security reviewers validating contract behavior, invariants, and integration surfaces.
- Frontend and indexer developers building on top of Conxian protocol state.

## Relationship to the Conxian stack

- This is the on-chain execution layer.
- It is typically consumed via:
  - [Conxian Gateway](https://github.com/Conxian/conxian-gateway) (API + indexing)
  - [Conxian UI](https://github.com/Conxian/Conxian_UI) (`Conxian_UI`)
  - [Conxius Wallet](https://github.com/Conxian/conxius-wallet)

## Overview

🏦 **Conxian Finance**: A Multi-Dimensional, Stacks-Native Automated Monetary Platform.

📜 **SAXAAP Manifesto**
> "Code is Law, Logic is Sovereign."

In 2026, Conxian has evolved from an isolated protocol into the **foundational liquidity gravitational center** of the Stacks ecosystem through the **Common Settlement Framework (CSF)**. It operates as a digital corporation where smart contracts are Managers/Staff reporting to the DAO (Board), now with native integrations for dominant players like StackingDAO, Zest, and Arkadiko.

- **Autonomous**: Decisions are executed by code agents (AYE, Apex BME).
- **Standardized**: Inter-protocol routing via CSF (`trait-csf-liquidity-v1`).
- **Resilient**: Multi-tier isolation and circuit breaking for external protocol risks.

## Apex Architecture (2026)

### 🗳️ **Dual-Council Governance (Staff vs Board)**

- **Operational Council (Staff)**: 24/7 voting by autonomous agents (`agent-risk`, `agent-treasury`) for parameter tuning and daily operations.
- **Strategic Council (Board/AGM)**: Periodic Human General Meetings for structural upgrades and major fiscal changes.

### 💰 **Apex BME Engine (Burn-Mint Equilibrium)**

Conxian employs a strictly on-chain algorithmic issuance model (1B CXD hard cap):
- **100% Fee Buy-back**: All protocol fees (Lending, DEX, Subscription) are autonomously swapped for CXD and burned/vaulted.
- **Meritocratic Emissions**: Emissions are distributed based on block-epoch activity markers registered via CSF.
- **Yield Routing**: Automated rewards for liquid staking (stSTX) and BTC lending (sBTC) without breaking the custody chain.

### 🌐 **Common Settlement Framework (CSF)**

The CSF is a standardized interface that allows third-party protocols to natively plug into Conxian's reward engine:
- **Liquid Staking**: Treats stSTX and stSTXbtc as Tier-1 collateral.
- **BTC Lending**: Guaranteed liquidation sinks for Zest Protocol sBTC loans.
- **Stable Routing**: USDA (Arkadiko 2.0) as the base asset for risk-off routing.

## Technical Stack

- **Clarity 4**: Nakamoto-native utilizing `stacks-block-time` and `burn-block-height`.
- **Apex Universal Router**: Dynamic dispatch router with circuit-breaker protection.
- **Enhanced Security**: Isolation Mode to prevent cross-protocol contagion.

## Repository Structure

```text
/contracts/
├── traits/           # CSF standards (v1.1.0) and SIP traits
├── core/             # Ops engine, Enhanced Circuit Breaker, BME
├── dex/              # Apex Universal Router, CL Pools (CSF-Compliant)
├── agents/           # AYE Predictive Risk, Sovereign Fiscal Agent
├── tokens/           # CXD (BME-Enabled), Governance, Position NFTs
├── oracle/           # Multi-source aggregator for 2026 assets (sBTC, stSTX)
├── treasury/         # Revenue routing and Apex BME Vaults
└── ...               # Lending, Monitoring, Security, Compliance
```

## Status (March 2026)

- **Maturity (as of March 2026)**: Snapshot of the then-current alpha-stage protocol; see [Status](#status) for the latest maturity and stability guidance.
- **Snapshot highlights**:
  - CSF traits and interfaces: [`contracts/traits/`](contracts/traits/)
  - Router and DEX modules: [`contracts/dex/`](contracts/dex/)
  - Core safety and execution engines: [`contracts/core/`](contracts/core/)
- **Nakamoto / Clarity 4 alignment**: [Clarity 4 migration tracking](docs/CLARITY4_MIGRATION_TRACKING.md)
- **Benchmarks (simnet)**: [Protocol benchmarks](docs/BENCHMARKS.md)
- **Recent reports and plans**:
  - [Deployment sign-off (March 2026)](DEPLOYMENT_SIGN_OFF_MARCH_2026.md) (root-level report)
  - [Enhancement plan (March 2026)](ENHANCEMENT_PLAN_MARCH_2026.md) (root-level report)
  - [System alignment audit (March 2026)](docs/SYSTEM_ALIGNMENT_AUDIT_MARCH_2026.md)

© 2024-2026 Conxian Finance. All rights reserved.
