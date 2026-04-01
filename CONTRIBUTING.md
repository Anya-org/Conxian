# Contributing to Conxian

Welcome to the Conxian ecosystem. We are building a Bitcoin-native Business Operations System (BOS).

## Getting Started

1.  Review the [OpenSpec](./openspec/) directory for technical specifications.
2.  Explore the [Nomenclature Alignment](./audit/nomenclature-alignment.md) for branding and naming standards.
3.  Check the [Sovereign-Ops-Orchestrator](./Sovereign-Ops-Orchestrator) for open bounties.

## Bounty workflow

- Only **bounty** issues in `Todo` are claimable, and claimable bounty issues must be unassigned.
- Free-text "I'd like to work on this" comments and payment details in threads do not constitute a claim.
- Preferred claim path is a `/claim` comment on the synced GitHub issue (when automation is enabled). Otherwise, maintainers accept claims by assigning the issue and moving it to `Claimed`.

Reference: [`docs/bounties/BOUNTY_WORKFLOW.md`](./docs/bounties/BOUNTY_WORKFLOW.md).

## Pull Request Process

1.  Ensure all code changes map to an existing Linear issue.
2.  Maintain Zero Secret Egress (ZSE) compliance.
3.  All Clarity smart contracts must pass the Vitest/Simnet test suite.
4.  Documentation must be updated to match implementation.
5.  Review the [**CODEOWNERS**](./CODEOWNERS) file to identify the appropriate reviewers for your changes.
6.  If your change affects user-facing behavior, public APIs, or the security posture, ensure it's documented in [**CHANGELOG.md**](./CHANGELOG.md) (see "Releases and Versioning" below).

## Security Issues

If you believe you've found a security vulnerability, do not open a public issue or pull request.

Follow the reporting guidance in [**SECURITY.md**](./SECURITY.md).

## Releases and Versioning

This repository follows Semantic Versioning and documents notable user-facing or security-impacting changes in [**CHANGELOG.md**](./CHANGELOG.md).

If your change affects a user-facing behavior or a security posture, include a changelog entry in the appropriate version section.

## Coding Standards

- **Rust**: Use standard `rustfmt` and `clippy`.
- **Clarity**: Use the 'cxn-' prefix for all contract components.
- **UI**: Use the centralized component library in `conxian-ui`.

## Governance

Conxian operates as a Sovereign Autonomous Business. Contributions are validated by the EXCO agent suite and must adhere to the [**LICENSE**](./LICENSE) terms.

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs.
