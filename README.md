# Conxian Finance Protocol

## Overview

🏦 **Conxian Finance**: A Multi-Dimensional, Stacks-Native Automated Monetary Platform

📜 **SAXAAP Manifesto**
> "Code is Law, Logic is Sovereign."

Conxian is not a financial service provider; it is an autonomous digital organism. It operates as a **Sovereign Autonomous Business (SAB)** where human discretion is replaced by mathematical certainty.

- **Autonomous**: Decisions are executed by code, not committees
- **Neutral**: The protocol is a public utility, indifferent to borders or identities  
- **Sovereign**: Conxian lives on "Stacks Blockchain" anchored by Bitcoin's immutable security

## Architecture

### 🏗️ **Facade Pattern & Trait System**

- **Centralized Traits**: All interfaces defined in `/contracts/traits/`
- **Modular Contracts**: Single-responsibility contracts in dedicated modules
- **Bitcoin Finality**: All operations anchored to Nakamoto consensus
- **Censorship Resistance**: Critical actions performable by any user

### 📊 **Multi-Dimensional DeFi System**

**Core DeFi Primitives:**

- **DEX**: Concentrated liquidity, multi-hop routing, batch auctions
- **Lending**: Automated money markets with Kinked-Curve Interest Rate Models
- **Vaults**: sBTC integration, yield aggregation, custody solutions
- **Tokens**: CXD (governance), CXS (staking), CXTR (treasury), CXLP (liquidity), DRT (position NFT)

**Enterprise and Yield Features:**

- `enterprise-api.clar`: Provides tiered institutional accounts, advanced order types, and compliance integration.
- `compliance-hooks.clar`: Offers hooks for KYC/AML checks and other compliance-related functions.
- `yield-optimizer.clar`: Analyzes strategies and rebalances funds for optimal APY, with performance tracking and auto-compounding capabilities.
- `auto-compounder.clar`: Automates yield compounding for connected vaults.

**Performance and Compatibility:**

- `performance-optimizer.clar`: Monitors and optimizes gas usage and transaction throughput.
- `legacy-adapter.clar`: Provides a backward-compatible interface to legacy contracts during migration.
- `migration-manager.clar`: Manages data migration from legacy contracts to the enhanced system.

**SAXAAP Business Model:**

- **Revenue Generation**: Subscription fees (1 STX), transaction fees, service charges
- **Revenue Distribution**: Autonomous 60/20/20 split (Staking/Dev/Insurance) via `revenue-distributor`
- **Multi-Council Governance**: 5 specialized automated seats
- **Office Workers**: Autonomous liquidations and treasury operations

### 🗳️ **5-Tier Governance System**

- **CXD (Debt)**: Automates stability and collateral ratios
- **CXVG (Governance)**: Manages systemic logic and upgrades  
- **CXTR (Treasury)**: Rebalances reserves against BTC/STX volatility
- **CXS (Staking)**: Manages yield distribution and reputation logic
- **CXLP (Liquidity)**: Optimizes AMM depth and fee structures

## Technical Stack

### ⚡ **Stacks-Native Components**

- **Clarity 4**: Smart contract language with Bitcoin anchoring
- **Nakamoto Compatibility**: 6 Bitcoin confirmations for high-value operations
- **Multi-Oracle System**: Chainlink, Pyth, Redstone, DIA, TWAP adapters
- **Cross-Chain**: Wormhole integration for sovereign token transfers

### 🔧 **Development Tools**

- **Clarinet SDK**: Contract development and testing
- **StacksOrbit**: Deployment automation
- **Vitest**: Comprehensive test suite

## Repository Structure

```text
/contracts/
├── traits/           # All trait definitions (centralized)
├── core/             # Dimensional engine, risk management
├── dex/              # Decentralized exchange logic
├── governance/       # 5-tier DAO system
├── tokens/           # Multi-token system
├── oracle/           # Price feed adapters
├── security/         # Circuit breakers, monitoring
├── lending/          # Money markets
├── vaults/           # Custody and yield
└── utils/            # Shared utilities
```

## Development

### Prerequisites

- Clarinet 3.12+
- Node.js 18+
- Git

### Getting Started

1. **Install Dependencies**

   ```bash
   npm install
   ```

2. **Run Tests**

   ```bash
   npm run coverage
   ```

3. **Contract Check**

   ```bash
   clarinet check
   ```

4. **Local Development**

   ```bash
   clarinet console
   ```

## License

Conxian Finance Protocol is distributed under the **GNU General Public License v3 (GPLv3)**.

**Why GPLv3?**

- **Hands-Off Sovereignty**: Establishes the protocol as a "public good"
- **Permissionless Growth**: Anyone can fork or build on Conxian
- **No Commercial Capture**: Prevents centralization of the protocol

---

## Status

- **Maturity Level**: 🟡 **Root Foundation Stable** (Recovered 2026-01-16)
- **Architecture**: Facade-Based & Trait-Driven (Top-down recovery in progress)
- **Next Steps**: Extension of the stable root to collateral and position managers; Nakamoto compatibility audit.

**Disclaimer**: This project is in a Technical Alpha stage. Features represent the target design, not all functionality is fully implemented.

---

© 2024-2026 Conxian Finance. All rights reserved.
