---
layout: default
title: Product Requirements Document (PRD)
permalink: /PRD/
---

# Conxian Finance Protocol - Product Requirements Document

## 1. Executive Summary

Conxian is a **Sovereign Autonomous Business (SAB)** operating on the Stacks blockchain with Bitcoin finality via Nakamoto consensus.
The protocol implements a full **Everything-as-a-Service (XAAS)** model, providing autonomous DeFi primitives (DEX, Lending, Vaults), multi-council governance, and monetized services.
The system operates like a digital corporation where smart contracts serve as Managers/Agents (Staff) reporting to the DAO (Board).

## 2. Investment-Grade Analysis (The Six-Pillar View)

### 2.1. Business

- **Revenue Engines**:
  - **Lending**: 10% Reserve Factor on interest spreads.
  - **DEX**: ~1/6th Protocol Fee on swap volume.
  - **Services**: Subscription fees for advanced tools.
- **Unit Economics**: Intelligence-Led Adaptive Yield Engine (AYE) dynamically rebalances revenue. Target: 60/20/20 (Staking/Dev/Insurance).
- **Market Defensibility**: Native Bitcoin finality (Nakamoto), "Full Truth" autonomous agent model, and the world's first "Self-Correcting" DeFi fiscal policy.
- **LTV/CAC**: High LTV via subscription-based services (XAAS) and automated liquidations; low CAC through community-driven "Staff" governance.

### 2.2. Regulations

- **Compliance-by-Design**: Integrated `regulatory-adapter` enforcing "Clean-Hands" for Strategic Council voters.
- **Jurisdictional Hurdles**: MiCA-aligned council structure for EU operations; SOC2 readiness via deterministic agent auditing.
- **Travel Rule**: Implementation logic for encrypted PII proofs scheduled for Institutional Phase.

### 2.3. Enterprise

- **Operational Resilience**: Dual-Council governance (Staff vs Board) separates daily ops from strategic changes.
- **SLA Requirements**: Autonomous `agent-risk` ensures 24/7 monitoring and position maintenance.

### 2.4. SME

- **Accessibility**: B2B value-add through modular DeFi primitives that SMEs can wrap or integrate.
- **Friction Reduction**: Lowering capital requirements via efficient Kinked Curve lending models.

### 2.5. Retail

- **UX Abstraction**: Transitioning from complex Clarity interactions to "One-Click" sovereign positions.
- **Psychological Triggers**: Yield-bearing dividends (CXD) and gamified reputation (CXVG).

### 2.6. Entrepreneur

- **Lean Execution**: Facade Pattern architecture allows for rapid module hot-swapping without core re-audits.
- **Speed-to-Market**: Reusing verified "Staff" agent skeletons for new financial services.

## 3. SWOT & PESTLE Analysis

### 3.1. SWOT

- **Strengths**:
  - **Bitcoin Finality**: Inheritance of BTC security via Nakamoto/PoX.
  - **Determinism**: Clarity 4 decidability prevents "Re-entrancy" and other EVM-common bugs.
- **Autonomous Fiscal Policy**: Intelligence-Led AYE with PID/Fuzzy transitions ensures predictive solvency.
- **Operational Efficiency**: 24/7 "Staff" agents with predictive risk perception (Agent-Risk 2.0).
- **Weaknesses**:
  - **Cognitive Load**: 5-token model (CXD/CXVG/CXS/CXTR/CXLP) requires steep user education.
  - **Dependency**: Reliance on Stacks core upgrade timelines (Nakamoto).
  - **Early Autonomy**: "Staff" agents currently handle limited scopes (Liquidations/Treasury).
- **Opportunities**:
  - **XAAS Adoption**: Providing sovereign infrastructure for institutional DeFi sub-DAOs.
  - **MiCA Compliance**: First-mover advantage in compliant Bitcoin DeFi for the EU market.
  - **Sovereign Wealth**: Attracting state-level capital seeking "Bitcoin-Native" yield.
- **Threats**:
  - **L2 Fragmentation**: Rapid TVL migration to EVM-based Bitcoin L2s (Merlin, BOB).
  - **Regulatory "Kill-Switch"**: Bans on autonomous agent legal personality or strict liability without safe harbors.

### 3.2. PESTLE

