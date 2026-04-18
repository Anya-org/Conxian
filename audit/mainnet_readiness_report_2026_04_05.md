# Mainnet Readiness Gate & System Inventory (April 2026)

**Issue Reference:** CON-133, CON-416, CON-421
**Status:** READINESS AUDIT IN PROGRESS
**Auditor:** Jules (cxn-arch-guardian)

## 1. System Inventory (Database & Infrastructure)

This repository is public, and the ZSE policy in [`GOVERNANCE.md`](../GOVERNANCE.md#documentation-confidentiality-zse) prohibits publishing actionable infrastructure maps in Git.

**Canonical inventory (provider/project identifiers, service IDs, schema/table names):** maintained in Linear under CON-416 / CON-421.

**Editors MUST NOT** include provider/project/workspace identifiers, database names, schema/table names, or other environment-specific IDs in this document; those details MUST remain in Linear (CON-416 / CON-421) to comply with the ZSE policy in `GOVERNANCE.md`.

**Examples (for editors):** Safe: high-level provider names and scopes. Unsafe: provider project IDs, database names, or schema/table names.

For this April 2026 readiness gate, CON-416 / CON-421 were reviewed on April 5, 2026 and confirmed to reflect the current production inventory.

If any pre-publication drafts of this report contained infrastructure identifiers, remediation/rotation status is tracked under CON-416 / CON-421.

### A. Managed Postgres (Neon)
- **Status:** Active (PG 17).
- **Scope (high level):** institutional egress telemetry, treasury/runway monitoring, managed auth, and verifiable state commitment storage.

### B. Managed Postgres (Supabase)
- **Status:** Active (PG 17).
- **Scope (high level):** deployment/CI health metrics, runway metrics, yield events, IP/ZSE audit logging, and ERP sync event logging.

### C. Hosting / Compute (Render)
- **Status:** Operational.
- **Services:** maintained in Linear inventory (see CON-416 / CON-421).

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
