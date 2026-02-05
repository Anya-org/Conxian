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
- **Unit Economics**: 60/20/20 revenue distribution split (Staking/Dev/Insurance).
- **Market Defensibility**: Native Bitcoin finality (Nakamoto) and a "Full Truth" autonomous agent model.
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
  - **Determinism**: Clarity 3 decidability prevents "Re-entrancy" and other EVM-common bugs. Clarity 4 migration prepared for when mainnet activates Epoch 3.1.
  - **Autonomous Fiscal Policy**: Hard-coded 60/20/20 revenue split ensures long-term solvency.
  - **Operational Efficiency**: 24/7 "Staff" agents reduce human overhead and reaction time.
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

- **R&D (High)**: Development of 53 modular Clarity 3 contracts (migrating to Clarity 4 upon mainnet Epoch 3.1 activation). Estimated 25,000+ developer hours.
- **Security Audits**: Critical for "Full Truth" recovery. Estimated budget: $150,000 - $300,000 for core primitives.
- **Legal Architecture**: Establishing the SAB's legal personality in MiCA-friendly jurisdictions (e.g., Switzerland/Luxembourg).

### 4.2. OPEX (Maintenance)

- **Staff Payroll (Autonomous)**: 20% of protocol revenue is automatically routed to `operational-treasury` to pay "Keepers" and "Agents" via `office-manager`.
- **Governance Dividends**: 60% of revenue distributed to CXD stakers, ensuring a high yield-to-governance ratio.
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
- **Revenue Distributor (CFO)**: Automatically enforces the 60/20/20 fiscal policy.

### 7.2. Facade Pattern Architecture

```text
/contracts/traits/ - All trait definitions centralized here
/contracts/[module]/[contract].clar - Individual contracts
/tests/ - Comprehensive test suite
```

## 8. Technical Specifications

### 8.1. Nakamoto & Tenure Alignment

- Use `stacks-block-time` for all temporal logic (Vesting, Voting, Staling) to ensure second-level precision.
- Minimum 6 Bitcoin confirmations for high-value operations via `block-utils`.
- All core logic is tenure-aware via `block-utils`, ensuring deterministic behavior across Stacks blocks.

### 8.2. Sovereign Autonomous Fiscal Policy

Revenue generated from all protocol activities (Subscriptions, DEX fees, Lending spreads) is automatically distributed:

- **60% Staking (Dividends)**: Routed to `cxd-staking` to reward governance participants.
- **20% Operational Treasury (R&D/Ops)**: Routed to `operational-treasury` for autonomous staff expenses and protocol development.
- **20% Insurance Fund (Risk Reserve)**: Routed to a dedicated reserve to maintain system solvency during black swan events.

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

## 12. Implementation Status (January 2026)
### 12.0 CXIP-012: The Cybernetic Upgrade (v0.6.1)

- **Dual-Clock Standard**: Integrated Fast Gear (Reflexes) and Slow Gear (Strategy) logic.
- **Anti-LVR Switch**: Dynamic DEX fees based on real-time volatility.
- **Fiscal Dam**: Adaptive revenue routing based on Global Collateral Ratio (GCR).
- **Chainhook Readiness**: Prepared for event-driven automation.

### 12.1 Current State: Cybernetic Protocol Upgrade (v0.6.1)

**Completed Priority Repairs (P1-P6)**:

| Priority | Component | Status | Key Deliverables |
|----------|-----------|--------|------------------|
| P1 | Sovereign Handoff | Complete | Timelock execution, 5-step transfer, admin role migration |
| P2 | Regulatory Gaps | Complete | Provider-based compliance, KYC/AML attestation, sanctions screening |
| P3 | Tokenomics | Complete | CXD supply cap (1B), 60/20/20 immutability lock |
| P4 | ICO Hardening | Complete | Compliance gating, purchase caps, buyer tracking |
| P5 | NFT Economics | Complete | CXLP Position NFT (SIP-009, metadata, fees) |
| P6 | Operational Safety | Complete | Rate limiter, proof-of-reserves, circuit breakers |

### 12.2 Clarity 3 / Nakamoto Compliance

- All contracts use `clarity-version = 3` for mainnet compatibility
- Epoch 3.0 activated in `Clarinet.toml`
- `burn-block-height` used for Bitcoin-anchored temporal logic
- Clarity 4 migration tracked in `docs/CLARITY4_MIGRATION_TRACKING.md`
- `stacks-block-time` and `contract-hash?` prepared for future activation

### 12.3 Testing & Deployment Readiness

- `clarinet check` passing on all modified contracts
- Unit test coverage >80% for new functions
- Testnet deployment validated
- Sovereign handoff procedure verified
- Security audit scope defined

### 12.4 Architecture Refactors

- **Hybrid Governance**: Refined `proposal-engine` (Staff) and `community-voting-engine` (Board) to support Dual-Council governance.
- **Clarity 4 Protocol Preparation**: Core contracts prepared for Clarity 4 (Epoch 3.1), utilizing `stacks-block-time` for high-precision temporal logic and `contract-hash?` for secure module registry. Currently Clarity 3 for mainnet compatibility.
- **Nakamoto Transition**: Switched from legacy `block-height` to `stacks-block-time` for all yield, voting, and timelock accrual, ensuring deterministic behavior in fast-block environments.
- **Service Module Repair**: Consolidated DEX, Lending, and Token modules.
- **Autonomous Agents**: Implemented `agent-risk` with `check-work-needed` and `do-work` for automated liquidations.

## 13. Recovery Registry (BOLT Initiative)

| File Path | Status | Repair Priority |
| :--- | :--- | :--- |
| `contracts/dex/swap-manager.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/dex/vault.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/lending/lending-manager.clar` | Consolidated | COMPLETED |
| `contracts/governance/dao-treasury.clar` | Aligned with Vault Trait | COMPLETED |
| `contracts/agents/agent-risk.clar` | "Office Worker" Implemented | COMPLETED |
