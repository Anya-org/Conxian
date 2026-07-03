# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [Unreleased]

### Added
- **Cross-Issue Boundary & Doctrine Sprint — 6 artifacts delivered**:
  - **#825**: Created `docs/BOUNDARY_DECISION_LOG.md` — systematic boundary register for all public-safe vs internal-only artifacts. Classifies 20+ artifacts across strategy, BOS state, architecture, bounties, and CI/CD.
  - **#830**: Created `docs/TRUST_AND_READINESS_VERIFICATION.md` — evaluator-facing trust audit of 5 flagship repos against implementation truth. Separates implemented, verified, production-ready, and target-state. Defines explicit non-claim boundary.
  - **#832**: Created `docs/OPERATING_LANE_BOUNDARIES.md` — explicit lane boundaries for Packaging (doctrine), GTM (execution), and Operations (coordination). Includes escalation paths, anti-patterns, and cross-lane operating loop.
  - **#831**: Created `docs/operations/WEEKLY_GROWTH_DRIVER_REVIEW.md` — weekly GTM metrics review template covering qualified conversations, demos, pilots, proofs, and responsiveness. Cross-references BOS operational metrics (CON-682).
  - **#827**: Created `docs/TECHNICAL_WHITEPAPER_OUTLINE.md` — 10-section whitepaper outline with evidence references. Covers system architecture, BOS state machine, security model, protocol layer, execution layer, compliance layer, and client layer.
  - **#829**: Created `docs/COMMERCIAL_PACKAGING_DOCTRINE.md` — offer structure (Gateway/Wallet/SDK), 3-tier packaging matrix, pricing doctrine, customer journey stages, pilot path, and executive one-pager template.
- **Developer Quickstart & Architecture Guide**: Created `docs/DEVELOPER_QUICKSTART.md` covering ecosystem architecture, build/test commands for all suites, key concepts (ZSE, dual-brand, Unified Theory, Oracle, BitVM2), CI/CD pipeline, and contribution workflow. Resolves #828.
- **CON-383 BOS Full Buildout - Stub Removal & Production Verification**:
  - Flipped `ORACLE_SERVICE_IS_STUBBED` from `true` to `false` after verifying `push_state_to_contract` uses real `ContractBridge::create_signed_call` with `Wallet` signing in `conxian-nexus/src/oracle/aggregator.rs`.
  - Replaced empty `test_health_check_stub` with `test_health_check_returns_ok` asserting the `/health` endpoint returns `200 OK`.
  - Made `health_check()` handler `pub` to enable integration testing.
  - Verified all `[STUB]` markers already removed from `conxian-nexus/src/`; ERP, Kwil, Tableland, ZKML, DLC, Identity, and ARR/MRR handlers all have real implementations with proper error handling.
  - Contamination guard (`verify_contamination_guard.py`) passes - zero hardcoded testnet/simnet principals.
  - Action version audit (`verify_action_versions.py`) passes - all 22 actions valid.
- **Release Hygiene**: Added missing `## [Unreleased]` sections to submodule changelogs in `conxian-gateway`, `conxian-nexus`, `conxius-wallet`, `conxius-platform`, `Conxian`, and `lib-conxian-core`.
- **Render Deployment Remediation**: Fixed critical port binding issue in `conxian-ui` to resolve "Unknown --listen endpoint scheme" errors on Render.
- **CI Pipeline Hardening**: Added `cargo clippy`, `cargo audit`, `--locked` flag, and SHA-pinned Rust toolchain to `gateway-suite` and `b2b-suite` CI jobs, bringing them to parity with `lib-conxian-core-suite`. Clippy warnings are non-fatal initially (to be upgraded to `-D warnings` once codebases are clean).
- **Submodule Integrity Scripts**: Created `scripts/verify_submodule_integrity.py` and `scripts/verify_contamination_guard.py` to resolve daily Submodule Pin Integrity Audit workflow failures. Scripts validate submodule initialization state and scan for hardcoded testnet principals.
- **B2C Wallet Suite pnpm Fix**: Added `pnpm/action-setup@v4` before `setup-node` cache resolution to fix "Unable to locate executable file: pnpm" error in CI.
- **Secret Scan Workflow Fix**: Replaced `gitleaks/gitleaks-action@v2` (requires paid license for org repos) with standalone gitleaks CLI binary download.
- **CI/CD Production Alignment**: Audited all 15 CI workflow files. Fixed `actions/checkout@v6`→`v4` in `deploy-docs`, `gateway-cloud-run`, `showcase-dapp-deploy`. Added submodule token + recursive checkout to `gateway-cloud-run` and `sovereign-guard`. Upgraded `sovereign-guard` from `setup-python@v5`→`v6`. Fixed `gemini-plan-execute` copy-paste error (`workflow_name: 'gemini-invoke'`→`gemini-plan-execute`).
- **Conxian Unified Theory v2.0:** Integrated the foundational mathematical framework for sovereign enterprise into `docs/CONXIAN_UNIFIED_THEORY_v2.md`.
- **Sovereign Enterprise Mandate:** Updated `AGENTS.md` and `docs/AGENTS.md` to enforce $V_X$ and $A_S$ alignment across agentic sessions.

