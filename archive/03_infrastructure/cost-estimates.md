# Conxian Labs: Baseline Operational Expense (OpEx) Estimates

This document defines the baseline monthly operational costs for Conxian Labs as of March 2026. These targets are codified into the Genesis Allocation contract's automated streaming logic to ensure operational continuity.

## 1. Baseline OpEx Targets

| Category | Monthly Cost (USD Equivalent) | Description |
| :--- | :--- | :--- |
| **Infrastructure** | $2,000 | Dedicated RPC nodes (Bitcoin/Stacks), GCP Cloud Run, and Secure Storage. |
| **Security & Auditing** | $5,000 | Continuous audit reserves and Bug Bounty fund for the CSF Standard. |
| **Core Maintenance** | $8,000 | Maintenance stipends for core protocol maintainers and unit leads. |
| **Total Baseline** | **$15,000** | **Target monthly release via 'Baseline_OpEx_Stream'.** |

## 2. Funding Mechanism

The `conxian-genesis-allocation.clar` contract manages these funds via:
1. **Automated Streaming**: Proportional release based on block-height (144 blocks/day).
2. **Multi-Sig Override**: Any update to the baseline rate requires a 3-of-5 confirmation from authorized Labs signers.
3. **Productive Capital**: Unvested founder equity is delegated to protocol staking to subsidize these costs via yield.

## 3. Scaling Plan

As the ecosystem moves toward Series A ($20M+), the baseline stream will be adjusted to support "Citadel" onsite deployments and national-level infrastructure.

---
© 2026 Conxian. Sovereign Autonomous Business.
[Return to Root README](../../README.md)
