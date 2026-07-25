# Independent Verification Path (CON-346)

## Overview
To ensure the integrity of the Conxian Sovereign Autonomous Business (SAB), all repository changes and agent-driven implementation must follow an independent verification path. This path separates planning and execution from verification and audit, preventing shared context or failure modes.

## Verification Workflow

### 1. External Repo Verification
Independent agents (e.g., Jules) are utilized for cross-repo verification.
- **Scope**: Audit branch protection rules, verify CI pass status on release candidates, and ensure production-path integrity (no testnet contamination).
- **Triggers**: Verified before any staged-to-main promotion.

### 2. Implementation Audit
Every technical repair (Phase 1 gaps) requires a separate audit session.
- **Baseline**: Current system state is evaluated against the March 2026 Systemic Audit.
- **Artifact**: A verification report (e.g., `docs/STANDARDS_VALIDATION_SESSION_X.md`) must accompany significant implementation PRs.

### 3. Standards Enforcement (6-Layer Framework)
Automated and manual checks enforce:
- **Structural**: `;; @desc` headers and Clarity 4 syntax.
- **Diátaxis**: Modular documentation structure.
- **Code-Doc Alignment**: Verification that READMEs reflect current contract signatures.
- **Contamination Gating**: Prohibition of hardcoded `ST...` principals in production code.

## Execution Support Path

### Session Handoff
To maintain continuity without re-discovery:
- **Linear Sync**: All session progress, decisions, and remaining gaps are recorded in the `Collective Memory` (CON-344).
- **Local State**: PRD and Audit reports are updated in `docs/` to serve as the source of truth for the next agent session.

### Verification Tools
- **Clarinet SDK**: Used for Simnet-based behavioral testing.
- **Sovereign Guard**: GitHub workflows that reject testnet residue.
- **Audit Scripts**: Python-based tools for structural header verification.
- **Main Branch Governance**: See [MAIN_BRANCH_GOVERNANCE.md](MAIN_BRANCH_GOVERNANCE.md) for the authoritative ownership policy, intended required checks, and admin-only ruleset verification.

---
**Status**: Baselined (April 2026)
**Reference**: CON-346, CON-390, CON-344
