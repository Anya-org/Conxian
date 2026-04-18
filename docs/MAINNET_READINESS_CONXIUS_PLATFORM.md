# Mainnet Readiness Checklist — conxius-platform (CON-142)

## Status: INCUBATING (Mainnet Ready)

This checklist tracks the mainnet readiness for the `conxius-platform` repository.

### 1) Orchestration & DevEx
- [x] **Stack Definition**: Mainnet-ready Docker Compose stacks defined.
- [x] **Service Wiring**: Proper integration between Gateway, Nexus, and UI verified.
- [x] **Env Templates**: ZSE-compliant environment templates established.

### 2) Platform Integrity
- [x] **Submodule Pinning**: All core modules pinned to mainnet-ready SHAs.
- [x] **CI Verifiers**: Submodule integrity and contamination guard passing.
- [x] **Orchestration Checks**: Local end-to-end stack validation successful.

### 3) Release & Documentation
- [x] **README**: Standardized with Purpose, Status, Ownership, and Releases.
- [x] **Changelog**: Initial CHANGELOG.md with `## [Unreleased]` section.
- [x] **Contributing**: Standardized guidelines added.

### 4) Governance & Separation
- [x] **CODEOWNERS**: Set to `@conxian/core-devs`.
- [x] **ZSE Compliance**: Sensitive deployment runbooks migrated to Linear.
- [x] **Role Separation**: Platform operations isolated from internal administrative controls.

---
© 2026 Conxian-Labs (Pty) Ltd.
