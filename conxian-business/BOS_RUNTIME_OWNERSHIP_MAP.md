# BOS Runtime Ownership Map
**Version:** v1.0 (April 2026)
**Status:** CANONICAL REFERENCE

This document maps the Conxian Sovereign BOS capabilities to their respective runtime repositories. It distinguishes between conceptual documentation, public-safe stubs (ZSE), and actual production implementation.

## 1. Core Operating Suite (EXCO)

| Capability | Primary Repository | Responsibility | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Strategy Nexus** | `conxian-nexus` | High-level orchestration, State Roots (MMR), Dec. Storage (Kwil/Tableland). | Production (v0.5.1) |
| **Sovereign Gateway** | `conxian-gateway` | x402 Mandates, Bitcoin/Stacks RPC Pooling, ZKML compliance pipe. | Production (v0.1.1) |
| **Fiscal Vault** | `Fiscal-Vault-Oracle` | Treasury management, DLC Bonds, Yield execution logic. | Active |
| **Nakamoto Guardian** | `Nakamoto-Guardian` | Policy enforcement, Compliance auditing, Anti-fragility monitoring. | Active |

## 2. Shared Libraries & SDKs

| Capability | Repository | Purpose |
| :--- | :--- | :--- |
| **Conclave SDK** | `lib-conclave-sdk` | Cross-platform agentic primitives (TEE, StrongBox, Musig2). | Stable (v1.9.3) |
| **Sovereign Core** | `lib-conxian-core` | Shared models for BitVM2, CJCS, and gateway engine components. | Stable (v1.9.3) |

## 3. Interfaces & Platforms

| Capability | Repository | Audience | Implementation Status |
| :--- | :--- | :--- | :--- |
| **Conxian UI** | `conxian-ui` | Sovereign Operators | Active |
| **Conxius Wallet** | `conxius-wallet` | Retail/Mobile Users | Beta (Native-Track) |
| **Sovereign Platform** | `conxius-platform` | Developers & Ecosystem | Active |
| **BOS Operations** | `conxian-business` | Commercial, Legal, and Platform Specs (ZSE Stubs). | Canonical Reference |

## 4. Production Boundaries & Branch Policy

- **Main Branch (`main`)**: Strictly mainnet-ready, production-track code. Must pass all Contamination Guard checks.
- **ZSE Compliance**: Strategic material, PII, and sensitive secrets are NEVER committed. Use Linear stubs for strategic continuity.
- **Artifact Hygiene**: Generated binaries, `node_modules`, and local logs are excluded via global `.gitignore`.

---
*Maintained by Jules. Directly addresses CON-615.*
