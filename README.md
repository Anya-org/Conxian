# Conxian Finance Protocol

## Overview

🏦 **Conxian Finance**: A Multi-Dimensional, Stacks-Native Automated Monetary Platform

📜 **SAXAAP Manifesto**
> "Code is Law, Logic is Sovereign."

Conxian is a **Sovereign Autonomous Business (SAB)** where human discretion is replaced by mathematical certainty. It operates like a digital corporation where smart contracts are the Managers/Staff reporting to the DAO (Board).

- **Autonomous**: Decisions are executed by code agents, not committees
- **Neutral**: The protocol is a public utility, indifferent to borders or identities  
- **Sovereign**: Anchored by Bitcoin's immutable security via Nakamoto consensus

## Refined Corporate Architecture

### 🗳️ **Dual-Council Governance (Staff vs Board)**

- **Operational Council (Staff)**: 24/7 voting by autonomous agents (`agent-risk`, `agent-treasury`) for parameter tuning and daily operations.
- **Strategic Council (Board/AGM)**: Periodic Human General Meetings (Annual/Quarterly) for structural upgrades and major fiscal changes.

### 💰 **Autonomous Fiscal Policy (60/20/20)**

Total revenue is automatically distributed:
- **60% Staking**: Rewards to `cxd-staking` participants.
- **20% Operational Treasury**: Protocol development and autonomous staff expenses.
- **20% Insurance Fund**: Systematic risk reserve.

## Technical Stack

- **Clarity 2**: Nakamoto-aligned with `burn-block-height` and Bitcoin finality.
- **Tenure Awareness**: Logic is aware of Stacks block tenures for deterministic execution.
- **Facade Pattern**: All core logic accessed via dimensional facades and consolidated traits.
- **Hybrid Oracle**: Aggregated Pyth, Redstone, and Switchboard feeds with deviation guards.

## Repository Structure

```text
/contracts/
├── traits/           # Consolidated modular trait standards
├── core/             # Ops engine, risk/collateral/position managers
├── dex/              # Concentrated liquidity, swap router, vault
├── governance/       # Dual-council DAO (Board)
├── agents/           # Autonomous Office Workers (Staff)
├── tokens/           # CXD, CXVG, CXS, CXTR, CXLP
├── oracle/           # Price feed adapters and aggregators
├── security/         # Circuit breakers and MEV protection
├── lending/          # Automated money markets
├── vaults/           # sBTC integration and yield aggregation
└── utils/            # Tenure and encoding utilities
```

## Development

### Prerequisites

- Clarinet 3.12+
- Node.js 18+

### Getting Started

1. **Install Dependencies**
   ```bash
   npm install
   ```
2. **Run Tests**
   ```bash
   npm test
   ```

---

## Status

- **Maturity Level**: 🟢 **Service Modules Repaired** (Refined 2026-01-16)
- **Architecture**: Full Truth Alignment achieved across Core, DEX, Governance, and Economics.
- **Nakamoto Ready**: Transitioned all temporal logic to `burn-block-height`.

---

© 2024-2026 Conxian Finance. All rights reserved.
