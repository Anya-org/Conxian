# Portfolio repository inventory (CON-468)

This is the canonical map of all repositories in the Conxian-Labs ecosystem, classified by layer, role, and evaluation standard.

## Layer Taxonomy

- **Decentralization-critical**: Core protocol, state-consensus, and trust-minimized execution.
- **User and application surface**: Direct interaction layers for retail, business, and enterprise users.
- **Shared runtime and developer infrastructure**: SDKs, core libraries, and internal orchestration tools.
- **Governance and operating system**: BOS governance, OpenSpec, and internal EXCO coordination modules.

## Evaluation Standards (Release Criticality)

- **P0**: Mainnet release blockers. Must adhere to strict production standards (no stubs, no testnet contamination).
- **P1**: Important supporting surfaces. Should follow standards; drift is not immediately mainnet-blocking.
- **P2**: Nice-to-have, experimental, or informational surfaces.

## Canonical Repository Map

| Repository | Layer | Role / Function | Owner | Standard |
| :--- | :--- | :--- | :--- | :--- |
| `conxian-business` | Governance | BOS & OpenSpec Governance | @botshelomokoka | P0 |
| `Conxian` | Decentralization | CSF Core Protocol (Clarity) | @botshelomokoka | P0 |
| `conxian-nexus` | Decentralization | Nexus State Node (Rust) | @botshelomokoka | P0 |
| `conxian-gateway` | Decentralization | Fusion Gateway (Rust Engine) | @botshelomokoka | P0 |
| `conxius-wallet` | User Surface | Sovereign Multi-chain Wallet | @botshelomokoka | P0 |
| `lib-conxian-core` | Shared Runtime | Shared Cryptographic & State Logic | @botshelomokoka | P0 |
| `lib-conclave-sdk` | Shared Runtime | TEE & Enclave SDK | @botshelomokoka | P0 |
| `stacksorbit` | Shared Runtime | DevOps & Deployment Tooling | @botshelomokoka | P0 |
| `conxian-ui` | User Surface | Operating Dashboard (Next.js) | @botshelomokoka | P1 |
| `conxius-platform` | Shared Runtime | Developer Platform & Orchestration | @conxian/core-devs | P1 |
| `conxian-labs-site` | User Surface | Public Communication Surface | @botshelomokoka | P2 |
| `Fiscal-Vault-Oracle` | Governance | EXCO: Treasury & Market Data | @botshelomokoka | P0 |
| `Nakamoto-Guardian` | Governance | EXCO: Compliance & Security | @botshelomokoka | P0 |
| `Sovereign-Ops-Orchestrator` | Governance | EXCO: Operations & Service Loop | @botshelomokoka | P0 |
| `Sovereign-Strategy-Nexus` | Governance | EXCO: Strategic Alignment | @botshelomokoka | P1 |
| `cxn-grid-oracle` | Shared Runtime | Decentralized Data Oracle | @botshelomokoka | P1 |
| `showcase-dapp` | User Surface | Demo & Integration Showcase | @botshelomokoka | P2 |
| `.github` | Governance | Org-wide Standards & Workflows | @Conxian/Admins | P0 |

---
© 2026 Conxian-Labs (Pty) Ltd.
