# Conxian: Business Model & Technical Deep Dive (v1.0)

## 1. Executive Summary
Conxian is a **Non-Custodial Software Infrastructure Provider** building the unified interface for the Bitcoin economy. By replacing human discretion with "Code is Law" (SAB Logic), Conxian anchors all system states to the Bitcoin burn-block height. The business model transitions from high-utility retail tools (B2C) to high-margin institutional infrastructure (B2B).

---

## 2. Technical Model Deep Dive
### 2.1 Microservices Architecture
- **conxius-wallet**: The Sovereign Android Vault. Utilizes **TEE/StrongBox** for on-device key isolation.
- **lib-conxian-core**: The Rust-based "Single Source of Truth" for protocol primitives.
- **conxian-gateway**: High-performance Rust/Actix gateway for global orchestration and risk assessment.
- **conxius-platform**: System orchestrator for local and production deployment stacks.
- **stacksorbit**: Professional TUI/GUI for Stacks smart contract deployment and monitoring.

### 2.2 Security & Telemetry
- **cxn-arch-guardian**: Automated secret filtering to prevent sensitive leakages.
- **Fusion Auth**: Unified JWT/Enclave-based authentication without custodial risk.
- **Glass Node Architecture**: Full system transparency via Prometheus (9090) and Grafana (3001).

---

## 3. Business Model & Monetization
### 3.1 Sovereignty-Adjusted Fee (SAF)
- **Base Fee**: 0.25% (Disruptive vs. MetaMask's 0.875%).
- **Sovereignty Multiplier**: Users with higher security scores (TEE enabled, Tor active) receive discounts.
- **Floor Fee**: 0.1% (Keep-the-lights-on rate).

### 3.2 B2B Revenue Streams
- **Conclave SDK**: Tiered licensing ($2.5k - $15k+/mo) for fintechs and neobanks.
- **IaaS**: Proof-as-a-Service (BitVM/STARK) and Relay-as-a-Service.

---

## 4. Market SWOT Analysis

| **STRENGTHS** | **WEAKNESSES** |
| :--- | :--- |
| **TEE Isolation**: Hardware-grade security on mobile devices. | **Early Stage**: Significant dependencies on Phase 12/13/14 milestones. |
| **Non-Custodial Edge**: Eliminates most regulatory licensing requirements. | **Fragmented Docs**: Historical redundancy across submodules. |
| **Unified Bitcoin UX**: One app for L1, Lightning, Stacks, Liquid, RGB. | **Cloud Reliance**: Agile but theoretically centralized until Year 3.5. |

| **OPPORTUNITIES** | **THREATS** |
| :--- | :--- |
| **Bitcoin DeFi Boom**: Capturing TVL as sBTC and BitVM mature. | **Regulatory Volatility**: Sudden shifts in non-custodial definitions. |
| **Institutional B2B**: Providing the standard SDK for Bitcoin banks. | **Competitor Speed**: Xverse or Leather expanding into TEE/Enclaves. |
| **Global South Adoption**: Low-fee rails for remittance (ZAR/VALR integration). | **L2 Consolidation**: If one L2 dominates, multi-layer utility may drop. |

---

## 5. Competitive Landscape
- **Hardware Wallets (Ledger/Trezor)**: High security but low mobility and high friction.
- **Hot Wallets (MetaMask/Phantom)**: High utility but vulnerable to OS exploits.
- **Bitcoin L2 Wallets (Xverse/Leather)**: Excellent for specific layers but lacks the unified TEE isolation and B2B SDK focus of Conxian.

---

## 6. Issues, Gaps & Impact
### 6.1 Technical Gaps
- **Taproot Musig2 (M13)**: Required for institutional treasury quorums.
- **RGB-WASM (M14)**: Essential for client-side asset validation.
- **WabiSabi Coordinator (M15)**: The final step for institutional-grade privacy.

### 6.2 Operational Gaps
- **M12 "Real Rails"**: Currently in active deployment. Crucial for moving from public APIs to dedicated sovereign proxies.

---

## 7. Regulatory Handling & Compliance
- **The Legal Shield**: Strictly non-custodial. No keys ever touch Conxian servers.
- **Partner Delegation**: Regulated activities (KYC, Fiat) are delegated to **Transak** and **VALR**.
- **Compliance Labels**: UI clearly indicates when users leave the Conxius enclave for partner flows.

---

## 8. Impact Analysis
The Conxian model democratizes high-security Bitcoin finance. By reducing fees to 0.1% while maintaining $15k/mo B2B contracts, the ecosystem ensures long-term sustainability. The move to **Progressive Sovereignty** (Year 3.5+) mitigates the risk of cloud-provider censorship while maintaining the speed required for pre-seed and seed growth.
