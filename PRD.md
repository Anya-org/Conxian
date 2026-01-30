# Conxian Finance Protocol - Product Requirements Document

## 1. Executive Summary

Conxian is a **Sovereign Autonomous Business (SAB)** operating on the Stacks blockchain with Bitcoin finality via Nakamoto consensus.
The protocol implements a full **Everything-as-a-Service (XAAS)** model, providing autonomous DeFi primitives (DEX, Lending, Vaults), multi-council governance, and monetized services.
The system operates like a digital corporation where smart contracts serve as Managers/Agents (Staff) reporting to the DAO (Board).

## 2. Investment-Grade Analysis (The Six-Pillar View)

### 2.1. Business
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
- **Strengths**: Bitcoin security, Clarity 4/Nakamoto alignment, 60/20/20 Fiscal Policy, Reputation meritocracy.
- **Weaknesses**: High 5-token complexity, central admin risk in `allocation-policy`, early-stage agent autonomy.
- **Opportunities**: Sovereign wealth fund integration, automated "Office Manager" for cross-chain liquidity.
- **Threats**: Regulatory scrutiny of autonomous agents, smart contract exploit risks, competitor L2 expansion.

### 3.2. PESTLE
- **Political**: Balancing decentralization with nation-state regulatory demands.
- **Economic**: Sustainability of the 60/20/20 split during low-volume market cycles.
- **Social**: Adoption of "Digital Corporation" models over traditional DAO committees.
- **Technological**: Stacks Nakamoto upgrade stability and Clarity 4 adoption.
- **Legal**: MiCA, GDPR compliance, and legal personality of DAOs.
- **Environmental**: High efficiency via Proof-of-Transfer (PoX) vs traditional PoW.

## 4. Financial Modeling (CAPEX/OPEX)

### 4.1. CAPEX (Initial Build)
- **R&D**: High initial cost for 40+ modular contracts and 5-token governance system.
- **Audits**: Multiple security audits required for core primitives (DEX, Lending, Agents).
- **Licenses**: Legal structuring for SAB entities in compliant jurisdictions.

### 4.2. OPEX (Maintenance)
- **Agent Salaries**: Incentive models for "Staff" agents performing 24/7 maintenance (Payroll model).
- **Infrastructure**: Cost of maintaining RPC nodes and indexing services.
- **Governance**: Rewards for active participants in both Staff and Board councils.

## 5. Gaps & Hurdles (Kill-Switch Risks)

- **Regulatory Wall**: If "Autonomous Agents" are legally banned or restricted, the protocol's core USP is threatened.
- **Complexity Trap**: The 5-token model (CXD/CXVG/CXS/CXTR/CXLP) may fragment governance attention and liquidity.
- **Admin Centralization**: The `allocation-policy` currently allows a single admin to alter revenue shares; needs migration to Board-only voting.

## 6. Opportunity Mapping (Blue Ocean)

- **Autonomous Office Manager**: A coordinator agent that optimizes "Staff" agent performance across multiple protocols.
- **Sovereign Lending**: Bitcoin-backed lending models with 24/7 autonomous risk mitigation.

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

- Use `burn-block-height` for all temporal logic (Vesting, Voting, Staling).
- Minimum 6 Bitcoin confirmations for high-value operations.
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

## 12. Implementation Status (Full Truth Recovery)

### Recently Implemented (PHASE 4)

- **Foundation Consolidation**: Reduced trait redundancy and implemented modular math libraries.
- **Core Stabilization**: Repaired logic and naming in `admin-facade`, `conxian-protocol`, and `risk-manager`.
- **Fiscal Policy**: Completed `revenue-distributor` and `allocation-policy` with 60/20/20 enforcement.
- **Hybrid Governance**: Refined `proposal-engine` (Staff) and `community-voting-engine` (Board) to support Dual-Council governance.
- **Clarity 4 Upgrade**: All core contracts migrated to Clarity 4 (Epoch 3.0), utilizing `burn-block-height` and `get-block-info?` for enhanced precision and tenure-aware security.
- **Nakamoto Transition**: Verified `burn-block-height` usage across all temporal logic.
- **Service Module Repair**: Consolidated DEX, Lending, and Token modules.
- **Autonomous Agents**: Implemented `agent-risk` with `check-work-needed` and `do-work` for automated liquidations.

### Resolved Issues

- **Invalid Syntax**: Fixed type errors in `dex-factory.clar` (removed integer comparison on principals).
- **Functionality Restoration**: Restored full operational logic to DEX and Lending modules, ensuring they are no longer stubs.
- **Tenure Awareness**: Integrated `block-utils` into `conxian-protocol` for real-time tenure ID retrieval.

## 13. Recovery Registry (BOLT ⚡ Initiative)

| File Path | Status | Repair Priority |
| :--- | :--- | :--- |
| `contracts/dex/swap-manager.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/dex/vault.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/lending/lending-manager.clar` | Consolidated | COMPLETED |
| `contracts/governance/dao-treasury.clar` | Aligned with Vault Trait | COMPLETED |
| `contracts/agents/agent-risk.clar` | "Office Worker" Implemented | COMPLETED |
