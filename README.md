# Conxian Finance Protocol

[![Status](https://img.shields.io/badge/Status-Apex_CSF_Active-green.svg)](https://conxian.io)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Theory](https://img.shields.io/badge/Theory-v2.0_Aligned-blue.svg)](docs/CONXIAN_UNIFIED_THEORY_v2.md)
[![Nakamoto](https://img.shields.io/badge/Nakamoto-Aligned-green.svg)](docs/CLARITY4_MIGRATION_TRACKING.md)

## Purpose

Ship the Conxian Finance Protocol smart contracts (Clarity), including CSF interfaces, core execution engines, and governance primitives, governed by the **Conxian Unified Theory of Sovereign Enterprise (v2.0)**.

## The Unified Theory (v2.0)

The protocol is designed to maximize the **Sovereign Enterprise** equation:
$$Total Value = (C_R \times A_S)^{N_E}$$

- **$C_R$ (Cost of Reproduction)**: Secured via complex Clarity 4 architecture and deep ERP/Gateway integrations.
- **$A_S$ (System Autonomy)**: Driven by the Business Operations System (BOS) and autonomous agents (AYE, Risk/Treasury).
- **$N_E$ (Network Effects)**: Scaled through the Common Settlement Framework (CSF).

For more details, see [**CONXIAN_UNIFIED_THEORY_v2.md**](docs/CONXIAN_UNIFIED_THEORY_v2.md).

## Status

**Technical Alpha - Nakamoto Aligned.**
Testing infrastructure is 100% stable in simulation. All core engines (Apex CSF, BME, AYE) are functional and verified in the remediation suite.

For ongoing changes, see [CHANGELOG.md](CHANGELOG.md).

## Ownership

Ownership and review requirements are defined in [`CODEOWNERS`](./CODEOWNERS).

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

In 2026, Conxian has evolved into the **foundational liquidity gravitational center** of the Stacks ecosystem through the **Common Settlement Framework (CSF)**. It operates as a digital corporation where smart contracts are Managers/Staff reporting to the DAO (Board).

- **Autonomous**: Decisions are executed by code agents (AYE, Apex BME).
- **Standardized**: Inter-protocol routing via CSF (`trait-csf-liquidity-v1`).
- **Resilient**: Multi-tier isolation and circuit breaking for external protocol risks.

## Apex Architecture (2026)

### 🗳️ **Dual-Council Governance (Staff vs Board)**

- **Operational Council (Staff)**: 24/7 voting by autonomous agents (`agent-risk`, `agent-treasury`) for parameter tuning and daily operations.
- **Strategic Council (Board/AGM)**: Periodic Human General Meetings for structural upgrades and major fiscal changes.

### 💰 **Apex BME Engine (Burn-Mint Equilibrium)**

Conxian employs a strictly on-chain algorithmic issuance model (1B CXD hard cap):
- **100% Fee Buy-back**: All protocol fees are autonomously swapped for CXD and burned/vaulted.
- **Meritocratic Emissions**: Emissions are distributed based on block-epoch activity markers registered via CSF.

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

© 2024-2026 Conxian Finance. All rights reserved.
