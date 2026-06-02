# lib-conxian-core — BOS business buildout (CON-154)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `lib-conxian-core`.

## 1) Business-unit role (Shared Core)

Per the repo portfolio, `lib-conxian-core` is a **supporting** repo:

- **Portfolio classification**: `Supporting — Shared primitives, models, and conventions.`
- **Business Purpose (External)**: Provide a stable, dependency-light library of Conxian primitives for external developers building on the platform.
- **Business Purpose (Internal)**: Ensure consistency across the stack by centralizing shared types, models, serialization logic, and error conventions.

## 2) Workflow Governance and Approval Paths

- **Core Integrity**: Changes to shared models or cryptographic primitives require strict review to prevent breaking downstream consumers (Wallet, Gateway, Nexus).
- **Approval Model**: PRs require review from Core maintainers (`@botshelomokoka @admin-conxian-labs`).
- **Stability Support**: Maintain backward compatibility for all stable interfaces or provide clear migration paths in the changelog.

## 3) Internal Operating Documentation vs Public SDK Surface

- **Public Surface**: Shared models, serialization traits, and public utility functions (Git).
- **Internal Operating Docs**: Benchmarking reports, detailed trade-off analysis for core decisions, and internal-only security audit findings (Linear).

## 4) Business Logic and Documentation Gaps

- **Gap**: Lack of a "Core Contribution Guide" for internal and external developers.
- **Gap**: Missing explicit "Deprecation Policy" for shared primitives.

## 5) Prioritized Build/Repair List

**P0 (Core Stability)**
- [x] Remediate production-path contamination (CON-402).
- Standardize `CHANGELOG.md` with `## [Unreleased]` section.

**P1 (Library Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Implement automated versioning and publishing checks.

**P2 (Documentation Alignment)**
- Migrate sensitive research and performance logs to Linear.
- Align core models with CJCS v2.0 standards.
