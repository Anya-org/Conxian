# Conxian

[![Protocol Status](https://img.shields.io/badge/Status-Mainnet--Ready-green.svg)](https://conxian.com)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)
[![Clarity 4](https://img.shields.io/badge/Clarity-4.0-orange.svg)](https://docs.stacks.co)

Conxian is the protocol, DeFi, and DAO-facing public layer.

Conxian-Labs is the builder and operator layer that develops, ships, and supports public infrastructure around the Conxian ecosystem without replacing protocol ownership.

## Identity split (authoritative)

- **Conxian (protocol / DeFi / DAO-facing):** protocol primitives, public economic logic, governance-facing standards, and public ecosystem surfaces.
- **Conxian-Labs (builder / operator / company-facing):** engineering execution, portfolio operations, deployment tooling, and public support infrastructure around the ecosystem.

## CI/CD and Release Posture

This repository follows a strict CI/CD and hardening baseline:
- **Mandatory PR CI**: Every pull request must pass Node.js installation, `clarinet check`, `vitest` (CI pool), and coverage reports.
- **Security Guards**: Automatic scanning via `gitleaks`, dependency review, and a custom contamination guard to prevent testnet leakage.
- **Tag-Driven Releases**: Official protocol versions are identified by Git tags (e.g., `v0.6.1`).
- **Protected Environments**: Testnet and Mainnet deployment paths are guarded by GitHub Environments and manual approvals.

## Pinned portfolio logic

Pinned repositories should make the split visible at a glance:

1. Conxian protocol and DAO-facing surfaces first.
2. Support and access surfaces second.
3. Conxian-Labs narrative and operator surfaces last.

## Portfolio map

### Conxian protocol / DAO-facing layer

- `Conxian/Conxian`
- `Conxian/lib-conxian-core`

### Support and access layer

- `Conxian/conxius-wallet`
- `Conxian/conxian-gateway`
- `Conxian/conxian-nexus`
- `Conxian/conxius-platform`
- `Conxian/conxius-orbit`
- `Conxian/conxius-enclave-sdk`
- `Conxian/conxian_ui`

### Conxian-Labs public narrative layer

- `Conxian/conxian-labs-site`
- `Conxian/.github`

## Governance relation

Conxian-Labs contributes to and operates infrastructure around the Conxian ecosystem, but Conxian remains the protocol and DAO-facing identity.

## Contact

- Ecosystem and protocol collaboration: open an issue in the relevant public repository.
- Operations and commercial engagement: `support@conxian-labs.com`

---

## Contributing
Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
