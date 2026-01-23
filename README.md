# Conxius Wallet

### The Sovereign Bitcoin Enclave

Designed by **Conxian Labs** under the **Conxian Brand**.

[![License](https://img.shields.io/badge/License-BUSL--1.1-orange.svg)](./LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Reproducible-success.svg)](https://github.com/conxian/conxius-wallet)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-blue.svg)](https://github.com/conxian/conxius-wallet)

Conxius is a mobile-first, non-custodial Bitcoin wallet built for the sovereign individual and the institutional operator.
It leverages a **Native Hardened Enclave** model to ensure your private keys never leave your device's secure hardware.

---

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

### Getting Started

1. **Install Dependencies**

   ```bash
   npm install
   ```

2. **Run in Web (Mock Enclave)**

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
