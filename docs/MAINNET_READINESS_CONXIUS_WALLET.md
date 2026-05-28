# Mainnet Readiness Checklist — conxius-wallet (CON-141)

## Status: READY FOR MAINNET (v1.6.0)

This checklist tracks the mainnet readiness for the `conxius-wallet` repository.

### 1) Security & Custody
- [x] **Sovereign Boundary**: Key custody and signing restricted to TEE/StrongBox.
- [x] **ZSE Compliance**: No secret leakage in native or TypeScript modules.
- [x] **Attestation**: `PlayIntegrityPlugin` integrated for device verification.

### 2) Protocol Integrations
- [x] **Stacks/sBTC**: Mainnet bridge logic verified.
- [x] **Bitcoin L1**: `BdkManager` verified for mainnet transactions.
- [x] **Boundary APIs**: Consumption of Gateway/Nexus APIs standardized.
- [x] **Intent Translation**: CXN Guardian Intent Translator implemented for TEE approval.
- [x] **Sovereign Handshake Workflow (Wallet)**: Hardware-verified intent verification UI created.

### 3) Release Maturity
- [x] **Versioning**: SemVer + Android versionCode (`v1.6.0`).
- [x] **Changelog**: Standardized with `## [Unreleased]` section.
- [x] **README**: Standardized with Purpose, Status, Ownership, and Releases.

### 4) Governance & Ownership
- [x] **CODEOWNERS**: Set to `@botshelomokoka @admin-conxian-labs`.
- [x] **Artifact Hygiene**: Tracked artifacts (logs, node_modules) removed.
- [x] **License**: Standardized GPL-3.0 added.

### 5) Lifecycle Control Gates
- [x] **Wallet Lifecycle Checklist**: Verify/Release/Operate evidence is tracked in [`docs/WALLET_LIFECYCLE_CONTROL_CHECKLIST.md`](./WALLET_LIFECYCLE_CONTROL_CHECKLIST.md) for `VER-1`, `VER-2`, `REL-1`, `REL-2`, `OPS-1`, and `OPS-2`.

---
© 2026 Conxian-Labs (Pty) Ltd.
