# Conxian: Sovereign Business Operations System (BOS v1.9.4)

[![Conxian Unified CI](https://github.com/Conxian/conxian-business/actions/workflows/conxian-unified-ci.yml/badge.svg)](https://github.com/Conxian/conxian-business/actions/workflows/conxian-unified-ci.yml)
[![Deploy Documentation](https://github.com/Conxian/conxian-business/actions/workflows/deploy-docs.yml/badge.svg)](https://github.com/Conxian/conxian-business/actions/workflows/deploy-docs.yml)

This repository is the programmatic **State Machine** for Conxian operations. We have evolved from a system that runs on infrastructure to a system that **is** infrastructure—living directly on Bitcoin.

Supporting — Governance + OpenSpec + submodule wiring for the Conxian ecosystem.

See the [repo portfolio](docs/REPO_PORTFOLIO.md#ecosystem-repos) for the flagship/supporting repo map and `docs/BOS_BUSINESS_BUILDOUT.md` for the business-end operating model and public/internal split.

## Purpose

Define and version Conxian's Business Operations System (BOS) as an auditable, programmatic state machine (OpenSpec, governance, and operational artifacts).

## Status

Active. This repository is private (as of April 8, 2026) and is the canonical in-repo source for BOS-level specifications and how the broader Conxian stack fits together.

This status framing is being kept aligned during the `conxius-platform` documentation transition.

Documentation here follows public-safe boundary rules; internal-only strategy and operational details remain in the sovereign coordination layer under ZSE.

Release and SemVer tagging follows the process in `RELEASING.md` (`vX.Y.Z`), with history tracked in `CHANGELOG.md`.

## Audience

- Contributors implementing Conxian's protocol, infrastructure, and tools.
- Partners and auditors who need a canonical, versioned view of OpenSpec.

## Relation to Conxian stack

The Conxian ecosystem is organized by function to ensure clarity and modularity across the Sovereign Autonomous Business (SAB) stack. See the **[BOS Runtime Ownership Map](./conxian-business/BOS_RUNTIME_OWNERSHIP_MAP.md)** for detailed responsibility boundaries.

### 1. Platform & Governance
- **[`conxian-business/`](./conxian-business)**: **BOS Operations**. Commercial, legal, and platform specifications (ZSE Stubs).
- **[`conxius-platform/`](./conxius-platform)**: **Orchestration**. Stack orchestration and local development.
- **[`conxius-orbit/`](./conxius-orbit)**: **Ops Tooling**. Deployment and operations automation.

### 2. Core Operating Suite (EXCO Agents)
- **[`conxian-nexus/`](./conxian-nexus)**: **State Node**. High-level orchestration, state roots (MMR), and decentralized storage.
- **[`conxian-gateway/`](./conxian-gateway)**: **Middleware**. x402 mandates, RPC pooling, and ZKML compliance.
- **[`Fiscal-Vault-Oracle/`](./Fiscal-Vault-Oracle)**: **Finance**. Treasury and yield management.
- **[`Nakamoto-Guardian/`](./Nakamoto-Guardian)**: **Compliance**. Policy enforcement and anti-fragility monitoring.

### 3. Protocol & SDKs
- **[`Conxian/`](./Conxian)**: **Protocol**. Conxian Finance Protocol (Clarity smart contracts).
- **[`conxius-enclave-sdk/`](./conxius-enclave-sdk)**: **Agentic SDK**. Enclave + hardware attestation primitives.
- **[`lib-conxian-core/`](./lib-conxian-core)**: **Shared Core**. Common models for BitVM2, CJCS, and Gateway engine.

### 4. User Interfaces
- **[`conxius-wallet/`](./conxius-wallet)**: **Mobile**. Sovereign hardware-grade mobile vault.
- **[`conxian-ui/`](./conxian-ui)**: **Web**. Sovereign operator dashboard.
- **[`conxian-labs-site/`](./conxian-labs-site)**: **Website**. Public ecosystem landing.

## Quick start / Next action

This repository uses Git submodules.

```bash
git clone --recurse-submodules https://github.com/Conxian/conxian-business
cd conxian-business
```

`conxius-platform/` is configured with `update = none`, so it will be skipped by default during recursive submodule updates. To opt in:

```bash
git -c submodule.conxius-platform.update=checkout submodule update --init conxius-platform
```

If you need the `conxius-platform/` nested submodules, initialize them from within that repo (for example):

```bash
cd conxius-platform
git submodule update --init services/conxian-ui
```

Next action after clone: review `docs/REPO_PORTFOLIO.md` for ecosystem context and `docs/BOS_BUSINESS_BUILDOUT.md` for public/internal boundary rules.

## Ownership

Ownership and review requirements are defined in [`CODEOWNERS`](./CODEOWNERS). `CODEOWNERS`-designated policy owners are authoritative for governance, security, and documentation-policy changes.

## Security / Governance

For general support and non-security bug reports, open a GitHub issue. For security vulnerabilities, follow the private reporting process in [`SECURITY.md`](./SECURITY.md).

This repository follows Zero Secret Egress (ZSE) boundary discipline. See [Repository visibility and public/private boundary](#repository-visibility-and-publicprivate-boundary).

## Repository visibility and public/private boundary

Treat this repository as private in hosting visibility, but public-safe for boundary purposes. Detailed strategy, legal interpretations, operational runbooks, infrastructure identifiers, and any secret inventory are maintained in the sovereign coordination layer (not in git), in compliance with our Zero Secret Egress (ZSE) mandate.

Detailed strategy and roadmap content must not be duplicated in this README; see `docs/BOS_BUSINESS_BUILDOUT.md` for the public vs internal documentation rules.

Some files are intentionally kept as stubs so existing links continue to resolve.

## BOS Architecture and Wallet Control

The Conxian Business Operations System (BOS) follows a strict **SAB-owned wallet architecture** to ensure system-controlled automation and auditable financial flows.

- **Wallet Architecture**: See [`docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md`](./docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md).
- **Handoff Protocol**: The staged migration from personal bootstrap control to SAB and DAO governance is defined in [`docs/SAB_DAO_HANDOFF_PROTOCOL.md`](./docs/SAB_DAO_HANDOFF_PROTOCOL.md).
- **Controlled Operational Mappings**: Detailed wallet remapping and signer mapping records are maintained in private governance/operations systems; public stubs are retained only for link continuity.

## Ground truth (OpenSpec)

The definitive technical specifications for the Conxian ecosystem are maintained in the `openspec/` directory. See the [Enterprise Sovereignty Baseline](./openspec/changes/remediate-enterprise-sovereignty/specs.md) for the latest architectural standards.

## Governance and security

We adhere to strict sovereignty and security standards.

For general support and non-security bug reports, open a GitHub issue. For security vulnerabilities, follow the private reporting process in `SECURITY.md`.

This repository is licensed under the GNU GPL v3.0 (see `LICENSE`).

Exception note: some Conxian public repositories use MIT (for example, `.github` and `conxius-platform`). This repository remains GPL v3.0 because it is the BOS governance and OpenSpec source of truth.

- [**CONTRIBUTING.md**](./CONTRIBUTING.md): Guidelines for contributing to the BOS.
- [**SECURITY.md**](./SECURITY.md): How to report vulnerabilities and our security posture.
- [**Trust & Proof Messaging**](./docs/TRUST_AND_PROOF_MESSAGING.md): Public-facing trust surface guidance.
- [**LICENSE**](./LICENSE): GNU GPL v3.0.
- [**CHANGELOG.md**](./CHANGELOG.md): History of BOS changes.
- [**RELEASING.md**](./RELEASING.md): Release process and changelog discipline.
- [**CODEOWNERS**](./CODEOWNERS): Repository ownership and review guidance.

## Repository catalog

See [`docs/REPOSITORY_CATALOG.md`](./docs/REPOSITORY_CATALOG.md) for the org-level submodule catalog and pinning guidance.

## Repository hygiene

To maintain a clean and sovereign workspace, we adhere to strict hygiene standards:

- **`scripts/`**: Contains active utility scripts (e.g., `check_links.py`).
- **`ARCHIVE_MIGRATION.md`**: ZSE-safe pointers to legacy material intentionally kept out of the Git index.
- **`openspec/`**: Definitive technical specifications.
- **Artifact Hygiene**: Scratch scripts and temporary fix-up files (e.g., `*_fix.py`) are excluded from the repository to maintain a clean production environment.
