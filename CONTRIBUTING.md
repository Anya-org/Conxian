# Contributing to Conxian

Thank you for your interest in contributing to the Conxian Protocol!

## How to Contribute

1. **Reporting Bugs**: Use the GitHub Issue Tracker to report bugs. Please provide as much detail as possible.
2. **Feature Requests**: We welcome ideas for new features! Please open an issue to discuss your proposal.
3. **Pull Requests**:
   - Fork the repository and create a new branch for your changes.
   - Ensure your code follows the established style and standards (Clarity 4, Diátaxis documentation).
   - Include tests for any new logic or bug fixes.
   - **Continuous Integration**: Your PR must pass all CI checks (Clarity validation, Vitest suite, Coverage, and Security scans).
   - **Pre-commit Checks**: Run `npm run clarinet:check` and `npm run ci` locally before submitting.

## Release Process

- **Tagging**: Releases are driven by Git tags following SemVer (e.g., `v0.6.1`).
- **Provenance**: We use GitHub Actions to generate build artifacts and provenance records for official releases.
- **Changelog**: Every release should be accompanied by a comprehensive changelog update.

## Code of Conduct

Please be respectful and professional in all interactions within the community.

## Development Setup

1. Install Node.js (v20+).
2. Install dependencies: `npm install`.
3. Run tests: `npm test` or `npm run ci`.
4. Use `clarinet check` for contract validation.

## Repository Merge Policy

`.github/CODEOWNERS` is the repository's only authoritative ownership file.

Pull requests that change contracts or GitHub Actions workflows must have:

- At least one approving review and an approval from a matching code owner.
- A successful `protocol-merge-gate` check.
- All review threads resolved before merge.
- Every GitHub Action pinned to an immutable 40-character commit SHA; floating tags are not allowed.

Repository administrators must verify the effective ruleset and any legacy branch protection without assuming repository files enabled those settings:

- Confirm the default branch requires at least one approval for contract and workflow changes.
- Confirm code-owner approval and resolved review threads are required.
- Confirm `protocol-merge-gate` is a required status check.
- Confirm no legacy branch-protection setting conflicts with or weakens the active ruleset.
- Record the verification evidence in [issue #515](https://github.com/Conxian/Conxian/issues/515).
