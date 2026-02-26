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

## 4. Technical Specifications
- **Temporal Alignment**: High-precision yield and vesting using `stacks-block-time`.
- **Identity**: Passkey-ready RBAC via `secp256r1-verify` placeholders.
- **Decision Engine**: Predictive PID controller for stability fees.

## 5. Fiscal Policy & Revenue Distribution

### 5.1. Sovereign Baseline (60/20/20)
The protocol's long-term equilibrium target for revenue distribution:
- **60% Dividends/LP Incentives**: Rewarding liquidity and capital.
- **20% R&D / Bounty**: Funding protocol evolution and maintenance.
- **20% Insurance / Stability**: Ensuring systemic solvency.

### 5.2. CXIP-013 Performance Overlay
Active cybernetic distribution model used during the growth phase:
- **Core Treasury (45%)**: Protocol development.
- **Bounty Pool (30%)**: Incentivizing active contributors.
- **LP Incentives (15%)**: Staking rewards.
- **Grants (5%)**: Ecosystem growth.
- **Buy-back (5%)**: Price support.
- **Performance Trigger**: If TVL growth > 12% MoM or Bounty rate > 95%, 5% shifts from Treasury to Bounty.

### 5.3. The Fiscal Dam (State Transitions)
- **CRISIS (GCR < 110%)**: 100% Insurance.
- **STABILITY (110% < GCR < 150%)**: CXIP-013 Baseline.
- **ABUNDANCE (GCR > 150%)**: 80% LP, 10% Treasury, 10% Insurance.

## 12. Recovery Registry (Failure Points)

| Issue ID | Title | Status | Details |
| :--- | :--- | :--- | :--- |
| **REC-001** | Circular Dependency Blockade | **CLOSED** | Resolved via Principal Injection and boot sequence remediation. |
| **REC-002** | Doc-Code Baseline Mismatch | **CLOSED** | Sync complete: 60/20/20 (Equilibrium) vs CXIP-013 (Active). |
| **REC-003** | Simulation Gap | **OPEN** | Clarity 4 keywords cause unresolved function errors in current simnet toolchains without shim. |
| **REC-004** | Foundation Race Condition | **CLOSED** | Resolved via singleton/Proxy pattern in `setup-test-env.ts`. |

## 13. Benchmarks (Verified)

| Module | Function | Gas Cost (Execution) | Latency (Sim) |
| :--- | :--- | :--- | :--- |
| Core | `set-paused` | < 10,000 | < 10ms |
| Treasury | `run-fiscal-strategy` | ~25,000 | < 25ms |
| Treasury | `distribute-token` | ~35,000 | < 30ms |

---
*End of Document (Archived Feb 2026)*
