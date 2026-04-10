# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [Unreleased]

### Added
- Documented the BOS business-end operating model (`docs/BOS_BUSINESS_BUILDOUT.md`), including ZSE public/internal split guidance and governance/README alignment.

### Fixed
- **Showcase DApp Hygiene:** Removed tracked `dev_server.log` artifact and updated `.gitignore` to prevent future contamination.

### Changed
- **Devcontainer (CON-383):** Added Rust stable and Python 3.10 to `.devcontainer/Dockerfile` so `cargo test` and CI scripts run locally.
- **BOS production boundary (CON-383):** Removed residual `// Simulate execution success` placeholder comment from `conxian-nexus/src/api/rest.rs`. Replaced empty `test_health_check_stub` with a real assertion.
- **ERP handler (CON-63):** Replaced mock enclave attestation UUID with a real wallet signature via `lib-conxian-core::Wallet::sign()`. Response now includes `attestation` (128-char hex) instead of a fabricated `enclave_sig_*` string.
- **Kwil adapter (CON-330):** Replaced stub hash (`kwil_tx_stub_*`) with a real HTTP POST to `KWIL_PROVIDER_URL/api/v1/broadcast`. Fails closed (returns `Err`) when the provider is unreachable or config is absent.
- **Tableland adapter (CON-69):** Replaced random hash stub with a real HTTP POST to the Tableland Validator REST API (`/api/v1/mutate`). Fails closed on HTTP error.
- **ARR/MRR metrics (CON-68):** Added durable Supabase REST upsert to `log_revenue_intelligence` alongside the existing Redis counter. Non-fatal: skipped with a warning when `SUPABASE_URL`/`SUPABASE_ANON_KEY` are absent.
- **ZKML handler (CON-70):** Replaced simulated-success stub with explicit `501 Not Implemented`. Integration path documented in `TODO(CON-70)` comment.
- **DLC handler (CON-62):** Replaced placeholder response with explicit `501 Not Implemented`. Integration path documented in `TODO(CON-62)` comment.
- **Identity handler (CON-66):** BNS names now resolved via real HTTP call to `api.bns.xyz`. ENS and WorldID return `503 Service Unavailable` until wired (`TODO(CON-66)`).
- **Oracle service (CON-394):** Renamed `OracleStub` → `OracleService` in `ppp_tracker.rs` (the implementation was already real). Flipped `ORACLE_SERVICE_IS_STUBBED` to `false` in `config.rs`.
- **Contamination guard (CON-383/CON-394):** Removed 7 file paths from `REPO_EXCLUSIONS["conxian-nexus"]` in `scripts/verify_contamination_guard.py`. `lib-conxian-core/src/lib.rs` retained (BitVM2 stub, CON-75).

### Pending (noted for future sessions)
- **Tableland (CON-69):** Full production wiring requires a Tableland table ID and a signed EVM transaction from the Nexus wallet. Current implementation sends unsigned SQL — needs wallet-signed mutation once Tableland EVM integration is confirmed.
- **ZKML (CON-70):** Requires selection and integration of a Groth16/PlonK verifier crate (`bellman` or `arkworks`) and a deployed verifying-key registry on Stacks.
- **DLC (CON-62):** Requires a DLC oracle contract address on Stacks mainnet and sBTC coupon settlement contract wiring.
- **ENS/WorldID identity (CON-66):** ENS via `api.ensideas.com`; WorldID nullifier lookup pending integration approval.
- **BitVM2 state root verification (CON-75):** `lib-conxian-core/src/lib.rs` retains one `[STUB]` for BitVM2 verification — tracked separately.

## [1.9.1] - 2026-04-06

