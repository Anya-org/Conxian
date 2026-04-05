# Mainnet Readiness Gate & System Inventory (April 2026)

**Issue Reference:** CON-133, CON-416, CON-421
**Status:** READINESS AUDIT IN PROGRESS
**Auditor:** Jules (cxn-arch-guardian)

## 1. System Inventory (Database & Infrastructure)

### A. Neon Project: Conxian-backend (orange-paper-76209725)
- **Status:** Active, PG 17.
- **Key Tables:**
  - `cnx_bos.cxn_external_settlement_logs`: Tracking institutional egress signals.
  - `cnx_bos.m_and_a_readiness`: Strategic growth tracking.
  - `cnx_bos.treasury_runway`: Fiscal health monitoring.
  - `neon_auth.*`: Managed authentication (Better Auth compatible).
  - `public.mmr_nodes`: Verifiable state commitment storage.

### B. Supabase Project: Conxian-platform (iczqutrbbfudfzfplymc)
- **Status:** Active, PG 17.
- **Key Tables:**
  - `public.deployment_efficiency`: Monitoring release velocity and CI health.
  - `public.runway_metrics`: Real-time fiscal telemetry.
  - `public.yield_events`: Protocol revenue and yield tracking.
  - `public.ip_audit_logs`: Intellectual Property and ZSE compliance auditing.
  - `public.erp_sync_events`: OData v4 / ISO 20022 synchronization logs.

### C. Render Workspace: Conxian-Business (tea-d6u0edngi27c73dvhsg0)
- **Status:** Operational.
- **Services:** [Inventory Pending - Requires explicit service listing]

## 2. Production Readiness Checklist

| Category | Item | Status | Notes |
| --- | --- | --- | --- |
| **Governance** | Branching Policy Enforcement | IN PROGRESS | `main`/`staged`/`dev` model defined. |
| **Security** | Zero Secret Egress (ZSE) | COMPLIANT | No secrets in Git; sensitive strategy migrated. |
| **Protocol** | Clarity 4 Alignment | PENDING | Audit identified `ST1...` principals and stubs. |
| **Gateway** | Institutional Egress | SIMULATED | ISO 20022 pacs.008 is formatted but OData is stubbed. |
| **Nexus** | State Authority | ENHANCED | ZKML and DLC are currently stubs; Nexus API is priority. |
| **Wallet** | Enclave Signing | VERIFIED | ZSE compliance in `services/identity.ts`. |

## 3. Critical Blockers for Mainnet Cutover
1. **Hardcoded Principals:** 76+ contracts still use devnet addresses. Must be remediated to dynamic RBAC (CON-61).
2. **Functional Stubs:** Settlement, ZKML, and DLC logic must move from simulation to production code.
3. **Branch Cleanup:** Non-production "contamination" (stubs/mocks) must be removed from the `main` branch.

---
**Verified by:** Jules (cxn-arch-guardian)
**Date:** April 5, 2026
