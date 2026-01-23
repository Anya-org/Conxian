# Conxius Wallet

<<<<<<< HEAD
## Overview

🏦 Conxian Protocol:

A Multi-Dimensional, Stacks-Native Automated Monetary Platform.

📜 I. The SAB Manifesto
> "Code is Law, Logic is Sovereign."

Conxian is not a financial service provider; it is an autonomous digital organism. It operates as a Sovereign Autonomous Bank (SAB) where human discretion is replaced by mathematical certainty.
 * Autonomous: Decisions are executed by code, not committees.
 * Neutral: The protocol is a public utility, indifferent to borders or identities.
 * Sovereign: Conxian lives on the "Pure Chain," anchored by the immutable security of Bitcoin.

📖 II. Whitepaper Summary (v2.0)

Conxian provides a Platform-as-a-Service (PaaS) model for decentralized, multi-dimensional finance.
⚡ Core Services (Current Implementation)
 * Sovereign Bonds: Automated fixed-yield debt instruments.
 * Wormhole NTT: Native Token Transfers for cross-chain sovereignty without "wrapping."

**Planned Features (Not Yet Implemented):**
 * Money Markets: Algorithmic lending with real-time risk adjustment.
 * Flash Loans: Atomic, uncollateralized liquidity for arbitrage and rebalancing.
🗳️ Granulated Automated DAO Seats
Governance is segmented into five specialized automated seats that respond to on-chain metrics:
 * CXD (Debt): Automates stability and collateral ratios.
 * CXVG (Governance): Manages systemic logic and upgrades.
 * CXTR (Treasury): Rebalances reserves against BTC/STX volatility.
 * CXS (Staking): Manages yield distribution and reputation logic.
 * CXLP (Liquidity): Optimizes AMM depth and fee structures.

🏢 III. Enterprise Integration Guide

Conxian is designed for "Compliance at the Edge." ### 🔗 Connecting to the PaaS
Institutions can leverage Conxian's liquidity and debt structures while maintaining their own regulatory requirements through:
 * Custom NTT Transceivers: Plug in KYC-filtered transceivers for cross-chain movement.
 * Metric Oracles: Provide institutional-grade data feeds to trigger automated DAO seat actions.

⚖️ IV. License & Regulatory Decoupling

This project is licensed under the GNU General Public License v3 (GPLv3).
Why GPLv3?
 * Hands-Off Sovereignty: It establishes the protocol as a "public good." No central "manager" owns the commercial rights, which decouples the Architect from the financial actions of the users.
 * Permissionless Growth: It allows anyone to fork or build on Conxian, provided their contributions remain open-source.

🛠️ V. Developer Setup

Conxian is built with Clarity 4 and tested using the Clarinet SDK.

**For a comprehensive overview of the protocol's vision, architecture, smart contracts, and operational procedures, please visit our complete documentation hub:**

-   **[View Complete Documentation](documentation/README.md)**

This central hub contains all key documents, including:

-   **Strategic Overview & Whitepaper**
-   **Technical Architecture Guides**
-   **Smart Contract Module Breakdowns**
-   **Development Roadmap**
-   **Security Audit Reports**
-   **Developer & Contribution Guides**
=======
### The Sovereign Bitcoin Enclave

Designed by **Conxian Labs** under the **Conxian Brand**.

