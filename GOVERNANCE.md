# Governance

This repository is governed by the Conxian Sovereign Autonomous Business (SAB).

This is a public repository. Governance rules must be documented without leaking privileged operational details.

Canonical business-purpose and public/private split guidance for this repo lives in `docs/BOS_BUSINESS_BUILDOUT.md`.

## Ownership

- **Repo owners:** defined by `CODEOWNERS`.
- **Policy owners:** `CODEOWNERS` is authoritative for governance, security, and documentation-policy changes.

## Branching and Promotion

All repositories in the Conxian portfolio must adhere to the [**Branching and Promotion Policy**](./docs/BRANCHING_AND_PROMOTION_POLICY.md).

- **`main` branch**: Reserved for mainnet-only production code. No stubs, mocks, or placeholders.
- **`staged` branch**: Reserved for mainnet candidate validation and promotion to `main`.
- **`dev` branch**: Default branch for development and testnet-oriented logic.

## Approval model

All changes land via pull request and must follow the workflow defined in `docs/BOS_BUSINESS_BUILDOUT.md` (Linear issue linkage, `CODEOWNERS` review, and documentation-alignment/`CHANGELOG.md` update rules for boundary or policy changes).

## Documentation confidentiality (ZSE)

Conxian operates under a Zero Secret Egress (ZSE) mandate.

- Public-safe documentation may live in Git.
- Strategic, legal, operational, and administrative documents that are internal-only must be stored in the Linear Virtual Office and referenced from Git with a pointer.

## Policies

- Repository visibility: This repository is intended to be public. Internal-only strategy, legal interpretations, operational runbooks, infrastructure identifiers, and secret inventories must live in the Conxian Linear workspace (https://linear.app/conxian-labs). Tracking issue: https://linear.app/conxian-labs/issue/CON-256
- Contributing guidelines: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Security policy: [`SECURITY.md`](./SECURITY.md)
- BOS business buildout and repo operating model: [`docs/BOS_BUSINESS_BUILDOUT.md`](./docs/BOS_BUSINESS_BUILDOUT.md)
- Branching and promotion: [`docs/BRANCHING_AND_PROMOTION_POLICY.md`](./docs/BRANCHING_AND_PROMOTION_POLICY.md)
- License: [`LICENSE`](./LICENSE) (GNU GPL v3.0)
