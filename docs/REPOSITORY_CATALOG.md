# Repository catalog

This catalog is the Conxian organization-level map of _what each repository is for_ and _how it should be presented publicly_.

The `conxian-business` repository is an umbrella repo that vendors key Conxian repositories as Git submodules (see `.gitmodules`).

## Categories

- **Platform**: orchestration stacks and operator-facing service surfaces (local dev, admin portals).
- **Wallet**: end-user, non-custodial wallet applications.
- **Gateway**: institutional middleware and API surfaces.
- **UI**: web frontends (distinct from the broader Platform stack).
- **Website**: marketing, docs, and landing pages.
- **Shared core**: libraries intended to be depended on by other repos.
- **Protocol**: smart contracts and protocol logic.
- **State node**: long-running nodes that maintain Conxian/BOS state and participate in protocol operations.
- **Specs**: `OpenSpec` and other public technical specification corpora.
- **Internal (Ops/Admin)**: governance, audits, and internal orchestration.
- **Tooling**: CLI tools and supporting utilities used for deployment, monitoring, or developer workflows.

## Quick map (by function)

- **Wallet**: `conxius-wallet`
- **Gateway**: `conxian-gateway`
- **Platform**: `conxius-platform`
- **UI**: `Conxian_UI` (planned rename to `conxian-ui`)
- **Shared core**: `lib-conxian-core`, `lib-conclave-sdk`
- **Protocol**: `Conxian`
- **State node**: `conxian-nexus`
- **Tooling**: `stacksorbit`
- **Website**: `conxian-labs-site`
- **Internal (Ops/Admin)**: `conxian-business`

## Recommended pins (GitHub org profile)

If we can only pin a few repos on the GitHub org profile, these are the clearest entry points:

1. `conxius-wallet` (Wallet)
2. `conxian-gateway` (Gateway)
3. `Conxian_UI` (UI) or `conxius-platform` (Platform)
4. `Conxian` (Protocol)
5. `lib-conxian-core` (Shared core)
6. `conxian-labs-site` (Website)

## Repositories (as vendored submodules)

| Category | Repository | Primary audience | Notes |
| --- | --- | --- | --- |
| Gateway | [conxian-gateway](https://github.com/Conxian/conxian-gateway) | Integrators, institutions | Rust gateway services and API surface. |
| Wallet | [conxius-wallet](https://github.com/Conxian/conxius-wallet) | End users | Non-custodial wallet product. |
| Platform | [conxius-platform](https://github.com/Conxian/conxius-platform) | Operators, institutions | Platform services (admin dashboards, etc.). |
| UI | [Conxian_UI](https://github.com/Conxian/Conxian_UI) | Operators, institutions | UI app(s) and specs. |
| Protocol | [Conxian](https://github.com/Conxian/Conxian) | Protocol engineers | Contracts + protocol logic. |
| State node | [conxian-nexus](https://github.com/Conxian/conxian-nexus) | Operators | Nexus state node implementation. |
| Shared core | [lib-conxian-core](https://github.com/Conxian/lib-conxian-core) | App / service developers | Shared core library. |
| Shared core | [lib-conclave-sdk](https://github.com/Conxian/lib-conclave-sdk) | Integrators | Conclave/TEE-related SDK components. |
| Website | [conxian-labs-site](https://github.com/Conxian/conxian-labs-site) | Public | Marketing + public docs site. |
| Tooling | [stacksorbit](https://github.com/Conxian/stacksorbit) | Developers | Stacks deployment and monitoring CLI/tooling. |

## Public README expectations (per repository)

For all user-facing repos (Wallet, Gateway, Platform, UI, Website, Shared core), the README should include:

- `## Purpose`: a 2–5 line description of the repository’s job.
- `## Status`: one of `active`, `alpha`, `beta`, `stable`, `maintenance`, `archived`, plus a short “what’s safe to use”.
- `## Ownership`: pointer to CODEOWNERS/maintainers.
- `## Releases`: how versions/tags are produced and where to find release notes.

## Release discipline (minimum bar)

- Use SemVer tags: `vX.Y.Z`.
- Keep `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format with a top-level `## [Unreleased]` section.
- For user-facing behavior changes, do not merge without an entry in `CHANGELOG.md`.
