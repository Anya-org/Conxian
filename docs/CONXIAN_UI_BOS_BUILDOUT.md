# Conxian_UI — BOS business buildout (CON-150)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `Conxian_UI`.

## 1) Business-unit role (User Surface)

Per the repo portfolio, `Conxian_UI` (to be renamed `conxian-ui`) is an **operating function** repo:

- **Portfolio classification**: `Operating function — Web UX for interacting with the ecosystem.`
- **Business Purpose (External)**: Provide a seamless, high-trust web experience for users and partners to interact with Conxian protocols, manage positions, and view system health.
- **Business Purpose (Internal)**: Serve as the primary visual interface for the BOS, translating complex protocol states into actionable insights for operators and stakeholders.

## 2) Workflow Governance and Approval Paths

- **UI Integrity**: Presentation-layer changes must be validated for accessibility, security (XSS/CSRF), and alignment with the Conxian design system.
- **Approval Model**: PRs require review from UI maintainers and occasionally product owners for UX alignment.
- **Release Support**: UI updates should be coordinated with Gateway/Nexus API versioning.

## 3) Separating Presentation Layer from Internal Controls

- **Presentation Layer**: React/Next.js components, styling, and client-side routing (Git).
- **Internal Controls**: Admin-only dashboard routes, internal analytics keys, and sensitive environment configuration (Linear/Supabase).

## 4) Business Logic and Documentation Gaps

- **Gap**: Missing "Component Library" documentation for consistent UI development.
- **Gap**: Lack of explicit documentation on client-side state handling for T+0 settlement views.

## 5) Prioritized Build/Repair List

**P0 (Release Confidence)**
- Audit production branch for placeholders and stubbed UI integrations (CON-405).
- Remove generated artifacts (`node_modules`, `.next`) from tracking.

**P1 (UX Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Implement explicit "stop-ship" checks for UI regressions on critical paths.

**P2 (Documentation Alignment)**
- Move internal-only operating guides to Linear.
- Standardize `CHANGELOG.md` with `## [Unreleased]` section.
