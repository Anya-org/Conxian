# .github — BOS business buildout (CON-174)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for the org-level `.github` repository.

## 1) Business-unit role (Org Governance)

Per the repo portfolio, `.github` is a **governance** repo:

- **Portfolio classification**: `Governance — Centralized templates, workflows, and org defaults.`
- **Business Purpose (External)**: Define the standards for community health, security reporting, and contributions across the Conxian organization.
- **Business Purpose (Internal)**: Enforce operational guardrails, automate hygiene checks, and provide a single source of truth for repository lifecycle management.

## 2) Workflow Governance and Approval Paths

- **Governance Integrity**: Changes to org-level CI workflows, issue templates, or PR requirements must be reviewed for cross-repo impact.
- **Approval Model**: PRs require review from Org Admins (`@Conxian/Admins`).
- **Standardization Support**: Ensure all flagship and supporting repos inherit the latest governance baselines.

## 3) Org-wide Standards vs Repo-specific Logic

- **Org-wide Standards**: Issue/PR templates, `CONTRIBUTING.md`, `SECURITY.md`, and shared CI actions (Git).
- **Repo-specific Logic**: Detailed implementation guides, unit test configurations, and business-unit-specific rules (Individual repos).

## 4) Business Logic and Documentation Gaps

- **Gap**: Missing clear mapping of "Inherited Governance" vs "Local Exceptions".
- **Gap**: Lack of explicit "Handoff Policy" for moving work between repos.

## 5) Prioritized Build/Repair List

**P0 (Org Integrity)**
- Fix failing hygiene verifiers affecting the whole org (CON-453).
- Standardize `CODEOWNERS` for all critical paths.

**P1 (Maturity Propagation)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Document org-wide release and merge hygiene standards (CON-178).

**P2 (Documentation Alignment)**
- Verify `SECURITY.md` coverage and disclosure paths.
- Standardize governance files across all public repositories (CON-432).
