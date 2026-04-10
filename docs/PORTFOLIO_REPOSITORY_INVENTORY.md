# Portfolio repository inventory

This document provides the canonical inventory of all repositories and subrepositories in the Conxian-Labs stack.

## Taxonomy

**Layers (per CON-468)**

- **Decentralization-critical**: core protocol and state-consensus components.
- **User and application surface**: direct interaction layers for users and partners.
- **Shared runtime and developer infrastructure**: SDKs, core libraries, and orchestration tools.
- **Governance and operating system**: BOS governance, specs, and internal EXCO modules.

**Release criticality**

- **P0**: mainnet release blockers (must not drift from portfolio standards).
- **P1**: important supporting surfaces (should follow standards; drift is not immediately mainnet-blocking).
- **P2**: nice-to-have or informational surfaces.

## Repository inventory (GitHub org)

| Repository | Layer | BU / function | Owner | Criticality |
| --- | --- | --- | --- | --- |
| `Conxian/conxian-business` | Governance | Governance (BOS + OpenSpec) | @botshelomokoka | P0 |
| `Conxian/Conxian` | Decentralization | CSF (Protocol) | @botshelomokoka | P0 |
| `Conxian/conxian-nexus` | Decentralization | Nexus (State node) | @botshelomokoka | P0 |
| `Conxian/conxian-gateway` | Decentralization | Fusion (Gateway) | @botshelomokoka | P0 |
| `Conxian/conxius-wallet` | User surface | Conxius (Wallet) | @botshelomokoka | P0 |
| `Conxian/lib-conxian-core` | Shared runtime | Shared core | @botshelomokoka | P0 |
| `Conxian/lib-conclave-sdk` | Shared runtime | Shared SDK (TEE/crypto) | @botshelomokoka | P0 |
| `Conxian/stacksorbit` | Shared runtime | DevOps tooling | @botshelomokoka | P0 |
| `Conxian/Conxian_UI` | User surface | Operating function (UI) | @botshelomokoka | P1 |
| `Conxian/conxius-platform` | Shared runtime | Platform/DevEx | @conxian/core-devs | P1 |
| `Conxian/conxian-labs-site` | User surface | Public web | @botshelomokoka | P2 |
| `Conxian/.github` | Governance | Org defaults | @Conxian/Admins | P0 |

## Subrepository inventory (governed by `conxian-business`)

| Asset | Layer | Type | BU / function | Criticality |
| --- | --- | --- | --- | --- |
| `Conxian/` | Decentralization | Submodule | CSF (Protocol) | P0 |
| `conxius-wallet/` | User surface | Submodule | Conxius (Wallet) | P0 |
| `conxian-gateway/` | Decentralization | Submodule | Fusion (Gateway) | P0 |
| `conxian-nexus/` | Decentralization | Submodule | Nexus (State node) | P0 |
| `conxian-ui/` | User surface | Submodule | UI | P1 |
| `conxian-labs-site/` | User surface | Submodule | Public web | P2 |
| `conxius-platform/` | Shared runtime | Submodule | Platform/DevEx | P1 |
| `stacksorbit/` | Shared runtime | Submodule | DevOps tooling | P0 |
| `lib-conclave-sdk/` | Shared runtime | Submodule | Shared SDK | P0 |
| `lib-conxian-core/` | Shared runtime | Submodule | Shared core | P0 |
| `openspec/` | Governance | Directory | OpenSpec | P0 |
| `docs/` | Governance | Directory | Public docs | P0 |
| `scripts/` | Governance | Directory | Hygiene | P0 |
| `.github/` | Governance | Directory | Repo ops | P0 |
| `Fiscal-Vault-Oracle/` | Governance | Directory | Treasury (EXCO) | P0 |
| `Nakamoto-Guardian/` | Governance | Directory | Compliance (EXCO) | P0 |
| `Sovereign-Ops-Orchestrator/` | Governance | Directory | Ops (EXCO) | P0 |
| `Sovereign-Strategy-Nexus/` | Governance | Directory | Strategy (EXCO) | P1 |
| `cxn-grid-oracle/` | Shared runtime | Directory | Grid oracle | P1 |
| `showcase-dapp/` | User surface | Directory | Showcase | P2 |

---
© 2026 Conxian-Labs (Pty) Ltd | Omphile Ndaloenhle Legacy Trust