[![License](https://img.shields.io/badge/License-BUSL--1.1-orange.svg)](./LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Reproducible-success.svg)](https://github.com/conxian/conxius-wallet)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-blue.svg)](https://github.com/conxian/conxius-wallet)

Conxius is a mobile-first, non-custodial Bitcoin wallet built for the sovereign individual and the institutional operator.
It leverages a **Native Hardened Enclave** model to ensure your private keys never leave your device's secure hardware.
>>>>>>> 2b7ceb80d13077a5ed3f3a4228acdc870843f446

---

<<<<<<< HEAD
-   **Maturity Level**: 🔵 **Technical Alpha (Testnet)**
-   **Architectural Pattern**: Facade-Based & Trait-Driven
-   **Next Steps**: Comprehensive testing, third-party security audits, and preparation for mainnet.

***Disclaimer**: This project is in a Technical Alpha stage. The features and architecture described in the documentation represent the target design of the protocol, and not all functionality is fully implemented. Please refer to the module-specific `README` files for the most accurate information on the current state of the code.*

## Development Setup

### Prerequisites

1.  Clarinet 2.0+
2.  Node.js 18+
3.  Git
=======
## 🛡️ Core Principles

- **True Sovereignty**: No accounts, no email, no KYC. Your keys, your Bitcoin.
- **Native Enclave**: Private keys are generated and stored within the Android Keystore / Secure Enclave.
- **Zero Telemetry**: We do not track you. No analytics, no logging, no middle-man servers.
- **Multi-Layer Native**: Deep integration with:
**Bitcoin L1, Lightning (Breez/Greenlight), Stacks (SIP-005), Rootstock, Liquid, and Nostr.

## 🚀 Key Features

### 🏦 Institutional-Grade Security

- **Native Enclave Core**: Encrypted state persisted on-device with memory-only seed handling.
- **Ops Personas**: Pre-configured governance structures (BRICS, Business, Nomad, Unbanked) for entity management.
- **Risk Enclave**: Real-time institutional risk auditing and protocol-native moat quantification.

### ⚡ Lightning & Multi-Layer

- **Embedded Lightning**: Built-in Greenlight (Breez SDK) node for instant, low-fee payments.
- **Bitcoin L2 Support**: Native derivation for Stacks, Liquid, and Rootstock.
- **Coin Control Forge**: Real-time UTXO indexer with advanced coin selection and freezing capabilities.

### 🆔 Decentralized Identity

- **D.iD Integration**: Decentralized Identity (did:pkh:btc) derived natively from your enclave.
- **Nostr Transport**: Encrypted multi-sig coordination and decentralized profile metadata via Nostr relays.

## 📂 Repository Structure

- `components/`: React UI components following Bitcoin Design Standards.
- `services/`: Core logic for Enclave interactions, signing, and protocol integrations.
- `android/`: Native Capacitor bridge and Secure Enclave implementation.
- `docs/`: Comprehensive technical and operational documentation.

## 🛠️ Development

### Prerequisites

- Node.js (v18+)
- Android Studio + Android SDK (for device installs)
- Java 17+
>>>>>>> 2b7ceb80d13077a5ed3f3a4228acdc870843f446

### Getting Started

1. **Install Dependencies**

   ```bash
   npm install
   ```

2. **Run in Web (Mock Enclave)**

<<<<<<< HEAD
```bash
npm test
```
=======
   ```bash
   npm run dev
   ```

3. **Build & Sync Android**

   ```bash
   npm run build
   ```

## 🔐 Security & Privacy

### Reproducible Builds

Conxius is committed to reproducible builds. This allows anyone to verify that the binary provided in our releases was generated from the exact source code in this repository.

### Vulnerability Disclosure

If you find a security issue, please contact us at `security@conxian.com`.

## 📜 Documentation & Guides

All documentation is centralized in our **[Documentation Hub](./docs/)**.

- **[User Guide](./docs/user/user-guide.md)**: Onboarding and daily usage.
- **[Architecture](./docs/architecture.md)**: Deep dive into the Enclave and Plugin system.
- **[Institutional Onboarding](./docs/enterprise/onboarding.md)**: Setting up Ops Personas.

## ⚖️ License

Conxius Wallet is distributed under the Business Source License 1.1 (BUSL-1.1). See [LICENSE](./LICENSE) for details.

---

© 2024-2026 Conxian Labs. All rights reserved.
>>>>>>> 2b7ceb80d13077a5ed3f3a4228acdc870843f446
