# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project aims to follow Semantic Versioning.

## [Unreleased]

### Added

- Implementation-grade roadmap with standards adherence and acceptance criteria.
- Whitepaper and PRD documents (see README for links).

### Changed

- Documentation alignment: repository docs now reflect actual wallet lifecycle and security boundary.

### Security

- Documented security requirements and quality gates for future changes.

## [0.3.0] - 2026-01-22

### Added

- Android SecureEnclave plugin backed by Android Keystore AES-GCM.
- Optional biometric/device-credential vault gate with authenticated-key protection.
- Vault existence detection and resume logic (use existing wallet if present; otherwise onboarding).
- Offline-safe Tailwind bundling (no CDN dependency) for consistent mobile UI styling.
- Lock screen destructive reset option for creating a new wallet when needed.

### Changed

- SVN version alignment across app, docs, and release hub.
- Lightning backend alignment to LND-only support and safer endpoint handling.
- Persistence sanitization to prevent mnemonic/passphrase from being re-persisted at rest.

### Fixed

- Android Gradle namespace/manifest compatibility issues for modern AGP.
- Test environment polyfills for crypto/TextEncoder/TextDecoder so vault tests run consistently.

### Security

- Session-only seed usage for signing; seed bytes are zeroed after signing operations.
- Reduced risk of accidental secret persistence via state sanitization.
