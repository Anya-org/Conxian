# Conxian Finance Protocol

## Overview

🏦 **Conxian Finance**: A Multi-Dimensional, Stacks-Native Automated Monetary Platform

📜 **SAXAAP Manifesto**
> "Code is Law, Logic is Sovereign."

Conxian is a **Sovereign Autonomous Business (SAB)** where human discretion is replaced by mathematical certainty. It operates like a digital corporation where smart contracts are the Managers/Staff reporting to the DAO (Board).

- **Autonomous**: Decisions are executed by code agents, not committees.
- **Neutral**: The protocol is a public utility, indifferent to borders or identities.
- **Sovereign**: Anchored by Bitcoin's immutable security via Nakamoto consensus.

## Refined Corporate Architecture

### 🗳️ **Dual-Council Governance (Staff vs Board)**

- **Operational Council (Staff)**: 24/7 voting by autonomous agents (`agent-risk`, `agent-treasury`) for parameter tuning and daily operations. Implemented via `proposal-engine.clar`.
- **Strategic Council (Board/AGM)**: Periodic Human General Meetings (Annual/Quarterly) for structural upgrades and major fiscal changes. Implemented via `community-voting-engine.clar`.

### 💰 **Autonomous Fiscal Policy (Cybernetic)**

The protocol employs active **Revenue Collection** levers to fund its ecosystem:
- **Lending**: 10% Reserve Factor on all borrow interest.
- **DEX**: ~16% Protocol Fee on all swaps.
- **Subscription**: Governance-tuned access fees.

Total revenue is dynamically distributed via the **Fiscal Dam** system (V3 Cybernetic Logic):
- **Staking (Dividends)**: Rewards to `cxd-staking` participants (60% Equilibrium target, scales up to 80% in Abundance).
- **Operational Treasury**: Protocol development and autonomous staff expenses (20% Equilibrium target, scales down to 0% in Crisis).
- **Insurance Fund**: Systematic risk reserve (20% Equilibrium target, scales up to 100% in Crisis).

## Technical Stack

- **Clarity 2/3**: Nakamoto-aligned (Epoch 3.0) utilizing `burn-block-height` for Bitcoin anchoring. Currently back-ported to Clarity 2 for Simnet compatibility while remaining logically ready for Clarity 4 (Epoch 3.1).
- **Tenure Awareness**: Logic is aware of Stacks block tenures via `block-utils` for deterministic execution.
- **Facade Pattern**: All core logic accessed via dimensional facades and consolidated traits.
- **Hybrid Oracle**: Aggregated Pyth, Redstone, and Switchboard feeds with deviation guards.

## Repository Structure

```text
/contracts/
├── traits/           # Consolidated modular trait standards
├── core/             # Ops engine, protocol coordinator, and facades
├── dimensional/      # Dimensional trading core and position NFTs
├── dex/              # Swap router, manager, and liquidity pools
├── governance/       # Dual-council DAO (Board/Staff)
├── agents/           # Autonomous Office Workers (Staff)
├── tokens/           # CXD, CXVG, CXS, CXTR, CXLP
├── oracle/           # Price feed adapters and aggregators
├── security/         # Circuit breakers, MEV protection, and PoR
├── lending/          # Automated money markets
├── treasury/         # Revenue distribution (Fiscal Dam) and vaults
├── yield/            # Staking and emission controllers
├── compliance/       # Regulatory adapter and KYC/AML services
├── automation/       # Keeper coordination and block manager
├── identity/         # KYC registry and identity badges
├── bonding/          # Bonding curves and bond factories
├── monitoring/       # Analytics and stability monitors
├── cross-chain/      # Bridge hooks and NFTs
└── math/             # Concentrated liquidity and math utilities
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

- **Maturity Level**: 🟡 **Foundational Stable** (Documentation Alignment Finalized - Feb 2026)
- **Performance**: ⚡ **[Verified Benchmarks](docs/BENCHMARKS.md)** (Avg. < 20ms execution)
- **Strategy**: 📖 **[Research & Strategic Analysis](docs/RESEARCH.md)** (2026 Update)
- **Completed Repairs**:
  - ✅ P1: Sovereign Handoff (timelock execution, admin transfers)
  - ✅ P2: Regulatory Gaps (compliance provider system, KYC/AML)
  - ✅ P3: Tokenomics Clarity (supply caps, 60/20/20 immutability in `cxd-treasury`)
  - ✅ P4: ICO Hardening (compliance gating, purchase caps)
  - ✅ P5: NFT Economics (CXLP Position NFT implementation)
  - ✅ P6: Operational Safety (rate limiter, proof-of-reserves)
- **Architecture**: Full Truth Alignment achieved across Core, DEX, Governance, Economics, and Security.
- **Nakamoto Ready**: All contracts use `burn-block-height` and Epoch 3.0 standards.
- **Next Phase**: Security audit preparation and testnet deployment.

---

© 2024-2026 Conxian Finance. All rights reserved.
