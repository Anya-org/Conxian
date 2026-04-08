# Conxian Job Card Schema (CJCS) v2.0.1 - Industrial Specification

**Date**: March 26, 2026 (Updated April 8, 2026)
**Version**: 2.0.1 (Industrial Release + Intent Standard)
**Status**: Baseline Draft

> **Note**: This document supersedes CJCS v2.0, but retains the filename `CJCS_v2.0_SPEC.md` for stable in-repo linking.

> **Versioning & compatibility:** CJCS v2.0.1 is intended as a backward-compatible revision of CJCS v2.0 (clarifying the Industrial Intent standard and dependency web logic). New integrations should prefer the `.../v2.0.1` `@context`. Existing integrations pinned to `.../v2.0` can continue to interoperate, but should migrate when practical.

## 1. Overview
The Conxian Job Card Schema (CJCS) is a machine-readable JSON-LD definition for ERP-to-Bitcoin labor coordination. It bridges the gap between institutional work orders (SAP/Oracle) and sovereign agent execution.

## 2. JSON-LD Definition

```json
{
  "@context": "https://conxian.com/contexts/job-card/v2.0.1",
  "@type": "ConxianJobCard",
  "id": "JOB-2026-001",
  "priority": 1,
  "unit_id": "TREASURY_REBALANCE_01",
  "sla_threshold": 1711468800,
  "referral_node": "did:cxn:agent:8822-00x1",
  "work_intent": {
    "@type": "x402Mandate",
    "action": "rebalance_sbtc",
    "parameters": {
      "source_vault": "OpexVault",
      "target_vault": "YieldAggregator",
      "amount_sbtc": 1.25
    }
  },
  "yield_distribution": {
    "worker_share": 0.95,
    "referrer_share": 0.05
  },
  "erp_mapping": {
    "system": "SAP_S4HANA_26A",
    "bapi_reference": "BAPI_ALM_ORDER_MAINTAIN",
    "external_id": "WO-990881"
  }
}
```

## 3. ERP Field Mapping

| CJCS Field | SAP BAPI Field (ALM) | Oracle REST Field (WorkOrder) | Description |
| :--- | :--- | :--- | :--- |
| `id` | `ORDERID` | `WorkOrderId` | Unique identifier |
| `priority` | `PRIORITY` | `WorkOrderPriority` | 1=Urgent, 2=High, 3=Normal |
| `sla_threshold` | `BASIC_FINISH_DATE` | `ScheduledCompletionDate` | Deadline for autonomous slashing |
| `referral_node` | `PARTNER_NUMBER` | `ReferredByAgentId` | The DID of the referring node |
| `unit_id` | `WORK_CENTER` | `OperationalUnit` | The Conxian Unit executing |

## 4. The "Industrial Intent" Standard
Virality in the B2B sector occurs when one lab's output is another lab's input. CJCS v2.0.1 serves as the "HTTP" of industrial coordination, enabling a **Dependency Web**.

- **Composable Intent**: If a lab builds an AI for "Warehouse Automation," they use CJCS as their native language.
- **Verification Loop**: If "Lab A" uses Conxian for *Inventory Proofs*, and "Lab B" builds a *CapEx Loan* engine, Lab B relies on CJCS to verify Lab A's data on-chain.

## 5. Sovereign Swarm (SIDL Integration)

The `referral_node` and `yield_distribution` fields enable the **Sovereign Swarm** virality flywheel. Every job card acts as an incentive anchor for agents on Twitter/X and Farcaster.

---
🛡️ **SOVEREIGN. INDUSTRIAL. BTC-NATIVE.**
