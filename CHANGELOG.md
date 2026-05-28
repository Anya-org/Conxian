# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [Unreleased]

### Added
- **Release Hygiene**: Added missing `## [Unreleased]` sections to submodule changelogs in `conxian-gateway`, `conxian-nexus`, `conxius-wallet`, `conxius-platform`, `Conxian`, and `lib-conxian-core`.
- **System Trait Alignment**: Added missing `bond-traits` to the Simnet deployment plan in the `Conxian` repository to stabilize protocol integration tests.

### Changed
- **Nomenclature Realignment**: Executed a system-wide realignment of public-facing documentation, replacing "Institutional" with "Sovereign" across root README, Gateway PRD, and ecosystem-wide specifications to improve public clarity and align with the sovereignty-first mandate.
- **Repository Versioning**: Updated root `README.md` to reflect BOS v1.9.4 alignment.
- **System Wallet Standardization**: Aligned `SystemWallets` in `conxian-gateway` core with the canonical Sovereign Treasury principal (`SP3FBR2AGK5H9QPNVFJWC7636X22Y620S00000000`).
- **CON-702 Parent-Control Checkpoint**: Added `docs/architecture/CONXIAN_UI_PARENT_CONTROL_ALIGNMENT_PLAN.md` and aligned role/checklist/portfolio docs so `Conxian_UI` is documented as a supporting/reference consumer surface (no secrets, signing keys, or privileged broadcast authority).

### Fixed
- **Testnet Principals Remediation**: Replaced hardcoded testnet principals (`ST...`) with environment-agnostic or Sovereign-aligned principals (`SP...`) in `conxius-wallet`, `conxian-ui`, and `Conxian` mainnet release plans.
- **Contamination Guard Compliance (CON-371):** Finalized remediation of hardcoded testnet principals in the `Conxian` submodule to satisfy production contamination gates.
- **DEX Logic Correction**: Resolved a result-type mismatch in the `concentrated-liquidity-pool.clar` swap-execution path.

### Security
- **Mock Pattern Enforcement**: Verified that `mock-integrations` features in `conxian-gateway` and `conxian-nexus` are strictly gated by `compile_error!` for release builds.
- **Testnet Contamination Guard**: Remediated residual testnet addresses in production-track files to prevent accidental mainnet contamination.

## [1.9.4] - 2026-05-03

### Added
- **BOS Knowledge Graph (Crystallization):** Finalized the canonical v1.9.3 entity and relationship map in `conxian-business/BOS_KNOWLEDGE_GRAPH.md`.
- **ZSE Transparency Custodian:** Enhanced `transparency_custodian.py` with cross-repository auditing and automated Zero Secret Egress (ZSE) compliance checks.

### Changed
- **Linear Issue Finalization:** Verified and closed core alignment issues (CON-614, CON-615, CON-619, CON-620, CON-624) to mark the end of the April 2026 Sprint.
- **Portfolio Mapping:** Updated `BOS_RUNTIME_OWNERSHIP_MAP.md` to provide a definitive guide for Sovereign BOS module responsibilities.

### Fixed
- **Audit Verification:** Remediated logic gaps in the transparency custodian to prevent accidental scanning of `.git` and `node_modules` while protecting sensitive patterns.

## [1.9.3] - 2026-04-26

### Added
- **Decentralized RPC Aggregation (Gateway):** Implemented resilient provider pooling and automatic failover for Stacks and Bitcoin RPC endpoints in `conxian-gateway`.
- **Sovereign Persistence Alignment (Nexus):** Standardized `KwilAdapter` and `TablelandAdapter` commitments with ISO-8601 timestamps and RFC3339 compatibility in `conxian-nexus`.
- **BOS Platformization (BaaP):** Updated `BOS_PLATFORM_SPEC.md` with multi-tenancy (Jurisdictional Sharding) and declarative provisioning (Akash SDL) standards derived from competitive research.

### Changed
- **System-Wide Version Alignment:** Aligned all core module versions and changelogs to v1.9.3 for unified mainnet readiness signaling.
- **Documentation Sanitization:** Renamed "Institutional" surfaces to "Sovereign" in public READMEs across Gateway, Wallet, and Core SDK to improve public clarity and reduce strategic exposure.

### Fixed
- **Release Hygiene:** Remediated missing `## [Unreleased]` and versioning gaps in submodule changelogs identified by CI.
- **Repository Hygiene:** Executed portfolio-wide pruning of merged branches in root and submodules.

## [1.9.2] - 2026-04-14