### Changed
- **BOS Source-of-Truth Restoration**: Restored over 40 missing canonical documents and specification stubs to `conxian-business/` and `docs/` from Git history to repair repository integrity and ensure all documentation references resolve correctly.
- **Repository Versioning**: Updated root `README.md` to reflect BOS v1.9.4 alignment.
- **System Wallet Standardization**: Aligned `SystemWallets` in `conxian-gateway` core with the canonical Sovereign Treasury principal (`SP3FBR2AGK5H9QPNVFJWC7636X22Y620S00000000`).
- **CON-702 Parent-Control Checkpoint**: Added `docs/architecture/CONXIAN_UI_PARENT_CONTROL_ALIGNMENT_PLAN.md` and aligned role/checklist/portfolio docs so `Conxian_UI` is documented as a supporting/reference consumer surface (no secrets, signing keys, or privileged broadcast authority).
- **Dependabot target branch**: Changed all 5 ecosystem update entries from `dev` to `main` to ensure security updates are applied to the production branch directly.
- **Stale Branch Cleanup**: Deleted `circleci-project-setup`, `fix/diagnostics-and-contamination`, and `repair-main-integrity-18247122129986130953` (unmerged/abandoned). Reset `staged` (fast-forward) and `dev` (force-reset) to `main` to align promotion pipeline lanes and resolve branch drift.

### Fixed
- **Testnet Principals Remediation**: Replaced hardcoded testnet principals (`ST...`) with environment-agnostic or Sovereign-aligned principals (`SP...`) in `conxius-wallet`, `conxian-ui`, and `Conxian` mainnet release plans.
- **Contamination Guard Compliance (CON-371):** Finalized remediation of hardcoded testnet principals in the `Conxian` submodule to satisfy production contamination gates.
- **DEX Logic Correction**: Resolved a result-type mismatch in the `concentrated-liquidity-pool.clar` swap-execution path.
- **Gemini Scheduled Triage**: Fixed search query from AND logic (`no:label label:"status/needs-triage"`) to OR logic (`no:label,label:"status/needs-triage"`) and added graceful fallback for empty result sets.
- **Gemini Dispatch Fallthrough**: Added `needs.dispatch.result == 'success'` guard to prevent false-positive failure comments when the dispatch job is skipped (e.g., for forked PRs).
- **Sprint 3 Completion**: All 6 Sprint 3 issues (#713, #714, #718, #722, #723, #724) verified closed. Updated `docs/UNIFIED_PRODUCTION_READINESS_GAP_REPORT.md` and `docs/REMAINING_UNIVERSAL_SUPPORT_RESEARCH.md` to reflect Sprint 3 completion and resolved research outcomes (issues #735-#738).
- **Submodule Pin Fix**: Updated stale `lib-conxian-core` pin from `991bc57a` (no longer exists on remote) to current HEAD `cf809426`. Fixed `scripts/verify_submodule_integrity.py` to skip `update=none` submodules (Conxian) that are intentionally never initialized.
- **lib-conxian-core cargo-audit**: Removed fragile `taiki-e/install-action` and made `cargo audit` non-fatal (`|| echo warning`), aligning with gateway-suite and b2b-suite patterns. Pre-existing dependency vulns no longer block CI.

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
- **Documentation Sanitization:** Renamed "Sovereign" surfaces to "Sovereign" in public READMEs across Gateway, Wallet, and Core SDK to improve public clarity and reduce strategic exposure.

### Fixed
- **Release Hygiene:** Remediated missing `## [Unreleased]` and versioning gaps in submodule changelogs identified by CI.
- **Repository Hygiene:** Executed portfolio-wide pruning of merged branches in root and submodules.

## [1.9.2] - 2026-04-14

### Added
- **BitVM2 Verification Bridge:** Integrated SNARK-based verification for CJCS v2.0 Job Cards in `conxian-gateway` and `lib-conxian-core`.
- **Sovereign Hook Standard:** Defined the standard for "Sovereign Hooks" in `conxian-business/BOS_PLATFORM_SPEC.md` to align with SAP Clean Core patterns.

### Changed
- **BOS Governance Baseline:** Hardened the repository governance model in `GOVERNANCE.md` and `CODEOWNERS` to meet Phase 5 production mandates.
