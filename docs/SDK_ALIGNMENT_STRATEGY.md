# Conxian SDK and Library Alignment Strategy

## 1. Overview
As the Conxian ecosystem scales, the relationship between the core protocol (Clarity) and its supporting libraries (TypeScript, Rust, Python) must be clarified and hardened.

## 2. Core Libraries

### 2.1. Stacks.js (TypeScript)
- **Role**: Canonical client SDK for Web and Node.js environments.
- **Alignment**: Must track Clarity 4 keywords and Nakamoto block production logic.
- **Status**: V0.1.0 maintained in `conxius-orbit`.

### 2.2. Conxius Enclave SDK (Rust/WASM)
- **Role**: Secure, client-side transaction signing and ZK-proof generation.
- **Alignment**: Aligned with the "Sovereign Enclave" security model where secrets never leave the user's environment.
- **Status**: V0.2.0 undergoing CI/CD repair (CON-1190).

## 3. Relocation Inventory (Protocol Narrowing)

### 3.1. Gateway Runtime Logic
- **ISO 20022 Parser**: Belongs in the Gateway service.
- **OData v4 Translator**: Belongs in the Gateway service.
- **ERP Integration Handlers**: Move to dedicated enterprise-bridge repo.

### 3.2. UX/UI Artifacts
- **Conxian UI Components**: Relocated to the frontend flagship repo.
- **Wallet-Adapter Logic**: Shared across wallet and gateway surfaces.

## 4. Verification Standard
- Every SDK must implement a **State Proof Verification** layer that can trustlessly verify protocol status using the BitVM2 state root in `clarity-bitcoin.clar`.
