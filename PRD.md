# Conxian Finance: Product Requirements Document (PRD)

## 1. Executive Summary

Conxian Finance is a multi-dimensional, Stacks-native automated monetary platform. It operates as a **Sovereign Autonomous Business (SAB)** where traditional corporate roles are replaced by autonomous agents and smart contracts. Anchored by Bitcoin security via the Nakamoto upgrade, Conxian provides a neutral, transparent, and highly efficient financial utility for the Stacks ecosystem.

## 2. Stakeholder Analysis

### 2.1. DAO (The Board)
- **Role**: Sovereign decision-making body for strategic upgrades and structural changes.
- **Incentive**: Long-term protocol stability and dividend yield (CXD).

### 2.2. Agents (The Staff)
- **Role**: Autonomous contracts (`agent-risk`, `agent-treasury`) executing daily operations.
- **Incentive**: Hard-coded operational efficiency and protocol health.

### 2.3. Lenders/Borrowers
- **Role**: Provide and utilize capital in the money market.
- **Incentive**: Competitive interest rates and deep liquidity.

### 2.4. Traders
- **Role**: Utilize the DEX for multi-hop swaps and dimensional trading.
- **Incentive**: Low slippage and MEV protection.

## 3. SWOT & PESTLE Analysis

### 3.1. SWOT
- **Strengths**: Bitcoin Finality, Clarity Determinism, Autonomous Fiscal Policy (Fiscal Dam V3).
- **Weaknesses**: High cognitive load (5-token model), dependency on Stacks core timelines.
- **Opportunities**: MiCA compliance, SAB-as-a-Service, institutional "Clean-Hands" lending.
- **Threats**: Regulatory fragmentation, L2 competition.

## 4. Financial Modeling

### 4.1. CAPEX (Initial Build)
- Development of 53 modular Clarity contracts (targeting Clarity 4, currently aligned to Clarity 2/3.0 for compatibility).

### 4.2. OPEX (Maintenance)
- **Staff Payroll**: 20% (Equilibrium) of protocol revenue routed to `operational-treasury`.
- **Governance Dividends**: 60% (Equilibrium) of revenue distributed to CXD stakers.

## 5. Core Architecture

### 5.1. Facade Pattern
The protocol utilizes a Facade Pattern to separate user interaction from core logic.
- **User Facades**: `dimensional-engine.clar`, `swap-router.clar`, `lending-manager.clar`.
- **Core Engines**: `dimensional-core.clar`, `concentrated-liquidity-pool.clar`.

## 6. Technical Specifications

### 6.1. Nakamoto & Tenure Alignment
- **Compatibility Standard**: Contracts use `clarity-version = 2` and `epoch = "3.0"` for broad toolchain support (Simnet).
- **Temporal Logic**: Uses `burn-block-height` for Bitcoin-anchored timing. Logical readiness for `stacks-block-time` (Clarity 4) is maintained.
- **Identity**: Native `secp256r1-verify` readiness for biometric signing.

### 6.2. Cybernetic Autonomous Fiscal Policy (Fiscal Dam V3)
Revenue is dynamically distributed based on system health (Global Collateral Ratio - GCR) and Risk Scores:
- **Equilibrium (Stable)**: 60% Staking, 20% Treasury, 20% Insurance.
- **Crisis (GCR < 110%)**: Up to 100% Insurance for recapitalization.
- **Abundance (GCR > 150%)**: Up to 80% Staking rewards.

## 7. Governance Model (Staff vs Board)

### 7.1. Operational Council (Staff)
- **Engine**: `proposal-engine.clar`.
- **Scope**: Parameter tuning, daily ops. 24/7 autonomous voting.

### 7.2. Strategic Council (Board/AGM)
- **Engine**: `community-voting-engine.clar`.
- `AGM Interval`: Codified at ~1 year (52,560 burn blocks).

## 8. Token System

- **CXD**: Dividend & Governance (Primary).
- **CXVG**: Strategic Voting (AGM).
- **CXS**: Staking & Yield Governance.
- **CXTR**: Treasury & Capital Allocation.
- **CXLP**: Liquidity Position NFTs (SIP-009).

## 9. Security & Risk Management
- **Dimensional Risk**: Implemented in `contracts/dimensional/dimensional-core.clar`.
- **MEV Protection**: Implemented in `contracts/security/mev-protector.clar`.
- **Hybrid Oracle**: Implemented in `contracts/oracle/oracle-aggregator.clar`.
- **Rate Limiting**: Implemented in `contracts/security/rate-limiter.clar`.
- **Proof-of-Reserves**: Implemented in `contracts/security/proof-of-reserves.clar`.

## 10. Implementation Status (February 2026)

### 10.1. CXIP-012: The Cybernetic Upgrade
- **Dual-Clock Standard**: Integrated Fast Gear (Reflexes) and Slow Gear (Strategy) logic via `ops-engine.clar`.
- **Anti-LVR Switch**: Dynamic DEX fees based on real-time volatility.
- **Fiscal Dam V3**: Fully adjusted, cybernetic revenue routing implemented in `agent-treasury.clar`.

### 10.2. Post-Repair Status
- **Dimensional Trading**: Fully operational, verified via system journey tests.
- **Compliance**: Provider-based system implemented in `compliance-manager.clar`.
- **Tokenomics**: 1B CXD supply cap enforced. `cxd-treasury` maintains fiscal dam states.
