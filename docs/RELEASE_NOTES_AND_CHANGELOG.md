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

Notes:

- Front matter is allowed (for example, repos that publish the changelog via GitHub Pages), but the changelog content should still follow the section rules above.

## Tagged releases (expectation)

For user-facing repos, a version in `CHANGELOG.md` should correspond to an immutable git tag in the repo.

- Tag format: `vX.Y.Z` (SemVer).
- Prefer annotated tags: `git tag -a vX.Y.Z -m "vX.Y.Z"`.
- The GitHub Release should be created from the tag and include the release notes.

In this BOS repo, `Conxian Unified CI` runs `scripts/verify_release_hygiene.py` to:

- enforce that the root `CHANGELOG.md` has an `## [Unreleased]` section, and
- emit warnings when user-facing repos (starting with `conxius-wallet`) are missing tags.

## Bootstrapping repos with versions but no tags

Some repos may already carry version history in `CHANGELOG.md` but have not cut git tags yet. To bootstrap:

1. Pick a version already documented in `CHANGELOG.md` (example: `1.6.0`).
2. Identify the exact commit SHA that produced the shipped artifact.
3. Create and push the tag in the upstream repo:

```bash
git tag -a v1.6.0 <commit-sha> -m "v1.6.0"
git push origin v1.6.0
```

4. Create a GitHub Release from the tag and copy the matching changelog section into the release notes.

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
