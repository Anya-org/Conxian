# Mainnet readiness checklist — lib-conclave-sdk (CON-171)

This checklist exists to make `lib-conclave-sdk` readiness work discoverable (and consistently named) across the BOS repo, Linear, and the GitHub portfolio.

Canonical trackers:

- Linear: https://linear.app/conxian-labs/issue/CON-171/mainnet-readiness-checklist-lib-conclave-sdk
- Portfolio tracker: https://linear.app/conxian-labs/issue/CON-139/prioritized-repo-action-list-for-mainnet-readiness

## Canonical repository identity

- GitHub repo: https://github.com/Conxian/lib-conclave-sdk
- Canonical short name (use in Linear issue titles + docs): `lib-conclave-sdk`
- This workspace vendors it as a gitlink submodule at `./lib-conclave-sdk/` (see `.gitmodules`).

## Governance + public repo standards

`lib-conclave-sdk` is a public-facing SDK and should meet the baseline expectations in:

- `docs/REPOSITORY_CATALOG.md` (README sections + release discipline)
- `docs/REPO_READINESS_GATES_BY_CONTROL_DOMAIN.md` (control-domain gate levels)

As of the submodule pin in this repo, the SDK repo contains: `README.md`, `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CODEOWNERS`, `GOVERNANCE.md`, `CHANGELOG.md`, and `RELEASING.md`.

Checklist:

- [x] README includes `## Purpose`, `## Status`, `## Ownership`, and `## Releases`.
- [x] `SECURITY.md` includes a stable reporting path (and avoids private operational detail).
- [x] `CODEOWNERS` covers high-risk surfaces (enclave interfaces, signing flows, and any rails that can materially affect custody or settlement).
- [x] Governance content is public-safe (no key custody procedures, partner terms, private endpoints, or other ZSE-restricted content).

## Release + versioning discipline

The SDK is a Rust crate (and may also ship WASM bindings). Minimum release discipline:

- [x] `Cargo.toml` crate version matches the release tag.
- [x] Tags are SemVer (`vX.Y.Z`), including `0.x.y` during beta.
- [x] `CHANGELOG.md` follows Keep a Changelog with a top-level `## [Unreleased]` section.
- [x] Each tag has a GitHub Release (or equivalent release notes artifact) that links the CI evidence.

## CI and supply-chain gates

Minimum CI gates before treating a release as mainnet-ready:

- [x] `cargo fmt --all -- --check`
- [x] `cargo clippy -- -D warnings`
- [x] `cargo test`
- [x] WASM build is reproducible and does not commit generated `pkg/` artifacts.
- [x] Dependency vulnerability scan is enforced (preferred: `cargo audit` as a CI gate).

## Workspace-level coverage (this repo)

When `conxian-business` updates the `lib-conclave-sdk` submodule pointer, `Conxian Unified CI` should execute a suite that includes `cargo test` for the SDK (see `.github/workflows/conxian-unified-ci.yml`).

## Hygiene: generated artifacts + vendored dependencies

Checklist:

- [x] No generated artifacts are committed (`target/`, `pkg/`, `node_modules/`).
- [x] No runtime secrets/config are committed (`.env.example` only).
- [x] Any vendored source or copied third-party code includes clear attribution and license compatibility.

## Related work

- Release hygiene: https://linear.app/conxian-labs/issue/CON-214/release-hygiene-lib-conclave-sdk
- Secret/artifact cleanup: https://linear.app/conxian-labs/issue/CON-215/secret-and-artifact-cleanup-lib-conclave-sdk
- Security hardening: https://linear.app/conxian-labs/issue/CON-210/security-hardening-lib-conclave-sdk
