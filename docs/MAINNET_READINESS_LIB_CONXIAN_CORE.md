# Mainnet Readiness Checklist — lib-conxian-core (CON-145)

## Status: READY FOR MAINNET

This checklist tracks the mainnet readiness for the `lib-conxian-core` repository, which provides shared cryptographic and state logic across the Conxian portfolio.

### 1) Security & Cryptography
- [x] **CON-216**: Security hardening complete (dependency integrity, cryptographic safety).
- [x] **Trait Ambiguity**: Resolved `Sha256` trait ambiguity using explicit syntax.
- [x] **Randomness**: Secure entropy sources verified for key generation.

### 2) Integration & Stability
- [x] **Consolidation**: Canonical source established and referenced by dependent services (CON-67).
- [x] **Versioning**: SemVer aligned with portfolio standards.
- [x] **Tests**: Unit tests for cryptographic primitives and state-root logic passing.

### 3) Release Hygiene
- [x] **Changelog**: Standardized with `## [Unreleased]` section.
- [x] **README**: Standardized with Purpose, Status, Ownership, and Releases.
- [x] **CI/CD**: Build and release process standardized.

### 4) Ownership & Governance
- [x] **CODEOWNERS**: Set to `@botshelomokoka @admin-conxian-labs`.
- [x] **License**: Standardized GPL-3.0 added.
- [x] **ZSE Compliance**: No production secrets or testnet principals tracked.

---
© 2026 Conxian-Labs (Pty) Ltd.
