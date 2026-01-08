# Conxian Protocol

> **For comprehensive documentation, please see our [Documentation Hub](./docs/).**

## Overview

Conxian is a sophisticated, multi-dimensional DeFi protocol on Stacks, designed
to provide a unified, secure, and efficient ecosystem for advanced financial
operations. We operate as a **Sovereign Autonomous Business (SAB)** — a Tier 0
Bitcoin-native financial infrastructure platform that combines retail
accessibility with institutional-grade controls. It has been architected from
the ground up to be modular, decentralized, and compatible with the latest
Stacks (Nakamoto) standards.

## System Status

- **Maturity Level**: 🔵 **Technical Alpha (Testnet)**
- **Architectural Pattern**: Facade-Based & Trait-Driven
- **Next Steps**: Comprehensive testing, third-party security audits, and
  preparation for mainnet.

## Core Architecture

The Conxian Protocol is built on a secure, modern, and modular **facade
pattern**. Each core piece of functionality (e.g., Core, DEX, Lending) is
exposed through a single, unified entry point contract (a "facade"). These
facades delegate all complex logic to a network of specialized,
single-responsibility "manager" contracts.

This architecture reduces the system's attack surface, improves maintainability,
and provides a clear, logical map of the protocol's operations.

> **For a complete technical breakdown of the architecture, including diagrams
> and control flow examples, see our
> [Architecture Overview](./docs/developer/architecture.md).**

## Core Modules

The protocol's functionality is organized into the following key modules:

- [Core Module](./contracts/core/README.md)
- [DEX Module](./contracts/dex/README.md)
- [Lending Module](./contracts/lending/README.md)
- [Governance Module](./contracts/governance/README.md)
- [Enterprise Module](./contracts/enterprise/README.md)
- [Tokens Module](./contracts/tokens/README.md)
- [Vaults Module](./contracts/vaults/README.md)
- [Security Module](./contracts/security/README.md)
- [Monitoring Module](./contracts/monitoring/README.md)

## License

Conxian Protocol core contracts and tooling are distributed under the **Business Source License 1.1 (BUSL‑1.1)** with a change date of **2029‑01‑01**, after which the code reverts to the MIT License. See [LICENSE](./LICENSE) for the full terms.

## Documentation

- **[Documentation Hub](./docs/)** - Complete documentation organized by user type
- **[Whitepaper](./whitepaper.md)** - Technical whitepaper
- **[ROADMAP](./ROADMAP.md)** - Development roadmap
- **[CHANGELOG](./CHANGELOG.md)** - Version history
- **[CONTRIBUTING](./CONTRIBUTING.md)** - Contribution guidelines
- **[LICENSE](./LICENSE)** - Business Source License 1.1 (change date 2029‑01‑01)

## Development Setup

### Prerequisites

1. Clarinet 2.0+
1. Node.js 18+
1. Git

### Installation

```bash
git clone https://github.com/anyachainlabs/Conxian.git
cd Conxian
npm install
```

### Testing

Run the comprehensive test suite:

```bash
npm test
```

### Advanced Testing Suites

- **System End-to-End**: `npm run test:system`
- **Performance Benchmark**: `npm run test:performance`
- **Fuzz Testing**: `npm run test:fuzz`
- **Security Audit**: `npm run test:security`

## Deployment

The protocol uses a staged deployment process managed by the `scripts/deploy-core.ts` script.

### Verified Principal Placeholders

When deploying to mainnet, ensure the following principals are used or replaced
with your specific addresses:

| Role                 | Principal / Placeholder                      | Notes                                 |
| -------------------- | -------------------------------------------- | ------------------------------------- |
| Devnet Deployer      | ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM    | Standard Clarinet Devnet Address      |
| Mainnet Deployer     | SP1CONXIANPROTOCOLDEPLOYERADDRESS            | Replace with your deployer            |
| Protocol Coordinator | SP1CONXIANPROTOCOLCOORDINATOR                | Address of deployed coordinator       |
| SIP-010 Trait        | SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE    | Standard Mainnet SIP-010 Trait        |
| POX Contract         | SP000000000000000000002Q6VF78                | Stacks Mainnet POX Contract           |

### Deployment Commands

#### Devnet Deployment

```bash
# Deploys to local Clarinet devnet
npm run deploy:core
```

#### Mainnet Deployment

Refer to `settings/Mainnet.toml` and ensure you have a valid deployer key.
