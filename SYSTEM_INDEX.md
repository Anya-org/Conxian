# Conxian Protocol System Index (February 2026)

This document provides a comprehensive index of the Conxian Protocol, outlining its modules, contracts, and interworkings.

## 1. Core Architecture (Root-to-Leaf Model)

The protocol is designed as a modular system with a central registry and specialized decision-making hubs.

### Monitoring & Analytics

- **`monitoring-dashboard.clar`**: Real-time health monitoring, reporting system status (HEALTHY, DEFENSIVE, CRISIS) integrated with live financial telemetry.
- **`finance-metrics.clar`**: Unified financial reporting, calculating protocol-wide TVL with cross-token decimal normalization (STX/CXD).
- **`price-stability-monitor.clar`**: Tracks CXD peg stability and PID controller health.

### Central Registry & Auth

- **`conxian-protocol.clar`**: The source of truth for all active modules. Maintains a map of module names to contract principals.
- **`admin-facade.clar`**: Centralized RBAC facade; delegates to `conxian-access.clar`.

## 2. Decision Logic Hubs (Mid-Layer)

### Risk & Decision Logic

- **`risk-manager.clar`**: **Centralized Risk Decision Hub**. Tracks position health factors and governs liquidation eligibility based on system-wide risk scores.
- **`agent-risk.clar`**: Cybernetic Perception Agent. Calculates PID stability fees and system risk scores.

### Fiscal & Treasury Strategy

- **`agent-treasury.clar`**: Orchestrates the "Fiscal Dam V4". Calculates performance-adjusted revenue shares.
- **`cxd-treasury.clar`**: Stores the dynamic revenue split policy (CXIP-013).

## 3. Executive Engines (Leaf Layer)

### Trading & Positions

- **`dimensional-core.clar`**: Executes the core logic for opening, closing, and liquidating leveraged positions. **Authorized by Risk Manager**.
- **`position-manager.clar`**: Lifecycle coordinator for positions.
- **`position-nft.clar`**: SIP-009 NFT representing an active position.

### DEX & Liquidity

- **`swap-router.clar`**: User-facing entry point for DEX operations.
- **`concentrated-liquidity-pool.clar`**: Executive engine for concentrated liquidity swaps and management.

## 4. The Heartbeat (Heart)

- **`ops-engine.clar`**: Coordinates the protocol "Dual-Clock" heartbeat.
  - **Fast Path (~1 min)**: Reflexive updates (DEX Fees).
  - **Slow Path (~10 min)**: Strategic updates (Fiscal strategy, PID).

## 5. Security & Compliance

- **`compliance-manager.clar`**: Central registry for KYC/AML compliance.
- **`compliance-hooks.clar`**: Read-only hooks for gating transactions.
- **`mev-protector.clar`**: Commitment-based front-running protection.
- **`circuit-breaker.clar`**: System-wide emergency stop mechanism.

## 6. Testing & Validation

The protocol is validated using a **Root-to-Leaf** and **Leaf-to-Root** methodology.

- **Unit Tests (Leaf)**: Individual manager and agent logic.
- **Integration Tests (Root)**: Full protocol journey and heartbeat coordination.
- **Dual-Mode Simulation**: Enabled via `block-utils.clar` to allow testing of Clarity 4 Nakamoto primitives in local simulation environments.

## 7. Ecosystem Submodules

- **`conxian-ui`**: Institutional-grade React frontend for the Conclave interface.
- **`conxian-nexus`**: Sovereign Glass Node for L1 health and service status.

---
*Updated by Chappies (Feb 21, 2026)*
*Phase 11 Status: 100% Normalized (Submodule Aligned, Principal Injection Blueprinted)*
