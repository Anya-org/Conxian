# Conxian Protocol: Financial Industry Standards Glossary (2026)

This document establishes the canonical terminology for the Conxian ecosystem, aligned with global TradFi (ISO 20022, MiCA, Basel III/IV) and DeFi (ERC-4626, SIP-010) standards.

## 1. Core Primitives

| Conxian Internal Term | Standardized Industry Term | Reference Standard | Definition |
| :--- | :--- | :--- | :--- |
| **Attestation (Zero-Knowledge Compliance)** | **Attestation / Proof of Compliance** | MiCA / FATF | A hardware-attested cryptographic proof that a transaction or user meets specific regulatory criteria without revealing raw data. |
| **ExchangeRate (Protocol Price/Purchasing)** | **Exchange Rate / Oracle Price** | ISO 20022 (CAMT) | The deterministic valuation of an asset relative to a benchmark (e.g., USD, BTC). |
| **DCR (Dynamic Collateral Ratio)** | **LTV (Loan-to-Value) / Capital Adequacy Ratio** | Basel III | The ratio of on-chain and ERP-verified assets to active liabilities, adjusted for risk multipliers. |
| **Sovereign Root** | **HD Master Seed / Root Entropy** | BIP-32 / BIP-44 | The hardware-anchored cryptographic origin for hierarchical deterministic key derivation. |
| **The Vault (Enclave)** | **TEE (Trusted Execution Environment)** | NIST / GlobalPlatform | A hardware-isolated secure area of a processor that guarantees code and data integrity. |

## 2. Smart Contract (Clarity) Terminology

| Internal Variable/Function | Standardized Term | Context |
| :--- | :--- | :--- |
| `deposit-assets` | `deposit-assets` | Asset inflow into a vault or collateral manager. |
| `withdraw-assets` | `withdraw-assets` | Asset outflow from a vault or collateral manager. |
| `clean-hands-compliance` | `sanctions-verification` | Compliance check against AML/OFAC lists. |
| `agent-risk` (AYE) | `risk-engine` | The autonomous logic determining stability fees and liquidation thresholds. |
| `fiscal-dam` | `treasury-controller` | Logic managing the flow of protocol revenue to various pools. |
| `dimensional-core` | `margin-engine` | System managing leveraged positions and cross-margining. |

## 3. System Architecture & Services

| Service Name | Standardized Definition | Role |
| :--- | :--- | :--- |
| **Conxian Nexus** | **State Orchestrator / Settlement Layer** | Manages cross-chain state proofs and ERP synchronization. |
| **Conxian Gateway** | **Financial Middleware / API Gateway** | Provides institutional access to Bitcoin/Stacks state and compliance services. |
| **Fusion Gateway** | **ERP Oracle / Data Bridge** | Connects legacy enterprise systems (SAP, Oracle) to the blockchain. |
| **Conxius Wallet** | **Sovereign Custody Client** | TEE-backed mobile/desktop interface for asset management and signing. |

## 4. Financial Instruments

| Term | Definition | Standard |
| :--- | :--- | :--- |
| **USDCx** | **Synthetic Dollar / Asset-Referenced Token** | MiCA ART |
| **sBTC** | **Wrapped Bitcoin / Trustless Peg** | SIP-010 |
| **Enterprise Swap** | **Revenue-Backed Obligation** | IFRS 9 |
| **Liquidity Pool** | **Automated Market Maker (AMM) Inventory** | DeFi Standard |

## 5. Status & Error Codes

| Code Prefix | Meaning | Industry Parallel |
| :--- | :--- | :--- |
| `E_AUTH_...` | Authentication Failure | HTTP 401 |
| `E_COMPLIANCE_...` | Regulatory/Compliance Halt | AML Block |
| `E_LIQUIDITY_...` | Insufficient Depth | Slippage/Orderbook |
| `E_SETTLEMENT_...` | Finality/Sync Error | Clearing Failure |

---
© 2026 Conxian Labs. Aligned for Global Institutional Adoption.
