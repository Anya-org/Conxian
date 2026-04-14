# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [Unreleased]

### Added
- (None currently)

## [1.9.2] - 2026-04-14

### Added
- **Decentralized RPC Architecture (CON-463):** Implemented `StacksRpcAggregator` and `BitcoinRpcAggregator` in `conxian-gateway`. These provide provider pooling with automatic failover, tip consistency checks, and latency-aware selection to remove reliance on single centralized RPC providers.
- **Sovereign Persistence Layer (CON-69 / CON-337):** Upgraded `KwilAdapter` and `TablelandAdapter` in `conxian-nexus` from stubs to functional REST-based implementations, enabling decentralized relational state and state-root persistence.
- **Autonomous Node Orchestration:** Integrated `AutonomousOrchestrator` and Nostr telemetry collectors in Nexus for self-healing and decentralized health reporting.
- **x402 Payment-Required Middleware:** Added `x402_filter` middleware to Gateway for industrial labor trigger inspection and enforcement.

### Changed
- **System Version Alignment:** Incremented system versions across the entire portfolio (Root v1.9.2, Nexus v0.5.1, Gateway v0.1.1, Protocol v0.6.2, UI v0.1.1, Showcase v1.7.1) to ensure consistent deployment signaling.
- **Mainnet Readiness Elevation:** Verified and elevated `conxian-nexus`, `conxius-platform`, and `lib-conclave-sdk` to READY FOR MAINNET status in their respective checklists.
- **Hardened Security Boundary:** Refactored `zkml.rs` to use real Groth16 state root verification logic via `lib-conxian-core` and implemented real cryptographic signing for DLC bond announcements.

### Fixed
- **Contamination Guard Compliance:** Remediated prohibited "mock" patterns in `internal/compliance/src/zkc.rs` to satisfy strict production CI gates.
- **Root-Up Modernization:** Synchronized `stacksorbit` with latest Vitest and Clarinet SDK dependencies for stable foundation testing.

## [1.9.1] - 2026-04-06

### Security
- **Hardcoded Principal Remediation (CON-61):** Replaced all instances of the hardcoded testnet admin principal ('ST1PQ...') with 'tx-sender' across 76+ Clarity contracts, enabling dynamic governance initialization.
- **Production Contamination Guard (CON-394):** Implemented a blocking CI check (`scripts/verify_contamination_guard.py`) that rejects hardcoded testnet principals, mocks, and explicit stub markers in production source trees.
- **Fail-Closed Execution Paths (CON-394):** Standardized critical stubs in `conxian-nexus` (ZKML, DLC, Identity, ERP) to return explicit service errors instead of simulated data, preventing "fail-open" scenarios during mainnet cutover.

### Added
- Added Independent Lab Development Kit (ILDK) README (`docs/ILDK_README.md`) defining the "Morpho Blue" base-layer strategy for BOS.
- Added Strategic Growth Model (`docs/STRATEGIC_GROWTH_MODEL_2026.md`) outlining comparison with legacy/DeFi models and governance-minimized scaling rules.

[... Rest of previous content ...]
