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

- **Tagging**: Releases are driven by Git tags following SemVer.
- **Provenance**: We use GitHub Actions to generate build artifacts and provenance records for official releases.
- **Changelog**: Every release should be accompanied by a comprehensive changelog update.

## Code of Conduct

Please be respectful and professional in all interactions within the community.

## Development Setup

1. Install Node.js (v20+).
2. Install dependencies: `npm install`.
3. Run tests: `npm test` or `npm run ci`.
4. Use `clarinet check` for contract validation.
