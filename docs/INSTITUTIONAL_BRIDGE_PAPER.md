# Conxian Institutional Bridge: ISO 20022 and x402 Architecture

## 1. Abstract
Conxian Finance bridges legacy financial systems (TradFi) with Bitcoin DeFi using a deterministic, sovereign mapping between institutional payment standards and Stacks-native smart contracts.

## 2. The x402 Standard
The **x402 payment mandate** is the protocol's canonical bridge for institutional settlement. It maps:
- **ISO 20022 (pacs.008)**: Credit transfer instructions.
- **OData v4**: ERP system synchronization (SAP, Oracle).
- **SIP-018**: On-chain verifiable signatures.

## 3. Architecture
1. **Gateway Ingress**: Institutional instructions (XML/JSON) are received and parsed by the Conxian Gateway.
2. **Intent Verification**: Signatures are verified against the `kyc-registry` and `regulatory-adapter`.
3. **Smart Settlement**: The protocol executes the mandate (e.g., funding a liquidity pool or settling a loan) based on the cryptographically verified intent.

## 4. Security: Zero-Trust Bridge
Unlike centralized bridges that rely on a trusted federation, the Conxian Institutional Bridge uses **BitVM2** to verify state roots directly on Bitcoin. This ensures that institutional assets are protected by the full hash-power of the Bitcoin network.

## 5. Deployment
The x402 implementation (v1.1.0) is production-ready as of March 2026 and supports multi-currency settlement via the CXD stablecoin.
