# CONXIAN MASTER BASELINE SPECIFICATION (MARCH 2026)

## 1. CORE ARCHITECTURE
The Conxian ecosystem is a vertically integrated Sovereign Stack:
- **Conxius Wallet**: The non-custodial interface (TEE-backed).
- **Conxian Gateway**: The institutional "Pipe" for ERP and Fiat integration.
- **Conxian Nexus**: The state-orchestration layer.
- **Conxian Finance (CSF)**: The settlement and yield protocol (sBTC/USDCx).

## 2. TECHNICAL BASELINE
- **Rust (Edition 2024)**: Gateway/Nexus/SDK. Strict async safety (Send trait).
- **Clarity 4 (Nakamoto)**: Smart contracts on Stacks L2.
- **Hardware Enclaves**: StrongBox (Android), Secure Enclave (iOS), TEE (Cloud).
- **Identity**: D.ID (did:pkh:btc) + Web5 (DWNs) + World ID.

## 3. KEY SPECIFICATIONS
1. [ERP Adapter Spec](./specifications/ERP_ADAPTER_SPEC.md)
2. [D.ID Resolver Spec](./specifications/DID_RESOLVER_SPEC.md)
3. [70% Loop (Tax Controller) Spec](./specifications/70_LOOP_SPEC.md)

## 4. MISSION ALIGNMENT
100% of yield-generation logic is **non-dilutive** and **principal-protected** via Bitcoin DLC Bonds and Stacks sBTC stacking.

---
🛡️ **Rooted Baseline**. © 2026 Conxian-Labs.
