# Conxian Finance Protocol - Product Requirements Document

## 1. Executive Summary

Conxian is a **Sovereign Autonomous Business (SAB)** operating on the Stacks blockchain with Bitcoin finality via
Nakamoto consensus.
The protocol implements a full **Everything-as-a-Service (XAAS)** model, providing autonomous DeFi primitives
(DEX, Lending, Vaults), multi-council governance, and monetized services.
The system operates like a digital corporation where smart contracts serve as Managers/Agents (Staff)
reporting to the DAO (Board).

## 2. Core Architecture

### 2.1. Corporate Analogy

- **DAO (Board of Directors)**: Holds ultimate sovereignty over the protocol. Approves strategic changes.
- **Office Workers (Staff)**: Autonomous agents (`agent-risk`, `agent-treasury`) that execute daily operations.
- **Operational Treasury (Company Accounts)**: Managed by the Executive (Ops Engine) with Board oversight.
- **Revenue Distributor (CFO)**: Automatically enforces the 60/20/20 fiscal policy.

### 2.2. Facade Pattern Architecture

```text
/contracts/traits/ - All trait definitions centralized here
/contracts/[module]/[contract].clar - Individual contracts
/tests/ - Comprehensive test suite
```

## 3. Technical Specifications

### 3.1. Nakamoto & Tenure Alignment

- Use `burn-block-height` for all temporal logic (Vesting, Voting, Staling).
- Minimum 6 Bitcoin confirmations for high-value operations.
- All core logic is tenure-aware, ensuring deterministic behavior across Stacks blocks.

### 3.2. Sovereign Autonomous Fiscal Policy

Revenue generated from all protocol activities (Subscriptions, DEX fees, Lending spreads) is automatically distributed:

- **60% Staking (Dividends)**: Routed to `cxd-staking` to reward governance participants.
- **20% Operational Treasury (R&D/Ops)**: Routed to `operational-treasury` for autonomous staff expenses and protocol development.
- **20% Insurance Fund (Risk Reserve)**: Routed to a dedicated reserve to maintain system solvency during black swan events.

## 4. Governance Model (Staff vs Board)

Conxian implements a **Dual-Council Governance Model**:

### 4.1. Operational Council (Staff)
- **Participants**: Autonomous Agents and Core Developers (Managers).
- **Scope**: Parameter tuning (Interest rates, Risk factors), emergency pauses, and daily treasury allocations.
- **Voting**: Continuous (24/7), lower threshold, fast execution.

### 4.2. Strategic Council (Board/AGM)
- **Participants**: Human Token Holders (Governance token holders).
- **Scope**: Structural upgrades, major fiscal policy changes, and appointment of new modules.
- **Voting**: Periodic (Annual General Meeting - AGM), high quorum required, long duration.
- **AGM Interval**: Codified at ~1 year (52,560 burn blocks).

## 5. Token System Use Cases

The protocol utilizes a 5-token system aligned with specialized councils:

- **CXD (Governance/Revenue)**: The primary dividend token. Receives 60% of protocol revenue. Used for staking and protocol-wide governance.
- **CXVG (Voting/Strategic)**: Used by the Strategic Council (Board) for AGM voting. Implements "Clean-Hands" compliance.
- **CXS (Staking/Yield)**: Specialized for Staking & Yield Curve parameter voting. Implemented via `yield-governance.clar`.
- **CXTR (Treasury/Capital)**: Specialized for Treasury & Capital Allocation voting. Implemented via `treasury-governance.clar`.
- **CXLP (Liquidity/Gauges)**: Specialized for Liquidity & AMM Weighting. Implemented via `gauge-manager.clar`.

## 6. Security & Risk Management

- **Dimensional Risk**: Maintenance Margin scales quadratically with leverage: $MM = MM_{base} + Leverage^2$.
- **MEV Protection**: Commit-Reveal scheme enforced for all DEX operations to prevent frontrunning.
- **Hybrid Oracle**: Aggregates Pyth, Redstone, and Switchboard with deviation guards.

## 11. Implementation Status (Full Truth Recovery)

### Recently Implemented (PHASE 4)

- **Foundation Consolidation**: Reduced trait redundancy and implemented modular math libraries.
- **Core stabilization**: Repaired logic and naming in `admin-facade`, `conxian-protocol`, and `risk-manager`.
- **Fiscal Policy**: Completed `revenue-distributor` and `allocation-policy` with 60/20/20 enforcement.
- **Hybrid Governance**: Refined `proposal-engine` (Staff) and `community-voting-engine` (Board) to support Dual-Council governance.
- **Nakamoto Transition**: Verified `burn-block-height` usage across all temporal logic.
- **Service Module Repair**: Consolidated DEX, Lending, and Token modules.

### Resolved Issues

- **Invalid Syntax**: Fixed type errors in `dex-factory.clar` (removed integer comparison on principals).
- **Functionality Restoration**: Restored full operational logic to DEX and Lending modules, ensuring they are no longer stubs.
- **Tenure Awareness**: Integrated `block-utils` into `conxian-protocol` for real-time tenure ID retrieval.

## 12. Recovery Registry (BOLT ⚡ Initiative)

| File Path | Status | Repair Priority |
| :--- | :--- | :--- |
| `contracts/dex/swap-manager.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/dex/vault.clar` | Repaired (Clarity 2) | COMPLETED |
| `contracts/lending/lending-manager.clar` | Consolidated | COMPLETED |
| `contracts/governance/dao-treasury.clar` | Aligned with Vault Trait | COMPLETED |
