# Portfolio repository and subrepository inventory (CON-410)

This page is the canonical inventory of the Conxian GitHub portfolio and the subrepositories governed by this umbrella repo (`conxian-business`).

It exists to keep _every active repository_ and _every governed subrepository_ inside the mainnet production standard (branching/promotion + release hygiene).

Related docs:

- [Repo trust-surface view (flagship vs supporting)](./REPO_PORTFOLIO.md)
- [Business-unit separation map (what belongs where)](./PORTFOLIO_BUSINESS_UNIT_MAP.md)
- [Branch model (dev/staged/main)](./BRANCHING_AND_PROMOTION_POLICY.md)
- [Branch and promotion standard (dev/staged/main)](./BRANCH_AND_PROMOTION_STANDARD.md)

## Legend

**Production relevance**

- **Mainnet runtime**: ships or directly affects mainnet execution.
- **Mainnet support**: dependencies/tooling required to ship or operate mainnet.
- **Non-mainnet**: dev stack, marketing site, or other non-production surfaces.

**Release criticality**

- **P0**: mainnet release blockers (must not drift from portfolio standards).
- **P1**: important supporting surfaces (should follow standards; drift is not immediately mainnet-blocking).
- **P2**: nice-to-have or informational surfaces.

## Repository inventory (GitHub org)

Scope: all repositories under the `Conxian` GitHub organization.

Branch model column references the expected taxonomy in `./BRANCH_AND_PROMOTION_STANDARD.md`.

