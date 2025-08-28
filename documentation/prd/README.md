# Product Requirements Documents (PRDs)

Centralized, versioned PRDs for major Conxian subsystems.
Each PRD follows a consistent format to reduce ambiguity between architecture intent, 
governance proposals (AIPs), and implementation.

## Index

| Subsystem | File | Status | Owner | Version |
|-----------|------|--------|-------|---------|
| Vault Core | `VAULT.md` | Stable (v1) | Protocol | 1.1 |
| DAO Governance & Voting | `DAO_GOVERNANCE.md` | Stable (v1) | Protocol | 1.3 |
| Treasury & Reserve | `TREASURY.md` | Stable (v1) | Protocol | 1.1 |
| DEX / Liquidity Layer | `DEX.md` | Draft (v0.5) | R&D | 0.5 |
| Oracle Aggregator | `ORACLE_AGGREGATOR.md` | Draft (v0.4) | R&D | 0.4 |
| Security Layer (AIP 1–5) | `SECURITY_LAYER.md` | Living | Security WG | 1.2 |

## Format Standard

* Summary & Vision
* Goals / Non‑Goals
* User Stories
* Functional Requirements
* Non‑Functional Requirements (NFRs)
* Invariants & Safety Properties
* Data Model / State & Maps
* Public Interface (Contract Functions / Events)
* Core Flows (Sequence Narratives)
* Edge Cases & Failure Modes
* Risks & Mitigations (Technical / Economic / Operational)
* Metrics & KPIs
* Rollout / Migration Plan
* Monitoring & Observability
* Open Questions
* Changelog & Version Sign‑off

## Lifecycle

- Draft → Reviewed → Stable → Deprecated.  
- Any on-chain impacting change requires version bump & AIP link.  
- Security-affecting changes append a Security Advisory note.

## Traceability

| Artifact | Mapping |
|----------|---------|
| AIPs | Linked in Changelog / Goals |
| Tests | `stacks/tests/*` reference PRD requirement IDs (e.g., VAULT-FR-07) |
| Monitoring | `scripts/*monitor*` map to Metrics IDs |
| Security Docs | `SECURITY.md` mapped via invariants IDs |

---
Last Updated: 2025-08-17
