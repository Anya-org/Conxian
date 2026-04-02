# Conxian: Sovereign Business Operations System (BOS v1.8.2)

This repository is the programmatic **State Machine** for Conxian operations. We have evolved from a system that runs on infrastructure to a system that **is** infrastructure—living directly on Bitcoin.

Supporting — governance + orchestration hub for the Conxian ecosystem (OpenSpec, docs, and submodule wiring).

See the [repo portfolio](docs/REPO_PORTFOLIO.md#ecosystem-repos) for the flagship/supporting repo map.

## Purpose

Define and version Conxian's Business Operations System (BOS) as an auditable, programmatic state machine (OpenSpec, governance, and operational artifacts).

## Status

Active. This is the public source of truth for BOS-level specifications and how the broader Conxian stack fits together.

## Audience

- Contributors implementing Conxian's protocol, infrastructure, and tools.
- Partners and auditors who need a canonical, versioned view of OpenSpec.

## Relationship to the Conxian stack

This repository pins and coordinates the flagship Conxian repositories, including:

- [`Conxian/`](./Conxian): Conxian Finance Protocol (Clarity smart contracts)
- [`conxian-gateway/`](./conxian-gateway): Conxian Gateway (Rust)
- [`conxian-nexus/`](./conxian-nexus): Conxian Nexus (Rust)
- [`lib-conxian-core/`](./lib-conxian-core): Shared core libraries centered around the Gateway
- [`conxian-ui/`](./conxian-ui): Conxian UI (web)
- [`conxius-wallet/`](./conxius-wallet): Conxius Wallet (mobile)
- [`conxius-platform/`](./conxius-platform): Stack orchestration and local development
- [`stacksorbit/`](./stacksorbit): Deployment and operations tooling
- [`conxian-labs-site/`](./conxian-labs-site): Conxian Labs public site

## 🚀 The Strategic Vision: Bitcoin-Native Evolution

Conxian is engineering a B+ Bitcoin-native ecosystem. Our Business Operations System (BOS) transforms operational excellence into verifiable, immutable proof on the world's most resilient network. This ensures absolute sovereignty and maximizes valuation for our Terminal Exit Vector.

## 🏛️ Ground Truth (OpenSpec)

The definitive technical specifications for the Conxian ecosystem are maintained in the `openspec/` directory. See the [Enterprise Sovereignty Baseline](./openspec/changes/remediate-enterprise-sovereignty/specs.md) for the latest architectural standards.

Sensitive strategy and operational documents have been migrated to the [Linear Virtual Office](https://linear.app/conxian-labs) for secure, high-integrity management in compliance with our Zero Secret Egress (ZSE) mandate.

## 🤖 Agentic EXCO Suite

The BOS is powered by an active suite of autonomous agents:

- **[Sovereign Strategy Nexus](./Sovereign-Strategy-Nexus)**: M&A velocity, structural integrity, and hardware-attested ZK-Data Room proofs.
- **[Fiscal Vault Oracle](./Fiscal-Vault-Oracle)**: Multi-sig Bitcoin treasury, automated BTC yield, and 1% (100 bps) Sovereign Tax routing to Conxian via revenue-automation.clar.
- **[Nakamoto Guardian](./Nakamoto-Guardian)**: ATS enforcement, immutable IP registry, and CARF/BRS v1.5 regulatory enforcement.
- **[Sovereign Ops Orchestrator](./Sovereign-Ops-Orchestrator)**: Bitcoin-native bounties, decentralized contributor onboarding, and protocol-owned layer (POL) management.

## 🏛️ Protocol Owned Layers (POL)

- **Settlement**: Anchored to Bitcoin L1 via OpenTimestamps and Stacks Nakamoto.
- **State Layer**: [Supabase](https://supabase.com) (Real-time Financials, IP Audit, Exit Velocity).
- **Execution Engine**: [Linear](https://linear.app) (Programmatic Action Task Specifications).
- **Monetization**: Hardcoded **0.1% protocol fee (CSF swaps) and 1% (100 bps) Sovereign Tax (A2P and cross-chain)** and 1% Software Licensing Royalty.

## 🛡️ Governance and Security

We adhere to strict sovereignty and security standards.

For general support and non-security bug reports, open a GitHub issue. For security vulnerabilities, follow the private reporting process in `SECURITY.md`.

This repository is licensed under the GNU GPL v3.0 (see `LICENSE`).

- [**CONTRIBUTING.md**](./CONTRIBUTING.md): Guidelines for contributing to the BOS.
- [**SECURITY.md**](./SECURITY.md): How to report vulnerabilities and our security posture.
- [**Trust & Proof Messaging**](./docs/TRUST_AND_PROOF_MESSAGING.md): Public-facing trust surface guidance.
- [**LICENSE**](./LICENSE): GNU GPL v3.0.
- [**CHANGELOG.md**](./CHANGELOG.md): History of BOS changes.
- [**CODEOWNERS**](./CODEOWNERS): Repository ownership and review guidance.

## 📂 Repository Hygiene

To maintain a clean and sovereign workspace, we adhere to strict hygiene standards:
- **`scripts/`**: Contains active utility scripts (e.g., `check_links.py`).
- **`archive/remediation_scripts/`**: Historical artifacts from previous system audits and remediations.
- **`openspec/`**: Definitive technical specifications.

## 🗺️ Implementation Roadmap (v1.8.2)

1. **Foundation (Q3-Q4 2025)**: Anchor key metrics and IP assets to Bitcoin. Establish multi-sig treasury.
2. **Integration (Q1-Q2 2026)**: Deploy autonomous BTC yield and on-chain governance logs.
3. **Sovereignty (Q3-Q4 2026+)**: Complete migration of critical state to Bitcoin; May 2027 SARS compliance deadline.

> "We didn't build Conxian to be another company running on rented infrastructure. We built it to be sovereign. This roadmap delivers that sovereignty—not in theory, but through every agent in our EXCO suite, on the most resilient network humanity has ever created."

---
🛡️ **Sovereign Autonomous Business (SAB)**. © 2026 Conxian-Labs. Powered by Bitcoin.
