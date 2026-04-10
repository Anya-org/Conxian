# conxius-platform — BOS business buildout (CON-149)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `conxius-platform`.

## 1) Business-unit role (Orchestration and DevEx)

Per the repo portfolio, `conxius-platform` is an **operating function** repo:

- **Portfolio classification**: `Operating function — Master orchestration and local stack DevEx.`
- **Business Purpose (External)**: Provide a reference implementation for running the Conxian ecosystem end-to-end, supporting partners and institutions in their deployment efforts.
- **Business Purpose (Internal)**: Standardize developer workflows, service wiring, and local environment orchestration to ensure dependable delivery across all business units.

## 2) Workflow Governance and Approval Paths

- **Orchestration Integrity**: Any change to shared compose files or service wiring must be validated against the full stack.
- **Approval Model**: PRs require review from the Platform maintainers (`@conxian/core-devs`).
- **Release Support**: Platform must align with the release cycles of upstream product repos (Gateway, Nexus, Wallet).

## 3) Separating Operations from Administrative Controls

- **Platform Operations**: Docker configurations, environment templates, and CLI orchestration helpers (Git).
- **Administrative Controls**: Access management policies, deployment secrets, and sensitive infrastructure mapping (Linear Virtual Office).

## 4) Business Logic and Documentation Gaps

- **Gap**: Lack of explicit "how-to-deploy" guides for different operator classes.
- **Gap**: Missing boundary validation between local dev and production-ready staging.

## 5) Prioritized Build/Repair List

**P0 (Orchestration Stability)**
- Resolve submodule integrity failures in CI.
- Fix broken orchestration paths for mainnet-ready services.

**P1 (DevEx Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Implement explicit "stop-ship" checks for platform-level regressions.

**P2 (Documentation Hygiene)**
- Classify platform docs as public-safe vs internal-only.
- Move sensitive deployment runbooks to Linear.
