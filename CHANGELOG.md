# Changelog

All notable changes to the Conxian Business Operations System (BOS) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
