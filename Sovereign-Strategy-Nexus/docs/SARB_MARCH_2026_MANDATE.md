# Global Reserve & SARB Compliance Mandate (ATS v4.8.0)

## 1. Objective
Codify the specific exchange control rules from the South Africa 2026 Budget Speech AND the **BIS/IMF Global Reserve Standards** to ensure institutional compliance for Conxian BOS.

## 2. Thresholds & Limits (SARB Specific)
- **Single Discretionary Allowance (SDA)**: 1.5M ZAR per calendar year (monitored via `conxian-gateway`).
- **Foreign Investment Allowance (FIA)**: 12M ZAR per calendar year, requiring AIT (Approval of International Transfer).
- **Institutional Asset Allocation**: 50bps cap on daily cross-border rebalancing without SARB-cleared pre-approval.

## 3. Global Reserve Compliance (BIS/IMF)
- **ISO 20022 Integration**: All institutional egress MUST match ISO 20022 XML standards (`pacs.008`, `camt.053`).
- **Legal Entity Identifier (LEI)**: Every corporate agent and treasury entity must have a verified LEI mapped to their DID (ERC-8004).
- **Basel III/IV Alignment**: Real-time Liquidity Coverage Ratio (LCR) and Net Stable Funding Ratio (NSFR) monitoring for all sovereign vaults.
- **Jurisdictional Sharding**: Automated sharding of state logic based on the counterparty's legal jurisdiction to avoid regulatory overlap.

## 4. Sovereign Shard Triggers
- **TRIGGER_SHARD_ONSHORE**: If SARB IP/KYC is detected and transaction > 50k ZAR.
- **TRIGGER_SHARD_OFFSHORE**: For all non-ZAR residents and non-SADC settlement flows.
- **TRIGGER_SHARD_GLOBAL**: For transactions involving Global Reserve Banks or Tier-1 institutional rails (SWIFT/Target2).

## 5. Automation & Enforcement
- **Compliance Czar (cxn-compliance-czar)**: Enforces real-time SARB and Global Reserve rule-checking on `conxian-gateway` middleware.
- **ZK-Attestation**: All compliance-exempted transactions must include a hardware-anchored TEE proof.
- **ISO 20022 Module**: (Gap: EXEC-ISO) Implementation of the XML transformation engine in the Gateway for banking egress.