- **Political**: Tension between DAO sovereignty and nation-state regulatory frameworks.
- **Economic**: Bitcoin's role as "Digital Gold" vs the protocol's need for high-velocity DeFi activity.
- **Social**: Shifting trust from human intermediaries to verifiable autonomous agents.
- **Technological**: Complexity of cross-chain "Staff" orchestration via Wormhole/Zink.
- **Legal**: Navigation of MiCA stablecoin bans (Algorithmic) and Travel Rule data-sharing requirements.
- **Environmental**: High efficiency of PoX (reusing existing PoW) aligns with ESG mandates.

## 4. Financial Modeling (CAPEX/OPEX)

### 4.1. CAPEX (Initial Build)

- **R&D (High)**: Development of 40+ modular Clarity 4 contracts. Estimated 25,000+ developer hours.
- **Security Audits**: Critical for "Full Truth" recovery. Estimated budget: $150,000 - $300,000 for core primitives.
- **Legal Architecture**: Establishing the SAB's legal personality in MiCA-friendly jurisdictions (e.g., Switzerland/Luxembourg).

### 4.2. OPEX (Maintenance)

- **Staff Payroll (Autonomous)**: 20% of protocol revenue is automatically routed to `operational-treasury` to pay "Keepers" and "Agents" via `office-manager`.
- **Governance Dividends**: Target 60% of revenue distributed to CXD stakers via AYE, with priority claims backfilled during defensive recovery.
- **Infrastructure**: Costs for RPC nodes, indexing, and front-end hosting (decentralized via IPFS).

## 5. Gaps & Hurdles (Kill-Switch Risks)

- **The "Agent Liability" Wall**: If regulators hold all protocol developers strictly liable for autonomous agent actions, the "Staff" model becomes a liability risk.
- **MiCA Algorithmic Ban**: If Conxian implements algorithmic stablecoins, they will be effectively barred from the EU market. Protocol must prioritize asset-backed (1:1) models.
- **Tenure Inconsistency**: High latency in Bitcoin block times (even with Stacks fast blocks) may affect high-frequency risk management.

## 6. Opportunity Mapping (Blue Ocean)

- **SAB-as-a-Service**: Offering the Conxian "Corporate Engine" (Governance + Staff + Treasury) as a template for other decentralized businesses.
- **Institutional "Clean-Hands" Lending**: Utilizing the `regulatory-adapter` to offer KYC/AML-compliant lending pools for traditional finance (TradFi) entry.
- **Autonomous Cross-Chain Yield**: Deploying "Agents" to other L2s (Liquid, Merlin) to aggregate yield back to Stacks/Bitcoin.

## 7. Core Architecture

### 7.1. Corporate Analogy

- **DAO (Board of Directors)**: Holds ultimate sovereignty over the protocol. Approves strategic changes.
- **Office Workers (Staff)**: Autonomous agents (`agent-risk`, `agent-treasury`) that execute daily operations.
- **Operational Treasury (Company Accounts)**: Managed by the Executive (Ops Engine) with Board oversight.
- **Revenue Distributor (CFO)**: Automatically enforces AYE fiscal policy with predictive claim accrual.
- **Adaptive Yield Engine (AYE)**: The "Monetary Fund" module implementing PID control and Fuzzy Logic state transitions.

### 7.2. Facade Pattern Architecture

```text
/contracts/traits/ - All trait definitions centralized here
/contracts/[module]/[contract].clar - Individual contracts
/tests/ - Comprehensive test suite
```

## 8. Technical Specifications

### 8.1. Nakamoto & Tenure Alignment

- Use `burn-block-height` (Bitcoin-anchored height) for all temporal logic (Vesting, Voting, Staking) to ensure cross-era consistency and Bitcoin finality.
- Minimum 6 Bitcoin confirmations for high-value operations via `block-utils`.
- All core logic is tenure-aware via `block-utils`, ensuring deterministic behavior across Stacks blocks.

### 8.2. Sovereign Autonomous Fiscal Policy (Intelligence-Led)

Revenue generated from all protocol activities is dynamically distributed via the **Adaptive Yield Engine (AYE)**:

- **Target State (Equilibrium)**: 60% Staking / 20% Treasury / 20% Insurance.
- **Predictive State (Pre-emptive)**: 40-55% Staking / 20% Treasury / 25-40% Insurance.
- **Crisis State (Defensive)**: 0-10% Staking / 20% Treasury / 70-80% Insurance.
- **Priority Claims**: Any yield diverted from stakers during Defensive/Pre-emptive states is recorded as an "Accrued Claim" for future backfilling.

