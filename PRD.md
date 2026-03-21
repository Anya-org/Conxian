# Conxian Finance: Product Requirements Document (PRD)

## 1. Executive Summary

Conxian Finance is a multi-dimensional, Stacks-native automated monetary platform. It operates as a **Sovereign Autonomous Business (SAB)** where traditional corporate roles are replaced by autonomous agents and smart contracts. Anchored by Bitcoin security via the Nakamoto upgrade, Conxian provides a neutral, transparent, and highly efficient financial utility for the Stacks ecosystem. In 2026, Conxian evolves into a foundational liquidity engine via the **Common Settlement Framework (CSF)**.

## 2. Core Functional Modules

### 2.1. Core Ecosystem (Root)
- **Central Registry**: Unified module registration and protocol-wide pause control.
- **Access Control**: Role-based access (RBAC) supporting institutional and retail tiers.
- **Heartbeat Engine**: Automated coordination of protocol state updates and incentive distribution.
- **Enhanced Circuit Breaker**: Multi-tier isolation for native and CSF-compliant external protocols to prevent cross-protocol contagion.

### 2.2. Dimensional Trading & Liquidity
- **Leveraged Positions**: Support for multi-dimensional leveraged trading with isolated and cross-margin collateral.
- **Concentrated Liquidity**: High-efficiency DEX engine with tick-based liquidity management.
- **Apex Universal Router**: Dynamic dispatch router that natively integrates with any CSF-compliant liquidity source.

### 2.3. Autonomous Agents (Office Workers)
- **Risk Agent (AYE)**: Predictive risk assessment using PID controllers to adjust stability fees and liquidation thresholds.
- **Treasury Agent**: Automated revenue routing via the Apex BME (Burn-Mint Equilibrium) Engine.

### 2.4. Governance & Sovereignty
- **Dual-Council DAO**: Separation of strategic (Human) and operational (Agent) decision-making.
- **Sovereign Handoff**: Protocol for trustless transfer of administrative power.

## 3. Implementation Status (Updated March 2026)

### 3.1. Clarity 4 & Nakamoto Standard
- **Status**: COMPLETED (v1.2.0 Core Engines).
- **Details**: All core contracts migrated to Clarity 4 keywords.

### 3.2. Root-to-Leaf Integrity Refactor
- **Status**: COMPLETED.
- **Details**: Resolved circular dependencies using Principal Injection.

### 3.3. Apex BME Engine (Burn-Mint Equilibrium)
- **Status**: ACTIVE.
- **Details**: Replaces legacy Fiscal Dam with strictly on-chain algorithmic issuance (1B CXD Cap) and 100% fee-to-buyback mechanism.

### 3.4. Conxian CSF (Common Settlement Framework)
- **Status**: ACTIVE (v1.1.0).
- **Details**: Standardized Clarity trait (`trait-csf-liquidity-v1`) established for trustless inter-protocol routing, flash liquidity, and automated yield distribution.

## 4. Technical Specifications
- **Temporal Alignment**: High-precision yield using `stacks-block-time`.
- **CSF Interface**: Flash liquidity provisioning, arbitrage settlement, and cross-protocol reward forwarding.
- **Security**: "Isolation Mode" for external protocols via the Enhanced Circuit Breaker.

## 6. The 2026 Stacks Target Landscape & CSF Integration

To position Conxian as the central liquidity gravitational hub, the CSF natively integrates with dominant ecosystem players:

- **Stacking DAO (Liquid Staking)**: Conxian treats stSTX and stSTXbtc (native sBTC yield) as premium Tier-1 collateral within vaults and bond factories.
- **Zest Protocol (Lending)**: Conxian provides a guaranteed, circuit-breaker-protected liquidation sink for Zest’s sBTC loans via the CSF.
- **Arkadiko 2.0 (Stablecoin/Vaults)**: Conxian utilizes USDA as the base routing asset for risk-off swaps, embedding Arkadiko’s vault mechanics into the Conxius Wallet.
- **ALEX & Bitflow (AMMs / Routing)**: Conxian’s Universal Router feeds directly into their aggregators, capturing volume whenever CSF offers optimal price paths.
- **Velar (Perpetual DEX)**: Conxian programmatically supplies deep, instant liquidity to Velar’s advanced traders through CSF automated provisioning.

## 12. Recovery Registry (Failure Points)

| Issue ID | Title | Status | Details |
| :--- | :--- | :--- | :--- |
| **REC-001** | Circular Dependency Blockade | **CLOSED** | Resolved via Principal Injection. |
| **REC-002** | Doc-Code Baseline Mismatch | **CLOSED** | Sync complete: Apex BME Engine integrated. |
| **REC-003** | Simulation Gap | **CLOSED** | Clarity 4 keywords successfully shimmed for @stacks/clarinet-sdk v3.14.0. |
| **REC-004** | Foundation Race Condition | **CLOSED** | Resolved via singleton/Proxy pattern in `setup-test-env.ts`. |
| **REC-005** | Federated Oracle Implementation | **CLOSED** | Weighted aggregation engine and stale price enforcement implemented in `federated-oracle-adapter.clar`. |

## 13. Benchmarks (Verified)

| Module | Function | Gas Cost (Execution) | Latency (Sim) |
| :--- | :--- | :--- | :--- |
| Core | `set-paused` | < 10,000 | < 10ms |
| DEX | `csf-swap` | ~45,000 | < 40ms |
| Treasury | `run-fiscal-strategy` | ~30,000 | < 25ms |

---
*End of Document (Archived March 2026)*

## 14. Mainnet Release Notes (March 2026)

### 14.1. ALEX Lab CSF Integration
- **Status**: COMPLETED.
- **Details**: Full support for trustless routing through ALEX Lab liquidity pools via the `alex-adapter`. Universal Router can now natively settle trades through ALEX mainnet contracts.
- **Verification**: Verified in simulation with 100% test coverage.

### 14.2. Federated Oracle Implementation
- **Status**: COMPLETED.
- **Details**: Remedial implementation of the `federated-oracle-adapter` with weighted price aggregation and stale price protection.
- **Verification**: 100% coverage via `tests/oracle-adapter.test.ts` in simulation.
