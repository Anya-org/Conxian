# Conxian Finance: Product Requirements Document (PRD)

## 1. Executive Summary

Conxian Finance is a multi-dimensional, Stacks-native automated monetary platform. It operates as a **Sovereign Autonomous Business (SAB)** where traditional corporate roles are replaced by autonomous agents and smart contracts. Anchored by Bitcoin security via the Nakamoto upgrade, Conxian provides a neutral, transparent, and highly efficient financial utility for the Stacks ecosystem. In 2026, Conxian evolves into a foundational liquidity engine via the **Common Settlement Framework (CSF)**.

## 2. Core Functional Modules

### 2.1. Core Ecosystem (Root)
- **Central Registry**: Unified module registration and protocol-wide pause control.
- **Access Control**: Role-based access (RBAC) supporting institutional and retail tiers.
- **Heartbeat Engine**: Automated coordination of protocol state updates and incentive distribution.
- **Enhanced Circuit Breaker**: Multi-tier isolation for native and CSF-compliant external protocols.

### 2.2. Dimensional Trading & Liquidity
- **Leveraged Positions**: Support for multi-dimensional leveraged trading with real-time risk tracking.
- **Concentrated Liquidity**: High-efficiency DEX engine with tick-based liquidity management.
- **Apex Universal Router**: Dynamic dispatch router that natively integrates with any CSF-compliant liquidity source.

### 2.3. Autonomous Agents (Office Workers)
- **Risk Agent (AYE)**: Predictive risk assessment using real protocol telemetry and PID controllers.
- **Treasury Agent**: Automated revenue routing via the Apex BME (Burn-Mint Equilibrium) Engine.

### 2.4. Governance & Sovereignty
- **Dual-Council DAO**: Separation of strategic (Human) and operational (Agent) decision-making.
- **Sovereign Handoff**: Protocol for trustless transfer of administrative power.

## 3. Implementation Status (Updated April 2026)

### 3.1. Clarity 4 & Nakamoto Standard
- **Status**: COMPLETED (v1.2.1 Core Engines).
- **Details**: All core contracts migrated to Clarity 4 keywords and verified for tenure-awareness.

### 3.2. Revenue Automation (CON-60)
- **Status**: COMPLETED.
- **Details**: Enforced 100 bps protocol fee on all core lending and trading transactions.

### 3.3. DLC Bond Lifecycle (CON-72)
- **Status**: COMPLETED.
- **Details**: Full lifecycle management for Bitcoin-anchored debt, integrated with BitVM2 verification.

### 3.4. ERP Gateway & x402 (CON-63)
- **Status**: COMPLETED.
- **Details**: Production-grade OData v4 translation layer for SAP/Oracle and x402 payment mandates.

### 3.5. Guardian & Persistence (CON-70, 69)
- **Status**: PARTIAL; ZKML boundary QUARANTINED.
- **Details**: Tableland state synchronization is implemented, but no cryptographic ZKML verification backend exists. `zkml-verifier.clar` is fail-closed: structural proof shape or length is not verification, and it must not drive compliance, settlement, custody, routing, deployment, or mainnet-readiness decisions.

### 3.6. SIP-018 Compliance (CON-76)
- **Status**: COMPLETED (April 2026).
- **Details**: Implemented real structured data hashing and signature verification in `regulatory-adapter.clar` using the SIP-018 standard.

## 12. Recovery Registry (Failure Points)

| Issue ID | Title | Status | Details |
| :--- | :--- | :--- | :--- |
| **REC-001** | Circular Dependency Blockade | **CLOSED** | Resolved via Trait Injection. |
| **REC-002** | Doc-Code Baseline Mismatch | **CLOSED** | Sync complete: Apex BME Engine and Revenue Automation integrated. |
| **REC-003** | Simulation Gap | **CLOSED** | Resolved via shimmed keywords. |
| **REC-006** | Systemic Stub Elimination | **CLOSED** | Removed all stubs for DLC, ERP, and Telemetry (April 2026). |
| **REC-007** | Simulation Race Condition | **CLOSED** | Resolved asynchronous race condition in Simnet initialization and standardized test suite (April 2026). |
| **REC-008** | SIP-018 Compliance Logic | **CLOSED** | Implemented real domain hashing and message verification (April 2026). |
| **REC-009** | Federated Oracle Implementation | **CLOSED** | Implemented `federated-oracle-adapter.clar` with Clarity 4 standards and DAO-ready governance (April 2026). |
| **REC-010** | Multi-Asset Collateral Redesign | **CLOSED** | Redesigned `lending-manager` and `lending-orchestrator` to support asset-specific collateral parameters and health calculations (July 2026). |

## 13. Benchmarks (Verified)

| Module | Function | Gas Cost (Execution) | Latency (Sim) |
| :--- | :--- | :--- | :--- |
| Core | `set-paused` | < 10,000 | < 10ms |
| DEX | `csf-swap` | ~45,000 | < 40ms |
| Treasury | `run-fiscal-strategy` | ~30,000 | < 25ms |
| Compliance | `verify-and-update-compliance` | ~25,000 | < 20ms |
| Lending | `configure-asset-collateral` | < 15,000 | < 10ms |