## 9. Governance Model (Staff vs Board)

Conxian implements a **Dual-Council Governance Model**:

### 9.1. Operational Council (Staff)

- **Participants**: Autonomous Agents and Core Developers (Managers).
- **Scope**: Parameter tuning (Interest rates, Risk factors), emergency pauses, and daily treasury allocations.
- **Voting**: Continuous (24/7), lower threshold, fast execution. Implemented via `proposal-engine.clar`.

### 9.2. Strategic Council (Board/AGM)

- **Participants**: Human Token Holders (Governance token holders).
- **Scope**: Structural upgrades, major fiscal policy changes, and appointment of new modules.
- **Voting**: Periodic (Annual General Meeting - AGM), high quorum required, long duration.
- **AGM Interval**: Codified at ~1 year (52,560 burn blocks) in `community-voting-engine.clar`.

## 10. Token System Use Cases

The protocol utilizes a 5-token system aligned with specialized councils:

- **CXD (Governance/Revenue)**: The primary dividend token. Receives 60% of protocol revenue. Used for staking and protocol-wide governance.
- **CXVG (Voting/Strategic)**: Used by the Strategic Council (Board) for AGM voting. Implements "Clean-Hands" compliance.
- **CXS (Staking/Yield)**: Specialized for Staking & Yield Curve parameter voting. Implemented via `yield-governance.clar`.
- **CXTR (Treasury/Capital)**: Specialized for Treasury & Capital Allocation voting. Implemented via `treasury-governance.clar`.
- **CXLP (Liquidity/Gauges)**: Specialized for Liquidity & AMM Weighting. Implemented via `gauge-manager.clar`.

## 11. Security & Risk Management

- **Dimensional Risk**: Maintenance Margin scales quadratically with leverage: $MM = MM_{base} + Leverage^2$. Implemented in `dimensional-core.clar`.
- **MEV Protection**: Commit-Reveal scheme enforced for all DEX operations to prevent frontrunning. Implemented in `mev-protector.clar`.
- **Hybrid Oracle**: Aggregates Pyth, Redstone, and Switchboard with deviation guards. Implemented in `oracle-aggregator.clar`.

## 12. Recovery Registry (BOLT Initiative)

| Component / File Path | Issue | Status | Repair Priority |
| :--- | :--- | :--- | :--- |
| `tests/setup-test-env.ts` | `initSimnet()` race condition and non-deterministic initialization | COMPLETED | - |
| `Clarinet.toml` | Clarity 4 vs Epoch 2.1 mismatch / Deployment errors | COMPLETED | - |
| `tests/` | Major Test-Contract Mismatch (Tests calling non-existent functions) | PENDING | HIGH |
| `Clarinet.toml` | Missing `mock-circuit-breaker` and other test dependencies | PENDING | MEDIUM |
| `tests/security.skip/` | Hardcoded `ST*` addresses and `TypeError` in circuit-breaker tests | PENDING | MEDIUM |
| `ui/src/tests/` | API Service test failures due to missing contract mocks | PENDING | LOW |
| `contracts/dex/swap-manager.clar` | Repaired (Clarity 2) | COMPLETED | - |
| `contracts/dex/vault.clar` | Repaired (Clarity 2) | COMPLETED | - |
| `contracts/lending/lending-manager.clar` | Consolidated | COMPLETED | - |
| `contracts/governance/dao-treasury.clar` | Aligned with Vault Trait | COMPLETED | - |
| `contracts/agents/agent-risk.clar` | "Office Worker" Implemented | COMPLETED | - |

**Next Logical Task**: Synchronize DEX and Lending tests with current contract implementations (Phase 2: Module Fix).

## 13. Performance & Benchmarks (February 2026)

### 13.1 Fresh Full Info
- **Current Stability**: ~30% (Foundation stable, Core logic passing, DEX/System tests failing due to out-of-sync logic).
- **Blockers**: Major discrepancy between test suite expectations and actual contract interfaces.
- **Gas Metrics**: Core transactions (Swap/Stake) verified within Nakamoto limits (< 20ms execution).

### 13.2 Verified Benchmarks

Detailed execution metrics and scalability data can be found in the [Protocol Benchmarks](docs/BENCHMARKS.md) document.
Current performance confirms < 20ms execution for core financial primitives.

Strategic analysis of the competitive landscape and regulatory environment is available in the [Research & Strategic Analysis](docs/RESEARCH.md) document.
