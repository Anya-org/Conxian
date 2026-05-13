# Strategic Release and Narrative Standard

## Purpose

This document standardizes portfolio classification, release discipline, and public narrative decisions for Conxian.

## Canonical repository classification categories

Use these categories exactly across portfolio docs:

- `primary strategic`
- `supporting`
- `reference`
- `internal strategy`
- `governance baseline`

### Current classification baseline (repos in scope for issue #639)

| Repository | Category | Role |
| --- | --- | --- |
| `Conxian` | `primary strategic` | Protocol and core Bitcoin-connected interfaces. |
| `conxian-gateway` | `primary strategic` | Integration and middleware layer for builders/institutions. |
| `conxian-nexus` | `primary strategic` | Authoritative state and telemetry layer. |
| `conxius-wallet` | `primary strategic` | Native wallet and signing surface for users/builders. |
| `lib-conxian-core` | `supporting` | Shared primitives and models used across strategic repos. |
| `conxius-enclave-sdk` | `supporting` | Enclave/attestation SDK surface consumed by higher layers. |
| `conxius-platform` | `supporting` | Local stack orchestration and developer operations. |
| `conxian-labs-site` | `reference` | Public-facing narrative and documentation surface. |
| `conxian-business` | `governance baseline` | Portfolio governance, standards, and release policy source. |

## Strategic narrative standard

Conxian should be positioned as infrastructure that helps builders support Bitcoin and Bitcoin-connected layers natively.

Use this framing consistently:

- infrastructure for builders, not a generic consumer fintech suite
- native support tooling for Bitcoin mainnet and Bitcoin-connected layers
- platform-level capability interfaces for secure signing, integration quality, and reference implementations

Avoid framing Conxian primarily as:

- a direct full-service financial operator
- a generic wallet-only company
- a duplicate of upstream SDK/application layers

## Release discipline standard

### Applies to `primary strategic` repositories

- `Conxian`
- `conxian-gateway`
- `conxian-nexus`
- `conxius-wallet`

### Minimum release expectations (required)

1. **Changelog discipline**
   - Root `CHANGELOG.md` is required.
   - `## [Unreleased]` must be present and updated for user-visible behavior changes before merge.
2. **Version tagging discipline**
   - Every release must map to an immutable SemVer tag (`vX.Y.Z`).
   - Annotated tags are required unless repository policy explicitly documents an alternative.
3. **Release notes discipline**
   - GitHub Release notes (or equivalent artifact) must be generated from tagged content.
   - Notes must include impact summary, breaking-change callouts, and upgrade guidance where needed.
4. **Compatibility signaling**
   - Breaking changes require explicit migration/compatibility notes.
   - Security-sensitive changes require explicit security section entries.

### Expectations for `supporting` and `reference`

- `supporting` repos should follow the same changelog/tag model when consumed by strategic repos.
- `reference` repos should publish clear narrative updates and link to canonical strategic release artifacts when no versioned release exists.

## Public narrative update plan (concrete rollout)

1. **Repository README alignment (strategic + supporting)**
   - Update `Purpose`, `Status`, and `Releases` sections to reflect the builder-infrastructure framing.
   - Ensure each README states scope and non-scope clearly.
2. **Public surface alignment (`conxian-labs-site`)**
   - Update homepage and trust pages to foreground “Bitcoin-native builder infrastructure.”
   - Link proof artifacts (`CHANGELOG.md`, tags/releases, `SECURITY.md`, OpenSpec references).
3. **Portfolio catalog alignment (`conxian-business`)**
   - Keep classification and release standards in sync across `docs/PORTFOLIO_BUSINESS_UNIT_MAP.md`, `docs/REPOSITORY_CATALOG.md`, and `docs/RELEASE_NOTES_AND_CHANGELOG.md`.
4. **Narrative drift checks (ongoing governance)**
   - During repo metadata/README updates, reject copy that drifts back to deprecated positioning.
   - Prefer statements that explain how each repo helps builders ship Bitcoin and Bitcoin-connected integrations natively.

## Summary

The portfolio baseline is:

- one canonical five-category classification model
- strict changelog + tag discipline for `primary strategic` repos
- a concrete narrative rollout plan anchored on Conxian as builder infrastructure for Bitcoin and Bitcoin-connected layers
