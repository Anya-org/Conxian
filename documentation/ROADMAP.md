# Roadmap

## Overview

This roadmap outlines the development phases and status of the Conxian Protocol.
The project is currently in the **Stabilization & Alignment Phase**, with a focus
on correctness, security, governance architecture, and alignment with
regulatory-style objectives.

The phases below incorporate the agreed recommendations around:

- Governance councils and role NFTs.
- The Conxian automated operations seat ("Conxian Operations Engine").
- **Self-Healing Architecture** via the `self-healing-controller.clar`.
- **Institutional Trading Suite** (TWAP/Iceberg) for enterprise users.
- **Native Bitcoin Lending** via DLC (Discreet Log Contracts) integration.
- Metrics and monitoring for LegEx / DevEx / OpEx / CapEx / InvEx style domains.
- NFT-based position representations and service vaults.

## Phase 0: Technical Alpha & Nakamoto Alignment (Current Phase)

- **Objective**: Solidify the protocol's foundation by aligning all core components with the modular, facade-based architecture and ensuring full compliance with the upcoming Stacks Nakamoto upgrade. This phase is about building a stable, future-proof base for all subsequent development.

- **Key Activities**:
  - **Architectural Integrity & Test Environment Stabilization (In Progress)**:
    - **Dependency Graph Overhaul**: The project's dependency analysis tooling (`build_graph.py`, `align_contracts.py`) has been completely rewritten. The new system accurately parses all contract files to detect dependencies from `use-trait`, `impl-trait`, and direct `contract-call?` statements, generating a correct topological ordering for deployment and testing.
    - **Circular Dependency Resolution**: The enhanced tooling successfully identified and enabled the resolution of multiple critical circular dependencies within the contract architecture. This was a major blocker preventing the test suite from initializing and has been a significant step toward stabilizing the system.
    - **Test Suite Status**: The test environment has been stabilized to the point where it can now reliably load the entire contract suite and report specific, actionable compilation errors. While many tests are still failing, the errors are no longer due to a broken environment but to issues within the contracts themselves, which can now be addressed systematically.

  - **Nakamoto Compliance (Next)**:
    - Audit all contracts for dependencies on `block-height` for time-based logic and rescale constants to align with faster block times.
    - Transition long-term logic to `burn-block-height` where appropriate.
    - Deprecate the custom BTC bridge and integrate the official, native sBTC protocol.

  - **Architectural Alignment (Planned)**:
    - Refactor the `enterprise-api.clar` from a prototype into a true facade, delegating logic to specialized manager contracts.
    - Solidify the `proposal-engine.clar` as the central facade for governance and clearly define the interfaces for its manager contracts.

  - **Documentation Overhaul (Planned)**:
    - Complete the comprehensive documentation alignment to ensure all `README.md` files and strategic documents accurately reflect the current state and target architecture of the protocol.

## Phase 1: Feature Hardening & Security (Planned)

- **Objective**: Move the protocol from a "Technical Alpha" to a "Beta" stage by hardening all existing features, expanding security measures, and preparing for a formal audit.

- **Key Activities**:
  - **Contract Hardening**:
    - Implement a production-grade `get-health-factor` in the lending module.
    - Complete the core math for the `concentrated-liquidity-pool.clar`.
    - Harden all temporary stubs and controller hooks identified in Phase 0.
  - **Testing Infrastructure**:
    - Achieve comprehensive test coverage for all core modules, including economic and security stress tests.
  - **Security & Monitoring**:
    - Implement and test advanced security features, including MEV protection, a robust circuit breaker, and oracle failure modes.
    - Prepare detailed architecture diagrams and threat models for an external security review.

## Phase 2: Advanced Governance & Feature Completion (Planned)

- **Objective**: Finish core protocol features and complete the governance /
  operational architecture so that Conxian can operate with a clear "board and
  automated executive" model.

- **Key Activities**:

  - **Lending & Risk Module**
    - Implement a production-grade `get-health-factor` in
      `comprehensive-lending-system.clar`, aligned with the risk and
      liquidation engines.
    - Complete and integrate `liquidation-manager.clar` /
      `liquidation-engine.clar` for consistent margin checks and liquidations.
  - **DEX Module**
    - Complete `concentrated-liquidity-pool.clar` and its core math.
  - **Tokens & Emission Module**
    - Harden integration hooks in `cxd-token.clar` for
      system-controller and emission-controller usage.
    - Complete `token-system-coordinator.clar` behavior and tests for
      cross-token coordination and system health views.
    - Ensure `token-emission-controller.clar` is the canonical emission rail
      for CXD, CXVG, CXTR, and related tokens.
  - **Governance Councils & Role NFTs**
    - Implement or refine council types and roles in
      `enhanced-governance-nft.clar` to match `NAMING_STANDARDS.md`.
  - **Conxian Automated Operations Seat**
    - Design and implement `conxian-operations-engine.clar` with **deterministic on-chain policy logic**.

## Phase 3: Scenario Testing, Stress & Regulatory Formalization (Planned)

- **Objective**: Prove system robustness via end-to-end scenarios and formal
  alignment of on-chain behavior with regulatory-style objectives.

- **Key Activities**:
  - **Cross-Domain Scenario Testing**
    - Implement multi-step economic scenarios that chain DEX, lending,
      protocol fees, and insurance.
  - **Governance & Council Behavior**
    - Add tests for quorum, proposal lifecycle, and council-based permissions.
  - **Regulatory Alignment Extensions**
    - Extend `REGULATORY_ALIGNMENT.md` with mappings from
      specific contracts and tests to regulatory-style objectives.

## Phase 4: Mainnet Launch (Planned)

- **Objective**: Launch the Conxian Protocol on Stacks mainnet with a
  production-ready governance and operational model.

- **Key Activities**:
  - **Deployment**
    - Deploy all core contracts to mainnet.
  - **Governance Bootstrapping**
    - Initialize the Conxian Protocol DAO with council membership NFTs.
  - **Web Application & Tooling**
    - Launch the official web application with dashboards for users and council members.
  - **Security Audit & Bug Bounty**
    - Complete an external security audit.
    - Initiate a bug bounty program to incentivize community involvement in
      securing the protocol.
