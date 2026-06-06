# Private repo check workflow

This document is the canonical lightweight workflow for checking a private repository before wider exposure, release promotion, or portfolio indexing.

## Check domains

Review the repository across these domains:

1. **Boundary and visibility**
   - Confirm the repository visibility matches its content and description.
   - Remove or stub internal-only strategy, legal, operational, security, and financial material.
   - Keep only public-safe content in git when the repository may be exposed outside the sovereign coordination layer.

2. **Secrets and sensitive material**
   - Remove `.env` files, secret inventories, credentials, tokens, and infrastructure identifiers from version control.
   - Rotate anything that may already have been exposed.
   - Prefer pointer stubs when link continuity is needed.

3. **Repo hygiene**
   - Exclude generated artifacts, vendored dependencies, caches, logs, and test reports from the Git index.
   - Keep `.gitignore` rules current.
   - Store runtime/build evidence in CI artifacts rather than committed files.

4. **Governance baseline**
   - Ensure the repository has a clear README, `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, and `CODEOWNERS` where applicable.
   - Keep role/purpose/status language aligned with the portfolio map.

5. **Release maturity**
   - Ensure branch/promotion rules are documented.
   - Use changelogs, tagged releases, and required checks for user-facing repos.

## Companion references

- [`REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md`](./REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md)
- [`PUBLIC_VISIBILITY_AUDIT_REPORT.md`](./PUBLIC_VISIBILITY_AUDIT_REPORT.md)
- [`GOVERNANCE_FILES_STANDARDIZATION.md`](./GOVERNANCE_FILES_STANDARDIZATION.md)
- [`RELEASE_NOTES_AND_CHANGELOG.md`](./RELEASE_NOTES_AND_CHANGELOG.md)
- [`BRANCH_AND_PROMOTION_STANDARD.md`](./BRANCH_AND_PROMOTION_STANDARD.md)
- [`PROMOTION_CHECKLISTS.md`](./PROMOTION_CHECKLISTS.md)

## Outcome

A repository passes this workflow when its visibility, contents, hygiene, governance files, and release controls are all consistent with the public/private boundary defined for the Conxian portfolio.
