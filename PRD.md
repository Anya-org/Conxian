# Conxian Finance: Product Requirements Document (PRD)

## 1. Executive Summary

Conxian Finance is a multi-dimensional, Stacks-native automated monetary platform. It operates as a **Sovereign Autonomous Business (SAB)** where traditional corporate roles are replaced by autonomous agents and smart contracts. Anchored by Bitcoin security via the Nakamoto upgrade, Conxian provides a neutral, transparent, and highly efficient financial utility for the Stacks ecosystem.

## 2. Core Functional Modules

### 2.1. Core Ecosystem (Root)
- **Central Registry**: Unified module registration and protocol-wide pause control.
- **Access Control**: Role-based access (RBAC) supporting institutional and retail tiers.
- **Heartbeat Engine**: Automated coordination of protocol state updates and incentive distribution.

### 2.2. Dimensional Trading & Liquidity
- **Leveraged Positions**: Support for multi-dimensional leveraged trading with isolated and cross-margin collateral.
- **Concentrated Liquidity**: High-efficiency DEX engine with tick-based liquidity management.
- **Predictive Routing**: Multi-hop swap optimization using AYE intelligence.

### 2.3. Autonomous Agents (Office Workers)
- **Risk Agent (AYE)**: Predictive risk assessment using PID controllers to adjust stability fees and liquidation thresholds.
- **Treasury Agent**: Automated revenue routing via the Fiscal Dam V4 (CXIP-013).

### 2.4. Governance & Sovereignty
- **Dual-Council DAO**: Separation of strategic (Human) and operational (Agent) decision-making.
- **Sovereign Handoff**: Protocol for trustless transfer of administrative power.

## 3. Implementation Status (Updated February 2026)

### 3.1. Clarity 4 & Nakamoto Standard
- **Status**: COMPLETED (v1.2.0 Core Engines).
- **Details**: All core contracts migrated to Clarity 4 keywords (`stacks-block-time`, `contract-hash?`, etc.).
- **Simulation**: Dual-Clock simulation supported via automated patching layer for current SDK toolchains.

### 3.2. Root-to-Leaf Integrity Refactor
- **Status**: COMPLETED.
- **Details**: Resolved circular dependencies between RBAC, Admin, and Executive layers using Principal Injection. Centralized executive logic in `dimensional-core.clar`.

### 3.3. Fiscal Dam V4 (CXIP-013)
- **Status**: ACTIVE.
- **Details**: 6-way revenue split (Treasury, Bounty, LP, Grant, Buy-back, Insurance) implemented in `agent-treasury.clar` and `revenue-distributor.clar`.

## 4. Recovery Registry (Remedial Actions)

### 4.1. Completed Remedial Actions
- [x] **Task A**: Fix tests/setup-test-env.ts (Asynchronous Race Condition).
- [x] **Task C**: Update regulatory-adapter.clar for SIP-018 Compliance.
- [x] **Task E**: Implement Simulation Compatibility Layer (Nakamoto Simulation Gap).
- [x] **Task F**: Protocol-Wide Principal Injection Refactor (SDK Adherence).
- [x] **Task G**: Documentation-Code Alignment (Feb 2026 Audit).

## 5. Technical Specifications
- **Temporal Alignment**: High-precision yield and vesting using `stacks-block-time`.
- **Identity**: Passkey-ready RBAC via `secp256r1-verify` placeholders.
- **Decision Engine**: Predictive PID controller for stability fees.

---
*End of Document (Archived Feb 2026)*
