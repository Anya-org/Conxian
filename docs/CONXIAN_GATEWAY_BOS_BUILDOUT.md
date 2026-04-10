# conxian-gateway — BOS business buildout (CON-151)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `conxian-gateway`.

## 1) Business-unit role (Fusion Gateway)

Per the repo portfolio, `conxian-gateway` is a **flagship** repo:

- **Portfolio classification**: `Flagship — Fusion integration and compliance gateway.`
- **Business Purpose (External)**: Provide a high-integrity integration surface for institutional partners, enabling seamless connection between legacy ERP systems and the Bitcoin economy.
- **Business Purpose (Internal)**: Act as the primary compliance and aggregation pipeline, ensuring all inbound settlement requests meet protocol standards before execution.

## 2) Workflow Governance and Approval Paths

- **Integration Integrity**: Changes to external-facing APIs or webhook handlers must maintain backward compatibility or follow the deprecation policy.
- **Approval Model**: PRs require review from Gateway maintainers (`@botshelomokoka @admin-conxian-labs`).
- **Release Support**: All production releases must be tagged and accompanied by a changelog entry.

## 3) Separating Runtime/Integration from Internal Controls

- **Runtime/Integration**: Rust service code, API definitions, and partner adapters (Git).
- **Internal Controls**: Production endpoint credentials, partner-specific commercial terms, and detailed compliance audit trails (Linear/Supabase).

## 4) Business Logic and Documentation Gaps

- **Gap**: Missing comprehensive "Partner Integration Guide" for automated onboarding.
- **Gap**: Lack of explicit T+0 operational constraints documentation for settlement flows.

## 5) Prioritized Build/Repair List

**P0 (Gateway Reliability)**
- Standardize `CHANGELOG.md` with `## [Unreleased]` section.
- Implement automated verification for x402 header parsing (CON-451).

**P1 (Compliance Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Define explicit ownership for compliance-gating logic.

**P2 (Documentation Alignment)**
- Migrate sensitive partner mapping to Linear.
- Establish a "Global Settlement Ingress" rollout tracker.
