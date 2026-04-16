# Bounty Classification Report (CON-231)

## Executive Summary
This report classifies active Linear issues as of April 2026 into specific participation domains. This ensures that externally claimable work is explicitly separated from internal-only deployment and security tasks.

## 1. Internal-Only (Maintainer Driven)
These tasks involve protocol integrity, mainnet orchestration, or sensitive system controls.

| ID | Title | Rationale |
|----|-------|-----------|
| CON-129 | CSF mainnet readiness gate | Final go/no-go control point. |
| CON-167 | Maintainer payout enablement checklist | Payout/Funds control. |
| CON-399 | Audit conxius-wallet production branch | Security/Signer path integrity. |
| CON-61 | Remediate admin centralization risk | Core protocol governance. |
| CON-10 | Mainnet launch | Orchestration. |
| CON-233 | Verify wallets and signers | Custody handling. |

## 2. Security-Sensitive (Trusted Contributors)
These tasks require deep protocol knowledge or specific pre-qualification.

| ID | Title | Requirement |
|----|-------|-------------|
| CON-75 | Wire BitVM2 verification floor | High complexity/Bitcoin state. |
| CON-72 | Finalize Bitcoin DLC Bond Lifecycle | Financial logic accuracy. |
| CON-70 | Integrate ZKML Verification | Specialized crypto-engineering. |

## 3. Externally Claimable (Community Open)
These tasks are open for public claims and external contribution.

| ID | Title | Category |
|----|-------|----------|
| CON-78 | Gateway Edge - Offline POS Sync | Integration/Edge. |
| CON-186 | Release hygiene — Conxian_UI | UI/Process. |
| CON-198 | Release hygiene — conxian-labs-site | Site/Docs. |
| CON-54 | Research contract deployment for Vaults | Ops/Research. |
| CON-49 | UI/UX Standardization | Frontend. |
| CON-347 | Reconcile repo registry | Governance/Cleanup. |

## Classification Rules
- **Rule 1**: Any task touching `main` branch deployment configuration is **Internal-Only**.
- **Rule 2**: Any task modifying the Principal Registry or Fiscal Policy is **Internal-Only**.
- **Rule 3**: Frontend, documentation, and standard ERP adapters are **Externally Claimable**.

---
**Status**: Active
**Last Updated**: April 2026
**Reference**: CON-231, CON-131
