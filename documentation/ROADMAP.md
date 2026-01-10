# Conxian Protocol Roadmap

**Last Updated**: January 10, 2026

## Overview

This roadmap outlines the development phases and status of the Conxian Protocol's **Sovereign Autonomous Business (SAB) ecosystem**. The project is currently in the **SAB System Integration Phase**, with focus on autonomous agent deployment, zero-gas operations, and regulatory handoff implementation.

## Current Execution Plan: SAB System Integration (Q1 2026)

Derived from our comprehensive SAB analysis, these are the immediate technical priorities for autonomous agent deployment.

### Pillar 1: Autonomous Agent Deployment

* **Objective**: Deploy and integrate all autonomous agents with zero-gas operations.
* **Status**: In Progress
* **Action Items**:
  * [x] Agent Risk (Chief Risk Officer) - sBTC peg monitoring and circuit breakers
  * [x] Agent Treasury (Chief Financial Officer) - Automated revenue distribution
  * [x] Conxian Operations Engine - Multi-agent coordination
  * [ ] **Complete Automation Manager**: Keeper coordination and system health monitoring
  * [ ] **Zero-Gas Optimization**: Ensure all agents operate without gas costs

### Pillar 2: Regulatory Handoff Implementation

* **Objective**: Complete regulatory compliance through off-chain verification.
* **Status**: In Progress
* **Action Items**:
  * [x] Regulatory Adapter - Clean-hands compliance verification
  * [x] SIP-018 Integration - Signed message verification
  * [ ] **Jurisdiction Support**: Multi-regulatory framework compatibility
  * [ ] **Compliance Test Suite**: Regulatory scenario testing

### Pillar 3: PaaS Factory Enhancement

* **Objective**: Complete one-click SAB deployment system.
* **Status**: Pending
* **Action Items**:
  * [ ] **SAB Template System**: Standardized business deployment templates
  * [ ] **Automated Configuration**: Business setup and compliance enforcement
  * [ ] **Metadata Management**: Business registration and tracking
  * [ ] **Deployment Fees**: Gas-free SAB creation through regulatory handoff

---

## Phase 0: SAB Foundation & Nakamoto Alignment (Current Phase)

* **Objective**: Establish the foundation for sovereign autonomous businesses with full Nakamoto compatibility and zero-gas operations through regulatory handoff.

* **Key Activities**:
  * **SAB Architecture Implementation**:
    * Deploy 5-tier council structure (CXD, CXVG, CXTR, CXS, CXLP)
    * Implement autonomous agents (Risk, Treasury, Operations Engine)
    * Establish regulatory handoff mechanisms for zero-gas operations
    * Create PaaS factory for automated SAB deployment
  * **Zero-Gas Operations**:
    * Implement off-chain compliance verification
    * Deploy keeper coordination system
    * Establish automated agent communication protocols
    * Create regulatory adapter with clean-hands protocol
  * **Nakamoto Compatibility**:
    * Align all agents with Bitcoin finality
    * Implement burn-block-height for critical operations
    * Optimize for 5-second block times
    * Ensure Bitcoin-anchored validation

## Phase 1: Feature Hardening & Security (Planned)

* **Objective**: Move the protocol from a "Technical Alpha" to a "Beta" stage by hardening all existing features, expanding security measures, launching full retail mainnet and preparing for a formal audit for enterprise.

* **Key Activities**:
  * **Contract Hardening**:
    * Implement a production-grade `get-health-factor` in the lending module.
    * Complete the core math for the `concentrated-liquidity-pool.clar`.
    * Harden all temporary stubs and controller hooks identified in Phase 0.
  * **Testing Infrastructure**:
    * Achieve comprehensive test coverage for all core modules, including economic and security stress tests.
    * Harden the Vitest-based test harness for reliable execution of all test suites.
  * **Security & Monitoring**:
    * Implement and test advanced security features, including MEV protection, a robust circuit breaker, and oracle failure modes.
    * Prepare detailed architecture diagrams and threat models for an external security review.

## Phase 2: Advanced Governance & Feature Completion (Planned)

* **Objective**: Finish core protocol features and complete the governance / operational architecture so that Conxian can operate with a clear "board and automated executive" model.

