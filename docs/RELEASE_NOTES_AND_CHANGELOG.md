# Release notes and changelog format

This document defines a repeatable release note and changelog structure for Conxian user-facing repositories.

The goal is to make public updates easy to scan, easy to verify, and hard to misinterpret.

## What goes where

- `CHANGELOG.md` is the durable, diff-friendly record of what changed.
- GitHub Releases (or an equivalent release artifact in other forges) are the narrative summary of a tagged release.

## `CHANGELOG.md` (structure)

All user-facing repositories **SHOULD** have a root `CHANGELOG.md`.

The recommended format is [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Required sections

1. `## [Unreleased]`
2. Versioned releases, newest first: `## [x.y.z] - YYYY-MM-DD`

Inside each release section, use these headings as needed:

- `### Added`
- `### Changed`
- `### Deprecated`
- `### Removed`
- `### Fixed`
- `### Security`

If a release has breaking changes, add:

- `### Breaking`

### Writing rules

- Prefer short, past-tense, user-impact bullets (example: "Fixed wallet cache key rotation on Android" instead of "Work on cache key rotation").
- Use scopes when a repo contains multiple products/packages: `- <scope>: Fixed …` (example: `- wallet: Fixed …`).
- Include references when possible:
  - Linear issue identifier (example: `CON-242`)
  - PR number and/or commit hash
- Avoid internal-only details and secrets (ZSE).

## Release notes (structure)

Release notes are for humans. They should summarize impact and provide enough provenance for readers to verify the release.

### Recommended sections

- `## Summary` (2–6 bullets)
- `## Highlights` (optional)
- `## Breaking changes` (required if any)
- `## Security` (required if any)
- `## Upgrade notes` (required if action is needed)
- `## Verification` (how to verify what shipped)
- `## Links` (changelog, PRs, issues)

### Provenance and verification

For trust, release notes **SHOULD** include at least:

- The source tag (`vX.Y.Z`) or commit SHA.
- A link to CI results (when available).
- A short list of notable checks (tests, lint, typecheck) that passed.

## Templates

Copy these into a repository and adapt as needed:

- [docs/templates/CHANGELOG_TEMPLATE.md](templates/CHANGELOG_TEMPLATE.md)
- [docs/templates/RELEASE_NOTES_TEMPLATE.md](templates/RELEASE_NOTES_TEMPLATE.md)

## Release v1.9.0 (April 2026)

This release establishes the **System Readiness & Branching Control** baseline for the Conxian mainnet cutover.

### Key Deliverables:
1. **Branching & Promotion Policy**: Explicit `main`/`staged`/`dev` model enforced to prevent testnet/stub contamination in production paths.
2. **Infrastructure Inventory**: Canonical mapping of Neon, Supabase, and Render components required for the SAB operating layer.
3. **Contamination Audit**: Comprehensive identification of functional stubs (ZKML, DLC, Settlement) and mock residue across core repositories.

### Repository Status:
- **Conxian-Business**: Updated to version v1.9.0.
- **Protocol/Gateway/Nexus**: Audit complete; remediation issues opened.
