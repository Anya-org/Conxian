# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Conxian Unified Theory v2.0:** Integrated the foundational mathematical framework for sovereign enterprise into `docs/CONXIAN_UNIFIED_THEORY_v2.md`.
- **Sovereign Enterprise Mandate:** Updated `AGENTS.md` and `docs/AGENTS.md` to enforce $V_X$ and $A_S$ alignment across agentic sessions.

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

### Added
- **BitVM2 Verification Bridge:** Integrated SNARK-based verification for CJCS v2.0 Job Cards in `conxian-gateway` and `lib-conxian-core`.
- **Sovereign Hook Standard:** Defined the standard for "Sovereign Hooks" in `conxian-business/BOS_PLATFORM_SPEC.md` to align with SAP Clean Core patterns.

### Changed
- **BOS Governance Baseline:** Hardened the repository governance model in `GOVERNANCE.md` and `CODEOWNERS` to meet Phase 5 production mandates.
