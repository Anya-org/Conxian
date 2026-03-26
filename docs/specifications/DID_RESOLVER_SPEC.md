# TECHNICAL SPECIFICATION: D.ID RESOLVER & COMPLIANCE (v1.0.0)

## 1. Executive Summary
The D.ID Resolver is the universal identity translation layer for the Conxius Wallet. It bridges Web3 social identities (Web3.bio), sovereign names (ENS/BNS), and Proof-of-Personhood (World ID) into a unified x402 cryptographic identity, satisfying SARB (South African Reserve Bank) exchange controls via Selective Disclosure.

## 2. Resolver Architecture
### 2.1 Web3.bio Integration
Aggregates Farcaster, Lens, and ENS profiles to provide "Social Veracity" scores for institutional partners.

### 2.2 BNS (Stacks) Native Support
Resolves `.btc` and `.stx` names into STX/BTC addresses within the enclave.

### 2.3 World ID / Proof-of-Personhood
Integrates World ID for sybil-resistance.
- **Ethos**: We do not store biometric data. We store a ZK-Proof of personhood verified against the World ID protocol.

## 3. Selective Disclosure (SARB Compliance)
To satisfy March 2026 SARB mandates without a centralized KYC database:
- **Protocol**: ERC-8004 (LEI Mapping).
- **Logic**: Users provide a ZK-Proof of their jurisdiction and tax residency.
- **Zero-Knowledge**: The Gateway verifies that the user is "South African Resident (SARS-Compliant)" without knowing their ID number or physical address.

## 4. Reputation & KYA
Every D.ID is assigned a **Knowledge Your Agent (KYA)** score based on:
1. Hardware Attestation (TEE/StrongBox)
2. Social Veracity (Web3.bio)
3. Transaction History (On-chain)
4. Proof of Personhood (World ID)

---
© 2026 Conxian-Labs. "Sovereign Identity."
