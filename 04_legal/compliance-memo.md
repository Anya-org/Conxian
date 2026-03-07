# Compliance Memo: Non-Custodial Regulatory Position

## Overview
Conxian operates a strictly non-custodial architecture.

## Technical Architecture
- **Key Management**: User keys are generated and stored exclusively within on-device Trusted Execution Environments (TEE) or StrongBox.
- **Access Control**: Authentication via Fusion Auth (JWT/Enclave-based).
- **Sovereignty**: No private keys are transmitted to or stored by Conxian servers.

## Regulatory Position
Since Conxian never takes custody of user assets, it does not fall under traditional money transmitter regulations in most jurisdictions. All actions are mathematically certain and governed by SAB (Sovereign Autonomous Business) logic.

## 2026 Strategic Compliance (MiCA & IRS)
Conxian extends its non-custodial position to include **Mathematically Verifiable Compliance Reports (MVCR).** By utilizing hardware-attested audit trails, the platform allows institutional users to remain compliant with MiCA (EU) and IRS Form 1099-DA (USA) without delegating custody to a centralized third party. This creates a "Regulatory Trust Moat" that differentiates Conxian from retail-centric incumbents.

---
[Return to Root README](../README.md) | [Strategic Alignment](../ALIGNMENT.md)
