# stacksorbit — BOS business buildout (CON-155)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `stacksorbit`.

## 1) Business-unit role (DevOps Tooling)

Per the repo portfolio, `stacksorbit` is a **tooling** repo:

- **Portfolio classification**: `Tooling — Stacks deployment and monitoring CLI/tooling.`
- **Business Purpose (External)**: Provide developers and operators with reliable, sovereign tools for deploying and monitoring Stacks smart contracts and network health.
- **Business Purpose (Internal)**: Standardize the deployment pipeline for Conxian protocol assets, ensuring high-fidelity verification and auditability of on-chain state changes.

## 2) Workflow Governance and Approval Paths

- **Tooling Integrity**: Changes to core deployment logic or verifier rules must be tested against simnet and testnet before promotion.
- **Approval Model**: PRs require review from the DevOps/Tooling maintainers.
- **Release Support**: Support for new contract versions or network upgrades must be prioritized to unblock downstream deployments.

## 3) Separating Technical Support from Business Operations

- **Technical Support**: CLI documentation, bug reports, and feature requests related to deployment mechanics (Git).
- **Business Operations**: Management of deployment keys (ZSE), vendor accounts for RPC providers, and strategic rollout timelines (Linear/Vault).

## 4) Business Logic and Documentation Gaps

- **Gap**: Missing "Mainnet Deployment Runbook" for automated high-value contract rollouts.
- **Gap**: Lack of explicit "Audit Log" standard for recorded deployment events.

## 5) Prioritized Build/Repair List

**P0 (Deployment Safety)**
- Remediate testnet principal contamination in deployment plans (CON-371).
- Fix failing submodule integrity checks.

**P1 (Tooling Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Implement automated "Sentinel" checks for production-bound deployments.

**P2 (Documentation Alignment)**
- Migrate sensitive infrastructure credentials to Linear.
- Standardize `CHANGELOG.md` with `## [Unreleased]` section.
