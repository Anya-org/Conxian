# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
...