### Security
- **Hardcoded Principal Remediation (CON-61):** Replaced all instances of the hardcoded testnet admin principal ('ST1PQ...') with 'tx-sender' across 76+ Clarity contracts, enabling dynamic governance initialization.
- **Production Contamination Guard (CON-394):** Implemented a blocking CI check (`scripts/verify_contamination_guard.py`) that rejects hardcoded testnet principals, mocks, and explicit stub markers in production source trees.
- **Fail-Closed Execution Paths (CON-394):** Standardized critical stubs in `conxian-nexus` (ZKML, DLC, Identity, ERP) to return explicit service errors instead of simulated data, preventing "fail-open" scenarios during mainnet cutover.

### Added
- Added Independent Lab Development Kit (ILDK) README (`docs/ILDK_README.md`) defining the "Morpho Blue" base-layer strategy for BOS.
- Added Strategic Growth Model (`docs/STRATEGIC_GROWTH_MODEL_2026.md`) outlining comparison with legacy/DeFi models and governance-minimized scaling rules.

Note: CJCS v2.0.1 / ILDK documentation updates landed on 2026-04-08.

### Changed
- **Mainnet Release Plan Alignment (CON-371):** Updated `mainnet-release-plan.yaml` to use canonical mainnet principals ('SP...').
- **Sanitized Integration Adapters:** Updated `alex-adapter.clar` and `redstone-oracle-adapter.clar` to production integration status, removing simulation placeholders.
- **Audit Verification:** Updated `contamination_audit_report_2026_04_05.md` and `mainnet_readiness_report_2026_04_05.md` to reflect REMEDIATED status.
- Enhanced Conxian Job Card Schema (CJCS) v2.0.1 (`docs/CJCS_v2.0_SPEC.md`) with "Industrial Intent" standard and dependency web logic.
- Upgraded BOS Business Buildout (`docs/BOS_BUSINESS_BUILDOUT.md`) to include Real Yield Flywheel, Agentic App Store, and Policy-as-Code scaling.
- Updated Documentation Hub entrypoint (`docs/README.md`) and alignment index (`docs/DOCUMENTATION_ALIGNMENT_INDEX.md`) to include new strategic artifacts.

## [1.9.0] - 2026-04-05
### Added
- Defined canonical [Branching and Promotion Policy](docs/BRANCHING_AND_PROMOTION_POLICY.md) (CON-381, CON-389) across all repositories.
- Created [Production-Path Contamination Audit Report](audit/contamination_audit_report_2026_04_05.md) (CON-394, CON-391) identifying stubs, mocks, and placeholders in core execution paths.
- Created [Mainnet Readiness Gate & System Inventory](audit/mainnet_readiness_report_2026_04_05.md) (CON-133, CON-416) mapping Neon, Supabase, and Render infrastructure.

### Changed
- Updated [BOS Business Buildout](docs/BOS_BUSINESS_BUILDOUT.md) to include the new Branching and Promotion Policy and align with the "Mainnet Readiness Gate".
- Updated [active session](audit/active_session.json) to reflect the transition from individual issue resolution to holistic system readiness.

### Changed
- gateway: **Behavior change** when `BITCOIN_RPC_URL` is unset: Gateway now defaults to the public Bitcoin mainnet RPC endpoint (`https://bitcoin-rpc.publicnode.com`). (CON-418, #354)

### Security
- gateway: **Operator action**: This default is intended only for non-production, non-funds-bearing development and low-traffic open-tier usage. Before upgrading, production, funds-bearing, or privacy-sensitive environments must set `BITCOIN_RPC_URL` explicitly (see [docs/BOS_BUSINESS_BUILDOUT.md](docs/BOS_BUSINESS_BUILDOUT.md) for environment tier definitions). Traffic to this default endpoint is handled by a third-party public RPC operator and may be logged (including IP addresses and request metadata). (CON-418, #354)

## [1.8.2] - 2026-03-31
### Security
- Remediated Zero Secret Egress (ZSE) violation by removing the `archive/` directory from the active Git index.
- Verified knowledge retention via `scripts/verify_knowledge_retention.py` and `audit/migration_manifest.json`.

### Changed
- Cleaned up `SUMMARY.md` and `docs/README.md` to remove legacy links to missing historical artifacts.

[... Output truncated ...]
