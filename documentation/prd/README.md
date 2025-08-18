# Product Requirements Documents (PRDs)

Centralized, versioned PRDs for major AutoVault subsystems. Each PRD follows a consistent format to reduce ambiguity between architecture intent, governance proposals (AIPs), and implementation.

## Index

| Subsystem | File | Status | Owner | Version | Last Updated |
|-----------|------|--------|-------|---------|--------------|
| Vault Core | `VAULT.md` | **Stable (v1.1)** | Protocol | 1.1 | 2025-08-18 |
| DAO Governance & Voting | `DAO_GOVERNANCE.md` | **Stable (v1.1)** | Protocol | 1.1 | 2025-08-18 |
| Treasury & Reserve | `TREASURY.md` | **Stable (v1.1)** | Protocol | 1.1 | 2025-08-18 |
| DEX / Liquidity Layer | `DEX.md` | **Stable (v1.0)** | R&D | 1.0 | 2025-08-18 |
| Oracle Aggregator | `ORACLE_AGGREGATOR.md` | **Stable (v1.0)** | R&D | 1.0 | 2025-08-18 |
| Security Layer (AIP 1–5) | `SECURITY_LAYER.md` | **Stable (v1.2)** | Security WG | 1.2 | 2025-08-18 |
| **SDK Testing Framework** | `SDK_TESTING.md` | **New (v1.0)** | DevOps | 1.0 | 2025-08-18 |

## Format Standard

1. Summary & Vision  
2. Goals / Non‑Goals  
3. User Stories  
4. Functional Requirements  
5. Non‑Functional Requirements (NFRs)  
6. Invariants & Safety Properties  
7. Data Model / State & Maps  
8. Public Interface (Contract Functions / Events)  
9. Core Flows (Sequence Narratives)  
10. Edge Cases & Failure Modes  
11. Risks & Mitigations (Technical / Economic / Operational)  
12. Metrics & KPIs  
13. Rollout / Migration Plan  
14. Monitoring & Observability  
15. Open Questions  
16. Changelog & Version Sign‑off  

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
