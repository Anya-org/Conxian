# Repo portfolio (flagship vs supporting)

This page defines the Conxian public repo map for external evaluation and internal consistency.

## Standard role line (GitHub description + README top section)

Use the same single **role line** in both the GitHub repo description (plain text; keep it concise—aim for ~160 chars) and the README “top section” (right below the opening paragraph). You may add a separate README-only line below it (for example, a link to this repo portfolio). The 1-line purposes should match the descriptions in the [Ecosystem repos](#ecosystem-repos) section.

- Flagship:
  - `Flagship — <1-line purpose>`
- Supporting:
  - `Supporting — <1-line purpose>`

> Maintainers: Prefer linking back to this file from flagship READMEs:
> <https://github.com/Conxian/conxian-business/blob/main/docs/REPO_PORTFOLIO.md#ecosystem-repos>
> Only copy the `## Ecosystem repos` section verbatim when you need a fully self-contained README, and keep that copy in sync whenever this section changes.

## Ecosystem repos

### Flagship

These repos are the public trust surface.

- [conxius-wallet](https://github.com/Conxian/conxius-wallet) — Sovereign wallet (Android-first, offline-first) for Bitcoin L1 and Bitcoin-adjacent layers.
- [conxian-gateway](https://github.com/Conxian/conxian-gateway) — “Fusion” gateway aggregating cross-layer state + compliance pipelines.
- [Conxian](https://github.com/Conxian/Conxian) — Core protocol + on-chain contracts.
- [Conxian_UI](https://github.com/Conxian/Conxian_UI) *(planned rename to `Conxian/conxian-ui`; see [CON-238](https://linear.app/conxian-labs/issue/CON-238/define-flagship-repos-and-external-trust-surface))* — Primary UI for interacting with the Conxian ecosystem.
- [conxian-labs-site](https://github.com/Conxian/conxian-labs-site) — Public Conxian Labs website.
- [conxius-platform](https://github.com/Conxian/conxius-platform) — Local dev stack to run the ecosystem end-to-end.

### Supporting

These repos support the flagship trust surface and are linked from flagship READMEs (not pinned).

- [lib-conxian-core](https://github.com/Conxian/lib-conxian-core) — Shared core models + conventions used across services.
- [lib-conclave-sdk](https://github.com/Conxian/lib-conclave-sdk) — Headless enclave + cryptographic state machine SDK.
- [conxian-nexus](https://github.com/Conxian/conxian-nexus) — API bridge (“Glass Node”) between layers/services.
- [stacksorbit](https://github.com/Conxian/stacksorbit) — Stacks smart-contract deployment tooling.
- [.github](https://github.com/Conxian/.github) — Org-wide defaults (community health files, templates).
- [conxian-business](https://github.com/Conxian/conxian-business) — Governance + OpenSpec + submodule wiring for the Conxian ecosystem.
