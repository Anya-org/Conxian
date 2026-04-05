# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release note and changelog guidance lives in [docs/RELEASE_NOTES_AND_CHANGELOG.md](docs/RELEASE_NOTES_AND_CHANGELOG.md).

## [Unreleased]

### Added
- Documented the BOS business-end operating model (`docs/BOS_BUSINESS_BUILDOUT.md`), including ZSE public/internal split guidance and governance/README alignment.

## [1.8.2] - 2026-03-31
### Security
- Remediated Zero Secret Egress (ZSE) violation by removing the `archive/` directory from the active Git index.
- Verified knowledge retention via `scripts/verify_knowledge_retention.py` and `audit/migration_manifest.json`.

### Changed
- Cleaned up `SUMMARY.md` and `docs/README.md` to remove legacy links to missing historical artifacts.

## [1.8.1] - 2026-03-31
### Security
- Fixed CON-304: Redaction scanner statefulness in `conxius-wallet` by replacing shared global regexes with factory-generated instances.

### Fixed
- Aligned `NUBIT_API` routing between testnet (`testnet.nubit.org`) and mainnet (`nubit.org`) in `network.ts`.

### Added
- Regression test suite `tests/stateful-regex-repro.test.ts` in `conxius-wallet`.

## [1.8.0] - 2026-03-31
### Added
- SAB Datastore Mapping Specification (`openspec/specs/sab-datastore-mapping/spec.md`) translating current-state inventory into target-state datastore decisions.

## [1.7.0] - 2026-03-30
### Added
- Root-level governance files: `LICENSE`, `CHANGELOG.md`.
- Enhanced `.gitignore` to protect internal strategy material and root-level artifacts.

### Changed
- Improved root-level hygiene by removing tracked build artifacts and sensitive strategy documents from the Git index.
- Standardized repository structure across submodules.

### Fixed
- Public/private boundary violation by moving sensitive `internal/strategy/` content out of the active Git index.

> Note: Removing files from the current tree does not purge them from git history. A follow-up history rewrite is required for a full removal.

## [1.9.0] - 2026-04-05
### Added
- Defined canonical [Branching and Promotion Policy](docs/BRANCHING_AND_PROMOTION_POLICY.md) (CON-381, CON-389) across all repositories.
- Created [Production-Path Contamination Audit Report](audit/contamination_audit_report_2026_04_05.md) (CON-394, CON-391) identifying stubs, mocks, and placeholders in core execution paths.
- Created [Mainnet Readiness Gate & System Inventory](audit/mainnet_readiness_report_2026_04_05.md) (CON-133, CON-416) mapping Neon, Supabase, and Render infrastructure.

### Changed
- Updated [BOS Business Buildout](docs/BOS_BUSINESS_BUILDOUT.md) to include the new Branching and Promotion Policy and align with the "Mainnet Readiness Gate".
- Updated [active session](audit/active_session.json) to reflect the transition from individual issue resolution to holistic system readiness.
