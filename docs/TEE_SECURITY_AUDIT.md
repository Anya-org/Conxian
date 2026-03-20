# TEE Security Audit: Bitcoin Root of Trust (ATS v4.7)

## 1. Trust-Level Mapping
The following table defines the protection levels for Bitcoin private keys during cross-chain calls:

| Level | Hardware Anchor | Egress Policy | Use Case |
|-------|-----------------|---------------|----------|
| **L4: BitVM2** | BitVM Fraud Proofs | Zero Secret Egress | Institutional Settlement |
| **L3: StrongBox** | Android TEE/Keystore | Hardware-Enclosed | Retail / High-Frequency |
| **L2: CloudTEE** | AWS Nitro / GCP Confidential | Stateless / Ephemeral | B2B / Enterprise Routes |
| **L1: Software** | LocalStorage / Mock | Unprotected | R&D / Simulation Only |

## 2. Protection Mechanism
- **Intent Mandate**: User approves the intent (e.g., "Pay 0.1 BTC") within the TEE.
- **Cart Mandate**: Cryptographic handshake ensures the payload cannot be tampered with after intent signing.
- **Tax Enforcement**: The 1% fee is extracted *at the point of signature* via hardware-bound logic.

## 3. FASB Audit Trail
Every TEE-signed transaction is cross-referenced with LSEG MCP data for real-time asset valuation at the time of execution.
