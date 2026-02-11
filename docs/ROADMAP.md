---
layout: default
title: Protocol Roadmap
permalink: /docs/ROADMAP/
---

# Conxian Protocol Roadmap (v0.6.0)

## Phase 1: MVP (Foundation Recovery) - COMPLETED

- **Root Sovereignty**: Implementation of `conxian-protocol` registry and `conxian-access` RBAC.
- **Trait Standardization**: Consolidation of core DeFi and Governance traits in `contracts/traits/`.
- **Nakamoto Alignment**: Migration of all temporal logic to `burn-block-height` (Bitcoin-anchored height) for cross-era consistency and Bitcoin finality.
- **Clarity 4 Preparation**: Core contracts prepared for Clarity 4 (Epoch 3.1) with `stacks-block-time` and `contract-hash?` features. Currently Clarity 3 (Epoch 3.0) for mainnet compatibility.
- **Fiscal Policy**: Implementation of the 60/20/20 `revenue-distributor` and `cxd-treasury`.

## Phase 2: Alpha (Autonomous Operations) - COMPLETED (January 2026)

- **Agent Staffing**: Deployment of Agent-Risk 2.0 (`agent-risk`) and Agent-Treasury (`agent-treasury`) for autonomous protocol management.
- **Circuit Breaker**: Integration of protocol-wide safety pauses in DEX and Lending modules.
- **Adaptive Yield Engine (AYE)**: Activation of Intelligence-Led fiscal policy with PID control and Fuzzy Logic state transitions (Equilibrium, Pre-emptive, Defensive).
- **Cybernetic Logic (CXIP-012)**: Implementation of Anti-LVR dynamic fees and the **Cybernetic Fiscal Dam (V3)** for fully automated, variable revenue distribution based on real-time metrics.
- **Dual-Council Governance**: Activation of `proposal-engine` (Staff) and `community-voting-engine` (Board).
- **Reputation Integration**: Merit-based voting weight adjustment via `reputation-engine`.

## Phase 3: Institutional (Compliance & Scale) - CURRENT

- **Regulatory Hardening**: Expansion of `regulatory-adapter` to include MiCA-compliant reporting, passporting, and VASP registration. [IN PROGRESS]
- **Enterprise Vaults**: Advanced sBTC integration and institutional yield aggregation. [PLANNED]
- **Clarity 4 Production Vision**: Implementation of next-gen Stacks primitives (stacks-block-time, contract-hash?). [IN PROGRESS]
- **Multi-Council Expansion**: Activation of specialized token governance (CXS, CXTR, CXLP).
- **Security Audits**: Comprehensive cross-contract audit of the "Full Truth" codebase.

## Phase 4: Scale (Sovereign Expansion) - FUTURE

- **Cross-Chain Sovereignty**: Integration with other Bitcoin L2s (Liquid, Merlin) and non-Bitcoin ecosystems via `interoperability` module.
- **Autonomous Office Manager**: Advanced AI-orchestration for complex multi-agent workflows.
- **Retail Abstraction**: Launch of the Conxian Unified Interface (UI) with full UX abstraction of Clarity logic.
- **AGM Maturation**: First full-cycle Annual General Meeting (AGM) execution.
