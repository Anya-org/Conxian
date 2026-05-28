# Contributing to Conxian

Welcome to the Conxian ecosystem. We are building a Bitcoin-native Business Operations System (BOS).

## Scope of this repository

This repository is private (as of April 8, 2026) and is the canonical in-repo source for BOS governance artifacts and OpenSpec under public-safe documentation boundaries.

Most implementation work happens in the individual service repositories (often pinned here as submodules). If your change affects a submodule, prefer opening a PR in that submodule repository, then update the pinned commit in this repo.

## Getting Started

1.  Review the [OpenSpec](./openspec/) directory for technical specifications.
2.  Review the [**Branching and Promotion Policy**](./docs/BRANCHING_AND_PROMOTION_POLICY.md) for required branch workflows.
3.  Explore the [Nomenclature Alignment](./audit/nomenclature-alignment.md) for branding and naming standards.
4.  Check the [Sovereign-Ops-Orchestrator](./Sovereign-Ops-Orchestrator) for open bounties.

## Branching and Promotion

All contributors must adhere to the [**Branching and Promotion Policy**](./docs/BRANCHING_AND_PROMOTION_POLICY.md):
- `main`: Mainnet-only production code. No stubs, mocks, or placeholders.
- `staged`: Mainnet candidate validation and promotion to `main`.
- `dev`: Default development and testnet-oriented logic.

Feature branches should validate locally first, then land in `dev` via pull request.

## Bounty workflow

- Only **bounty** issues in `Todo` are claimable, and claimable bounty issues must be unassigned.
- Free-text "I'd like to work on this" comments and payment details in threads do not constitute a claim.
- Preferred claim path is a `/claim` comment on the synced GitHub issue (when automation is enabled). Otherwise, maintainers accept claims by assigning the issue and moving it to `Claimed`.

Reference: [`docs/bounties/BOUNTY_WORKFLOW.md`](./docs/bounties/BOUNTY_WORKFLOW.md).

## ExCo intake (Linear-first)

- For ExCo-relevant newly discovered work, create/route the item in Linear first using the [ExCo intake standard](./Sovereign-Ops-Orchestrator/LINEAR_WIRING.md).
- For protocol-adapter or emerging-rail intake, include the maturity lane fields defined in [Protocol Adapter Maturity Lanes](./docs/architecture/PROTOCOL_ADAPTER_MATURITY_LANES.md).
- If the maturity lane is missing at intake, record and proceed with the required default: `Research`.
- If work is mirrored to GitHub, include the full Linear issue URL in the issue/PR body for traceability.
- Keep sensitive strategic, financial, legal, security, and detailed operational content in Linear only (ZSE).

## Pull Request Process

1.  Ensure all code changes map to an existing Linear issue.
2.  Maintain Zero Secret Egress (ZSE) compliance.
3.  All Clarity smart contracts must pass the Vitest/Simnet test suite.
4.  Documentation must be updated to match implementation.
5.  Review the [**CODEOWNERS**](./CODEOWNERS) file to identify the appropriate reviewers for your changes.
6.  Review [`.github/RELEASE_HYGIENE.md`](./.github/RELEASE_HYGIENE.md) for required checks and label-gated CI suites.
7.  If your change affects user-facing behavior, public APIs, or the security posture, ensure it's documented in [**CHANGELOG.md**](./CHANGELOG.md) (see [docs/RELEASE_NOTES_AND_CHANGELOG.md](./docs/RELEASE_NOTES_AND_CHANGELOG.md) for format).

## Security Issues

If you believe you've found a security vulnerability, do not open a public issue or pull request.

Follow the reporting guidance in [**SECURITY.md**](./SECURITY.md).

## Releases and Versioning

This repository follows Semantic Versioning and documents notable user-facing or security-impacting changes in [**CHANGELOG.md**](./CHANGELOG.md).

If your change affects a user-facing behavior or a security posture, include a changelog entry in the appropriate version section.

For merge expectations and required checks, see [`.github/RELEASE_HYGIENE.md`](./.github/RELEASE_HYGIENE.md).

For the release procedure (tags + GitHub Releases), see [**RELEASING.md**](./RELEASING.md).

## Coding Standards

- **Rust**: Use standard `rustfmt` and `clippy`.
- **Clarity**: Use the 'cxn-' prefix for all contract components.
- **UI**: Use the centralized component library in `conxian-ui`.

## Governance

Conxian operates as a Sovereign Autonomous Business. Contributions are validated by the EXCO agent suite and must adhere to the [**LICENSE**](./LICENSE) terms.
