# Repository catalog

This catalog is the Conxian organization-level map of what each repository is for and how it should be classified publicly.

The `conxian-business` repository vendors key Conxian repositories as Git submodules (see `.gitmodules`) and is the governance baseline for portfolio standards.

## Canonical categories (use exactly)

- `primary strategic`
- `supporting`
- `reference`
- `internal strategy`
- `governance baseline`

### Category intent

| Category | Intent | Release expectation |
| --- | --- | --- |
| `primary strategic` | Core product/infrastructure surfaces that define Conxian’s builder platform | Required: SemVer tags + maintained `CHANGELOG.md` + release notes |
| `supporting` | Shared dependencies and delivery support repos used by strategic surfaces | Strongly recommended: same changelog/tag discipline as strategic repos |
| `reference` | Public-facing examples, docs, and narrative surfaces | Narrative updates required; tags/changelogs encouraged when versioned |
| `internal strategy` | Internal strategy/planning systems not intended as public product surfaces | Keep sensitive strategy in private systems; no public over-sharing |
| `governance baseline` | Governance/specification baseline that sets standards for the portfolio | Must keep policy and classification docs current |

## Current classification map

| Repository / asset | Category | Primary audience | Notes |
| --- | --- | --- | --- |
| [Conxian](https://github.com/Conxian/Conxian) | `primary strategic` | Protocol engineers, integrators | Canonical protocol and on-chain interfaces. |
| [conxian-gateway](https://github.com/Conxian/conxian-gateway) | `primary strategic` | Integrators, institutions | Integration/middleware layer for external systems. |
| [conxian-nexus](https://github.com/Conxian/conxian-nexus) | `primary strategic` | Operators, integrators | Authoritative state and telemetry services. |
| [conxius-wallet](https://github.com/Conxian/conxius-wallet) | `primary strategic` | End users, integrators | Wallet and signing experience. |
| [lib-conxian-core](https://github.com/Conxian/lib-conxian-core) | `supporting` | App/service developers | Shared primitives and models. |
| [conxius-enclave-sdk](https://github.com/Conxian/conxius-enclave-sdk) | `supporting` | Integrators, platform engineers | Enclave/attestation SDK components. |
| [conxius-platform](https://github.com/Conxian/conxius-platform) | `supporting` | Operators, developers | Local stack orchestration and developer operations. |
| [conxius-orbit](https://github.com/Conxian/conxius-orbit) | `supporting` | Developers, operators | Deployment and operational tooling. |
| [Conxian_UI](https://github.com/Conxian/Conxian_UI) (vendored as `conxian-ui/`) | `reference` | Operators, institutions | Web interaction surface; consume strategic APIs/interfaces. |
| [conxian-labs-site](https://github.com/Conxian/conxian-labs-site) | `reference` | Public | Website and public narrative surface. |
| `Sovereign-Strategy-Nexus/` (tracked in this repo) | `internal strategy` | Leadership/strategy | Internal strategic intelligence surface. |
| [conxian-business](https://github.com/Conxian/conxian-business) | `governance baseline` | Contributors, auditors | Portfolio governance, OpenSpec, and standards. |

## README and release expectations

For all `primary strategic` and `supporting` repos, README files should include:

- `## Purpose`
- `## Status`
- `## Ownership`
- `## Releases`

Minimum release discipline for `primary strategic` repos:

- Use SemVer tags (`vX.Y.Z`).
- Keep `CHANGELOG.md` in Keep a Changelog format with `## [Unreleased]`.
- Do not merge user-facing behavior changes without a corresponding changelog entry.