* **Key Activities**:

  * **Lending & Risk Module**:
    * Implement a production-grade `get-health-factor` in `comprehensive-lending-system.clar`, aligned with the risk and liquidation engines.
    * Complete and integrate `liquidation-manager.clar` / `liquidation-engine.clar` for consistent margin checks and liquidations.
    * Extend the existing risk and liquidation tests into full cross-module scenarios that bridge lending, oracle, circuit breaker, and liquidation behavior, including enterprise-style credit lines.

  * **DEX Module**:
    * Complete `concentrated-liquidity-pool.clar` and its core math.
    * Integrate `dijkstra-pathfinder.clar` with `multi-hop-router-v3.clar` for efficient routing across pools.
    * Ensure DEX fee flows are fully routed through `protocol-fee-switch.clar`.

  * **Tokens & Emission Module**:
    * Enable and harden integration hooks in `cxd-token.clar` for system-controller and emission-controller usage, subject to Clarity constraints.
    * Complete `token-system-coordinator.clar` behavior and tests for cross-token coordination and system health views.
    * Ensure `token-emission-controller.clar` is the canonical emission rail for CXD, CXVG, CXTR, and related tokens.

  * **Governance Councils & Role NFTs**:
    * Implement or refine council types and roles in `enhanced-governance-nft.clar` to match `NAMING_STANDARDS.md`.
    * Ensure metadata for council membership NFTs uses descriptive, regulatory-friendly labels.

  * **Conxian Automated Operations Seat**:
    * Design and implement `conxian-operations-engine.clar` with deterministic on-chain policy logic.
    * Reads metrics from various coordinators and modules.
    * Casts votes via `proposal-engine.clar` as an on-chain contract principal.

  * **Guardian Network & Automation Scaffolding**:
    * Design and implement `guardian-registry.clar` for managing Guardian roles and bonding in CXD.
    * Wire `keeper-coordinator.clar` and automation targets to enforce Guardian checks via a shared `automation-trait`.

  * **Position NFTs & DAO Role NFTs**:
    * Design NFT schemas and traits for LP positions, lending positions, and DAO roles.

  * **Service Vaults & Treasury / Fee Routing**:
    * Design a "service vault" pattern for holding CXD/CXTR to pay for on-chain services.

## Phase 3: Scenario Testing & Regulatory Formalization (Planned)

* **Objective**: Prove system robustness via end-to-end scenarios and formal alignment of on-chain behavior with regulatory-style objectives.

* **Key Activities**:
  * **Cross-Domain Scenario Testing**:
    * Implement multi-step economic scenarios that chain DEX, lending, protocol fees, and insurance.
    * Test oracle failures, circuit breaker activation, and incident playbooks end-to-end.
  * **Governance & Council Behavior**:
    * Add tests for quorum, proposal lifecycle, council-based permissions, and the impact of the Conxian Operations Engine seat on governance outcomes.
  * **Regulatory Alignment Extensions**:
    * Extend `REGULATORY_ALIGNMENT.md` with more concrete mappings from specific contracts and tests to regulatory-style objectives and stress scenarios.

## Phase 4: Mainnet Launch (Planned)

* **Objective**: Launch the Conxian Protocol on Stacks mainnet with a production-ready governance and operational model.

* **Key Activities**:
  * **Deployment**: Deploy all core contracts to mainnet.
  * **Governance Bootstrapping**: Initialize the DAO with council membership NFTs.
  * **Web Application & Tooling**: Launch the official web application with dashboards.
  * **Security Audit & Bug Bounty**: Complete an external security audit and initiate a bug bounty program.

## Unified Context Architecture

```mermaid
graph TD
    User[Institutional User] -->|1. KYC Check| EntAPI[Enterprise API]
    User -->|2. Swap Request| Router[Multi-Hop Router V3]
    
    subgraph "Core Execution Layer"
        Router -->|Direct| Pool[Concentrated Liquidity Pool]
        Router -->|Multi-Hop| Pool
        Pool -->|3. Compliance Hook| EntAPI
        Pool -->|4. Fee Logic| FeeSwitch[Protocol Fee Switch]
    end
    
    subgraph "Security Layer"
        MEV[MEV Protector] -.->|Optional| Router
        Oracle[Oracle Aggregator] -->|Price Feeds| Pool
    end
```
