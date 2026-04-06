# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [1.9.1] - 2026-04-06

### Security
- **Hardcoded Principal Remediation (CON-61):** Replaced all instances of the hardcoded testnet admin principal ('ST1PQ...') with 'tx-sender' across 76+ Clarity contracts, enabling dynamic governance initialization.
- **Production Contamination Guard (CON-394):** Implemented a blocking CI check (`scripts/verify_contamination_guard.py`) that rejects hardcoded testnet principals, mocks, and explicit stub markers in production source trees.
- **Fail-Closed Execution Paths (CON-394):** Standardized critical stubs in `conxian-nexus` (ZKML, DLC, Identity, ERP) to return explicit service errors instead of simulated data, preventing "fail-open" scenarios during mainnet cutover.

### Changed
- **Mainnet Release Plan Alignment (CON-371):** Updated `mainnet-release-plan.yaml` to use canonical mainnet principals ('SP...').
- **Sanitized Integration Adapters:** Updated `alex-adapter.clar` and `redstone-oracle-adapter.clar` to production integration status, removing simulation placeholders.
- **Audit Verification:** Updated `contamination_audit_report_2026_04_05.md` and `mainnet_readiness_report_2026_04_05.md` to reflect REMEDIATED status.

## [1.9.0] - 2026-04-05
### Added
- Defined canonical [Branching and Promotion Policy](docs/BRANCHING_AND_PROMOTION_POLICY.md) (CON-381, CON-389) across all repositories.
- Created [Production-Path Contamination Audit Report](audit/contamination_audit_report_2026_04_05.md) (CON-394, CON-391) identifying stubs, mocks, and placeholders in core execution paths.
- Created [Mainnet Readiness Gate & System Inventory](audit/mainnet_readiness_report_2026_04_05.md) (CON-133, CON-416) mapping Neon, Supabase, and Render infrastructure.

### Changed
- Updated [BOS Business Buildout](docs/BOS_BUSINESS_BUILDOUT.md) to include the new Branching and Promotion Policy and align with the "Mainnet Readiness Gate".
- Updated [active session](audit/active_session.json) to reflect the transition from individual issue resolution to holistic system readiness.

## [1.8.2] - 2026-03-31
### Security
- Remediated Zero Secret Egress (ZSE) violation by removing the `archive/` directory from the active Git index.
- Verified knowledge retention via `scripts/verify_knowledge_retention.py` and `audit/migration_manifest.json`.

### Changed
- Cleaned up `SUMMARY.md` and `docs/README.md` to remove legacy links to missing historical artifacts.

[... Output truncated ...]