| Repository | BU / function | Owner (CODEOWNERS) | Production relevance | Branch model (observed) | Release criticality | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `Conxian/conxian-business` | Governance (BOS + OpenSpec) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | `default=main; dev=Y; staged=Y` | P0 | Umbrella repo; pins submodules and defines portfolio hygiene guardrails. |
| `Conxian/Conxian` | CSF (Protocol) | Missing (PR open) | Mainnet runtime | `default=main; dev=Y; staged=n` | P0 | Add `staged` to complete the promotion chain. Ownership: [#373](https://github.com/Conxian/Conxian/pull/373). |
| `Conxian/conxian-nexus` | Nexus (State node) | Missing (PR open) | Mainnet runtime | `default=main; dev=n; staged=n` | P0 | Missing `dev` and `staged`. Ownership: [#42](https://github.com/Conxian/conxian-nexus/pull/42). |
| `Conxian/conxian-gateway` | Fusion (Gateway) | Missing (PR open) | Mainnet runtime | `default=main; dev=n; staged=n` | P0 | Missing `dev` and `staged`. Ownership: [#43](https://github.com/Conxian/conxian-gateway/pull/43). |
| `Conxian/conxius-wallet` | Conxius (Wallet) | Missing (PR open) | Mainnet runtime | `default=main; dev=n; staged=n` | P0 | Missing `dev` and `staged`. Ownership: [#178](https://github.com/Conxian/conxius-wallet/pull/178). |
| `Conxian/lib-conxian-core` | Shared core | `@botshelomokoka @admin-conxian-labs` | Mainnet support | `default=main; dev=n; staged=n` | P0 | Missing `dev` and `staged`. Ownership: [#42](https://github.com/Conxian/lib-conxian-core/pull/42). |
| `Conxian/lib-conclave-sdk` | Shared SDK (TEE/crypto) | `@botshelomokoka` | Mainnet support | `default=master; dev=n; staged=n` | P0 | Default branch is `master` (portfolio standard expects `main`). Missing `dev` and `staged`. Ownership: [#24](https://github.com/Conxian/lib-conclave-sdk/pull/24). |
| `Conxian/stacksorbit` | DevOps tooling (deployments) | Missing (PR open) | Mainnet support | `default=main; dev=n; staged=n` | P0 | Missing `dev` and `staged`. Ownership: [#206](https://github.com/Conxian/stacksorbit/pull/206). |
| `Conxian/Conxian_UI` | Operating function (UI) | Missing (PR open) | Non-mainnet | `default=main; dev=n; staged=n` | P1 | Planned rename to `conxian-ui` (see `./REPO_PORTFOLIO.md`). Ownership: [#88](https://github.com/Conxian/Conxian_UI/pull/88). |
| `Conxian/conxius-platform` | Operating function (Platform/DevEx) | `@conxian/core-devs` | Non-mainnet | `default=main; dev=n; staged=n` | P1 | Local stack orchestration; should not become a home for product logic. Ownership: [#452](https://github.com/Conxian/conxius-platform/pull/452). |
| `Conxian/conxian-labs-site` | Operating function (Public web) | `@botshelomokoka` | Non-mainnet | `default=main; dev=n; staged=n` | P2 | Public site; ZSE-sensitive material must remain in Linear. Ownership: [#7](https://github.com/Conxian/conxian-labs-site/pull/7). |
| `Conxian/.github` | Governance (org defaults) | `@Conxian/Admins` | Mainnet support | `default=main; dev=n; staged=n` | P0 | Centralized templates/workflows; treat as production-relevant governance surface. Ownership: [#11](https://github.com/Conxian/.github/pull/11). |
| `Conxian/.github-private` | Governance (private org ops) | Missing (no root `CODEOWNERS`) | Mainnet support | `default=main; dev=n; staged=n` | P0 | Private governance surface; add `CODEOWNERS` for explicit accountability. |

## Subrepository inventory (governed by `conxian-business`)

Scope: the pinned submodules plus the BOS-native module directories tracked in this repo.

Source-of-truth notes:

- Submodule set and BU/function mapping must remain consistent with `./PORTFOLIO_BUSINESS_UNIT_MAP.md`.
- Submodule pin metadata lives in `.gitmodules` + the committed gitlinks.
- In the table below, the `Governance owner` column reflects `conxian-business` portfolio governance, not each upstream repo's `CODEOWNERS`.

| Asset (path in this repo) | Type | BU / function | Governance owner | Production relevance | Branch model | Release criticality | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Conxian/` | Submodule | CSF (Protocol) | `@botshelomokoka @admin-conxian-labs` | Mainnet runtime | See `Conxian/Conxian` | P0 | Canonical on-chain source. |
| `conxius-wallet/` | Submodule | Conxius (Wallet) | `@botshelomokoka @admin-conxian-labs` | Mainnet runtime | See `Conxian/conxius-wallet` | P0 | Sovereign custody and signing surface. |
| `conxian-gateway/` | Submodule | Fusion (Gateway) | `@botshelomokoka @admin-conxian-labs` | Mainnet runtime | See `Conxian/conxian-gateway` | P0 | Integration + compliance surface. |
| `conxian-nexus/` | Submodule | Nexus (State node) | `@botshelomokoka @admin-conxian-labs` | Mainnet runtime | See `Conxian/conxian-nexus` | P0 | Authoritative state + telemetry surface. |
| `conxian-ui/` | Submodule | Operating function (UI) | `@botshelomokoka @admin-conxian-labs` | Non-mainnet | See `Conxian/Conxian_UI` | P1 | Vendored from `Conxian/Conxian_UI` (planned rename). |
| `conxian-labs-site/` | Submodule | Operating function (Public web) | `@botshelomokoka @admin-conxian-labs` | Non-mainnet | See `Conxian/conxian-labs-site` | P2 | Public Conxian Labs site. |
| `conxius-platform/` | Submodule | Operating function (Platform/DevEx) | `@botshelomokoka @admin-conxian-labs` | Non-mainnet | See `Conxian/conxius-platform` | P1 | Local stack orchestration. |
| `stacksorbit/` | Submodule | Operating function (DevOps tooling) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | See `Conxian/stacksorbit` | P0 | Deployment tooling supporting CSF. |
| `lib-conclave-sdk/` | Submodule | Operating function (Shared SDK) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | See `Conxian/lib-conclave-sdk` | P0 | TEE/crypto SDK surfaces for services. |
| `lib-conxian-core/` | Submodule | Operating function (Shared core) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | See `Conxian/lib-conxian-core` | P0 | Shared primitives and conventions. |
| `openspec/` | Directory | Governance (OpenSpec) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Ground-truth technical requirements. |
| `docs/` | Directory | Governance (Public docs) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Portfolio conventions + public-safe standards. |
| `scripts/` | Directory | Governance (Portfolio hygiene) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | CI enforcement and portfolio audits. |
| `.github/` | Directory | Governance (Repo operations) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | CI/CD and workflow guardrails. |
| `audit/` | Directory | Governance (Assurance) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P1 | Public-safe assurance artifacts only (ZSE). |
| `infrastructure/terraform/` | Directory | Operating function (Infra) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P1 | Shared infra definitions. |
| `admin/` | Directory | Operating function (Admin) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P1 | Must remain ZSE-compliant (no secrets in git). |
| `showcase-dapp/` | Directory | Operating function (Showcase) | `@botshelomokoka @admin-conxian-labs` | Non-mainnet | Inherits `conxian-business` | P2 | Demo surface; not a product source of truth. |
| `conxian-business/` | Directory | Operating function (Governance/BOS runtime) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Nested BOS runtime stubs + local audit generator code. |
| `Fiscal-Vault-Oracle/` | Directory | Operating function (Treasury) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Treasury automation module (EXCO suite). |
| `Nakamoto-Guardian/` | Directory | Operating function (Compliance) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Compliance/enforcement module (EXCO suite). |
| `Sovereign-Ops-Orchestrator/` | Directory | Operating function (Ops) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P0 | Work execution and orchestration module (EXCO suite). |
| `Sovereign-Strategy-Nexus/` | Directory | Operating function (Strategy) | `@botshelomokoka @admin-conxian-labs` | Non-mainnet | Inherits `conxian-business` | P1 | Keep sensitive strategy material in Linear Virtual Office. |
| `cxn-grid-oracle/` | Directory | Operating function (Grid oracle) | `@botshelomokoka @admin-conxian-labs` | Mainnet support | Inherits `conxian-business` | P1 | External oracle integration module. |

## Inventory-driven deltas (to enforce the mainnet production standard)

To keep this page single-sourced (and avoid drift between the tables above and hand-maintained lists), treat the tables as canonical and apply these criteria:

1. **Branch model gaps**: any repo row where `dev=n` or `staged=n` (unless explicitly exempt from promotion).
2. **Missing ownership**: any repo row where Owner starts with `Missing`.
3. **Default branch mismatch**: any repo row where observed `default` is not `main`.
4. **Submodule pin divergence**: any pinned submodule gitlink that diverges from the upstream default branch (enforced by `scripts/verify_submodule_integrity.py`).
