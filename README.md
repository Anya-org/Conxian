# Conxian: Sovereign Business Operations System (BOS v1.9.0)

[![Conxian Unified CI](https://github.com/Conxian/conxian-business/actions/workflows/conxian-unified-ci.yml/badge.svg)](https://github.com/Conxian/conxian-business/actions/workflows/conxian-unified-ci.yml)
[![Deploy Documentation](https://github.com/Conxian/conxian-business/actions/workflows/deploy-docs.yml/badge.svg)](https://github.com/Conxian/conxian-business/actions/workflows/deploy-docs.yml)

This repository is the programmatic **State Machine** for Conxian operations. We have evolved from a system that runs on infrastructure to a system that **is** infrastructure—living directly on Bitcoin.

Supporting — Governance + OpenSpec + submodule wiring for the Conxian ecosystem.

See the [repo portfolio](docs/REPO_PORTFOLIO.md#ecosystem-repos) for the flagship/supporting repo map and `docs/BOS_BUSINESS_BUILDOUT.md` for the business-end operating model and public/internal split.

## Purpose

Define and version Conxian's Business Operations System (BOS) as an auditable, programmatic state machine (OpenSpec, governance, and operational artifacts).

## Status

Active. This is the public source of truth for BOS-level specifications and how the broader Conxian stack fits together.

Releases are tracked in `CHANGELOG.md` and published as SemVer tags (`vX.Y.Z`). See `RELEASING.md`.

## Ownership

Ownership and review requirements are defined in [`CODEOWNERS`](./CODEOWNERS).

## Audience

- Contributors implementing Conxian's protocol, infrastructure, and tools.
- Partners and auditors who need a canonical, versioned view of OpenSpec.

## Relationship to the Conxian stack

This repository pins and coordinates the flagship Conxian repositories, including:

- [`Conxian/`](./Conxian): Conxian Finance Protocol (Protocol; Clarity smart contracts)
- [`conxian-gateway/`](./conxian-gateway): Conxian Gateway (Gateway; Rust)
- [`conxian-nexus/`](./conxian-nexus): Conxian Nexus (State node; Rust)
- [`lib-conxian-core/`](./lib-conxian-core): Shared core libraries centered around the Gateway (Shared core; Rust)
- [`lib-conclave-sdk/`](./lib-conclave-sdk): Enclave + hardware attestation SDK (SDK)
- [`conxian-ui/`](./conxian-ui): Conxian UI (UI; web) — upstream: `Conxian_UI` *(to be renamed to `conxian-ui`)*
- [`conxius-wallet/`](./conxius-wallet): Conxius Wallet (Wallet; mobile)
- [`conxius-platform/`](./conxius-platform): Stack orchestration and local development (Platform)
- [`stacksorbit/`](./stacksorbit): Deployment and operations tooling (Tooling)
- [`conxian-labs-site/`](./conxian-labs-site): Conxian Labs public site (Website)

## Cloning

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

## Repository visibility and public/private boundary

This repository is currently private. To reduce public/private boundary risk, detailed strategy, legal interpretations, operational runbooks, infrastructure identifiers, and any secret inventory are maintained in the Conxian Linear workspace (not in git), in compliance with our Zero Secret Egress (ZSE) mandate.

See https://linear.app/conxian-labs/issue/CON-256 for ZSE background and operating requirements.

Detailed strategy and roadmap content must not be duplicated in this README; see `docs/BOS_BUSINESS_BUILDOUT.md` for the public vs internal documentation rules.

Some files are intentionally kept as stubs so existing links continue to resolve.

## BOS Architecture and Wallet Control

The Conxian Business Operations System (BOS) follows a strict **SAB-owned wallet architecture** to ensure system-controlled automation and auditable financial flows.

- **Wallet Architecture**: See [`docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md`](./docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md).
- **Handoff Protocol**: The staged migration from personal bootstrap control to SAB and DAO governance is defined in [`docs/SAB_DAO_HANDOFF_PROTOCOL.md`](./docs/SAB_DAO_HANDOFF_PROTOCOL.md).
- **Implementation Manifest**: Technical remediation of hardcoded principals and stubbed roles is tracked in [`docs/WALLET_REMAPPING_MANIFEST_CON_61_CON_423.md`](./docs/WALLET_REMAPPING_MANIFEST_CON_61_CON_423.md).

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
