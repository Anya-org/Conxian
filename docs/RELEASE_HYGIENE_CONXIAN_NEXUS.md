# Release hygiene — conxian-nexus

This is the release discipline checklist for `conxian-nexus` (the Rust "Glass Node" / B2B surface).

## Release artifacts (required)

1. A version tag in the `conxian-nexus` repo (recommended: `vX.Y.Z`).
2. A root `CHANGELOG.md` entry for the same `X.Y.Z` (Keep a Changelog + SemVer).
3. GitHub Release notes (or equivalent) pointing to the tag/commit and linking CI results.

## Versioning and tagging

- The `conxian-nexus/Cargo.toml` `package.version` **MUST** match the released version.
- Prefer annotated tags: `git tag -a vX.Y.Z -m "conxian-nexus vX.Y.Z"`.
- Tags should be created in the upstream `Conxian/conxian-nexus` repository (not in this workspace repo).

## `CHANGELOG.md` practice

- Keep `## [Unreleased]` at the top and move items into a dated `## [X.Y.Z] - YYYY-MM-DD` section on release.
- Every release entry should be user-impact-focused (what changed for integrators), with links to the PR/commit when possible.
- If a release changes API surface or breaks compatibility, add an explicit `### Breaking` section.

## CI and required checks

### In this workspace (`Conxian/conxian-business`)

`Conxian Unified CI` is the merge gate for submodule bumps.

- `Repo Hygiene (ZSE & Submodules)` runs on every PR.
- `B2B Suite (Nexus & SDK)` runs on:
  - every push to `main`, and
  - internal PRs that update `conxian-nexus` or `lib-conclave-sdk` submodule pointers (or any PR labeled `b2b`).

For "release candidate" PRs that bump `conxian-nexus`, the `B2B Suite (Nexus & SDK)` check should be treated as required.

### In `Conxian/conxian-nexus`

The `Rust` workflow should pass on the release tag and on the release PR.

## Branch protection (recommended)

Enable branch protection on `main` in `Conxian/conxian-nexus` requiring:

- the `Rust` workflow check
- linearized history (optional)
- tags/releases created from protected `main`
