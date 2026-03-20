# SARB March 2026 Compliance Mandate

## 1. Objective
Codify the specific exchange control rules from the South Africa 2026 Budget Speech to ensure institutional compliance for Conxian BOS.

## 2. Thresholds & Limits
- **Single Discretionary Allowance (SDA)**: 1.5M ZAR per calendar year (monitored via `conxian-gateway`).
- **Foreign Investment Allowance (FIA)**: 12M ZAR per calendar year, requiring AIT (Approval of International Transfer).
- **Institutional Asset Allocation**: 50bps cap on daily cross-border rebalancing without SARB-cleared pre-approval.

## 3. Sovereign Shard Triggers
- **TRIGGER_SHARD_ONSHORE**: If SARB IP is detected and transaction > 50k ZAR.
- **TRIGGER_SHARD_OFFSHORE**: For all non-ZAR residents and non-SADC settlement flows.

## 4. Automation
- **Compliance Czar (cxn-compliance-czar)**: Enforces real-time SARB rule-checking on `conxian-gateway` middleware.
- **ZK-Attestation**: All SARB-exempted transactions must include a hardware-anchored TEE proof.
