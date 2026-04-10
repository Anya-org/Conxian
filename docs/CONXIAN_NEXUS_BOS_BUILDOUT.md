# conxian-nexus — BOS business buildout (CON-173)

This document defines the BOS-level business role, governance controls, and documentation separation guidance for `conxian-nexus`.

## 1) Business-unit role (Nexus State Node)

Per the repo portfolio, `conxian-nexus` is a **flagship** repo:

- **Portfolio classification**: `Flagship — Authoritative state node and telemetry surface.`
- **Business Purpose (External)**: Provide the source of truth for off-chain state, block height authority, and verifiable protocol telemetry.
- **Business Purpose (Internal)**: Power the ecosystem's decision-making engine by providing high-fidelity metrics and real-time state synchronization for downstream services.

## 2) Workflow Governance and Approval Paths

- **State Integrity**: Changes to state transition logic or Merkle tree implementations require rigorous testing and security review.
- **Approval Model**: PRs require review from Nexus maintainers (`@botshelomokoka @admin-conxian-labs`).
- **Release Support**: Nexus releases must align with Protocol updates to ensure state consistency.

## 3) Separating Protocol/Runtime from Internal Controls

- **Protocol/Runtime**: State machine implementation, sync ingestion loops, and telemetry exporters (Git).
- **Internal Controls**: Database connection strings for production instances, detailed infrastructure monitoring dashboards, and incident response runbooks (Linear/Supabase).

## 4) Business Logic and Documentation Gaps

- **Gap**: Lack of a "State Recovery Runbook" for node operators.
- **Gap**: Missing explicit documentation on "Safety Mode" triggers and thresholds.

## 5) Prioritized Build/Repair List

**P0 (Node Stability)**
- Resolve BitVM2 state root verification stubs (CON-450).
- Standardize `CHANGELOG.md` structure.

**P1 (Observability Maturity)**
- Add standardized `README.md` (Purpose, Status, Ownership, Releases).
- Finalize Prometheus metrics exporter for mainnet-ready telemetry.

**P2 (Documentation Alignment)**
- Move sensitive infrastructure mapping to Linear.
- Update `SECURITY.md` to reflect the public/private boundary for state data.
