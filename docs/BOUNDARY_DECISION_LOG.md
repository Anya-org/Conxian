# Boundary Decision Log — Public-Safe vs Internal-Only Artifacts

> **Issue**: [#825](https://github.com/Conxian/conxian-business/issues/825) — Boundary review for tracked strategy and scorecard material
> **Status**: Canonical
> **Last reviewed**: 2026-07-03
> **Review cadence**: On every major release or boundary-affecting PR

## Purpose

This document records explicit boundary decisions for every artifact in `conxian-business` that could blur the line between **public-safe** (OK to expose in a public repo) and **internal-only** (must remain in the Conxian Linear workspace per Zero Secret Egress mandate).

## Classification Framework

| Classification | Definition | Where It Lives |
|----------------|-----------|----------------|
| **Public-safe** | No secrets, no commercially sensitive strategy, no operational runbooks. Safe for public GitHub. | Git (this repo) |
| **Public-safe stub** | A short pointer file in Git; canonical content lives in Linear. Resolves link continuity while keeping sensitive detail out of public view. | Git (stub) + Linear (canonical) |
| **Internal-only** | Contains commercially sensitive strategy, partner data, operational runbooks, or privileged identifiers. Must NOT appear in Git in any form. | Linear only |
| **Derived (generated)** | Auto-generated from canonical sources; not edited by hand. `.generated/` directory (gitignored). | `.generated/` (local only) |

## Sovereign Boundary Invariants

1. **No secrets in Git.** Secrets, privileged identifiers, and operational runbooks live in Linear or Supabase only.
2. **Stubs fail closed.** If canonical content is unavailable, the stub resolves to `err-u501` / `err-u503`.
3. **Commitment-based linking.** When internal-only documents must be referenced from public-safe surfaces, use hash commitments (`sha256(hex)`), not URLs or identifiers.
4. **Contamination guard.** Any `.clar` file in a production-track path with hardcoded testnet/simnet principals breaks the build immediately.

## Artifact Boundary Register

### Strategy & Scorecard

| Artifact | Classification | Boundary Decision | Rationale |
|----------|---------------|-------------------|-----------|
| `docs/operations/CON-762_PARTNER_SCORECARD_AND_SHORTLIST.md` | **Public-safe stub** | Canonical in Linear (CON-762). Git stub retained for link continuity. | Partner names, dimension scores, scenario weights, and build-vs-partner decisions are commercially sensitive procurement strategy. |
| `docs/operations/con-762-partner-scorecard/*/` (CSV stubs) | **Public-safe stub** | Canonical in Linear. CSV files are ZSE stubs. | Same as above. Dimension scores and weighted partner scores must not appear in Git. |
| `Sovereign-Strategy-Nexus/` | **Public-safe stub** | Canonical strategy tracking and narrative scaffolding in Linear. Git directory is a ZSE stub. | Strategy material must not mix into product repos. Per BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX. |
| `docs/operations/CON-682_APPROVED_METRIC_SPEC.md` | **Public-safe** | Formula definitions (C_R, O_C, V_X, A_S, N_E) are safe to publish. Actual metric values and dashboards remain in Linear/Supabase. | Formulas are architecture-level; values are commercially sensitive. |
| `cxn-grid-oracle/` | **Public-safe** | Schema-level oracle surface only. Alpha; not a BOS critical dependency. | Small, public-safe interface contract per BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX. |

### BOS State & Orchestration

| Artifact | Classification | Boundary Decision | Rationale |
|----------|---------------|-------------------|-----------|
| `conxian-business/BOS_STATE_MACHINE.stub.json` | **Public-safe stub** | Derived BOS state audit output. Canonical in Linear. Do not hand-edit. | Generated from transparency_custodian.py; treat as pointer only. |
| `conxian-business/AUDIT_MANIFEST.stub.json` | **Public-safe stub** | Generated audit output. Canonical in Linear. | Same as above. |
| `conxian-business/SARB_COMPLIANCE_REPORT.stub.json` | **Public-safe stub** | Internal compliance identifiers in Linear. | Public-safe stub with note pointing to Linear workspace. |
| `Sovereign-Ops-Orchestrator/` | **Public-safe stub** | Linear-to-BOS wiring and orchestration runbooks in Linear. Git directory is a ZSE stub. | Prevents accidental leakage of operational wiring per BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX. |
| `Fiscal-Vault-Oracle/` | **Public-safe stub** | Treasury runway/yield control surfaces in Linear. Git directory is a ZSE stub. | Clear separation between public-safe pointers and internal-only operational detail. |
| `Nakamoto-Guardian/` | **Public-safe stub** | Compliance/policy enforcement loops in Linear. Git directory is a ZSE stub. | Keeps operational enforcement details out of Git. |

### Architecture & Design

| Artifact | Classification | Boundary Decision | Rationale |
|----------|---------------|-------------------|-----------|
| `docs/architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md` | **Public-safe** | Architecture only. Vendor-specific templates, secret management, and concrete endpoints excluded per ZSE. | Defines invariants, lanes, and component model without operational detail. |
| `docs/architecture/BOS_SOVEREIGN_ENTERPRISE_IDENTITY_ARCHITECTURE.md` | **Public-safe** | Trust primitives, interfaces, and invariants only. No operational runbooks or secret material. | Hardware-backed identity design without exposing implementation secrets. |
| `docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md` | **Public-safe** | Architecture only. Secret management, allowlists, vendor endpoints excluded. | Public-safe payload fields defined; internal docs behind hash commitments. |
| `docs/architecture/BOS_SUPPLY_CHAIN_VERIFICATION_AND_PROOF_PIPELINE.md` | **Public-safe** | Checkpoint payloads are public-safe; sensitive documents behind hash commitments. | ZSE by default for public-safe surfaces. |
| `docs/architecture/BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX.md` | **Public-safe** | Gap analysis of BOS components. References ZSE stubs without exposing their content. | Architectural alignment without operational detail. |

### Bounties & Community

| Artifact | Classification | Boundary Decision | Rationale |
|----------|---------------|-------------------|-----------|
| `docs/bounties/BOUNTY_WORKFLOW.md` | **Public-safe** | Workflow rules for bounty claims, labels, status model. No payout instructions. | Community-facing process without financial or security exposure. |
| `docs/bounties/CON-137_COMMUNITY_FUNDING_MODEL.md` | **Public-safe** | Funding eligibility and constraints. Payout-enablement gates described, not configured. | Policy-level; actual payout controls in Linear. |
| `docs/bounties/CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md` | **Public-safe** | Classification decision and audit queries. No privileged data. | Historical classification artifact. |
| `docs/bounties/MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md` | **Public-safe stub** | Canonical in Linear (CON-256). Git stub for link continuity. | Payout enablement procedures are privileged. |

### CI/CD & Operations

| Artifact | Classification | Boundary Decision | Rationale |
|----------|---------------|-------------------|-----------|
| `.github/workflows/*.yml` | **Public-safe** | All CI workflows public. Secrets referenced via `${{ secrets.* }}`; never hardcoded. | Workflow definitions are infrastructure-as-code; secrets injected at runtime. |
| `scripts/verify_contamination_guard.py` | **Public-safe** | Guard logic is public. Detection patterns are public. | Enforcement mechanism should be transparent to contributors. |
| `docs/operations/CON-681_PHASE6_PRODUCTION_ROLLOUT_RUNBOOK.md` | **Public-safe** | Rollout gates, metrics, and triggers described. Privileged identifiers and endpoints in Linear. | Operator-visible procedures without exposing sensitive infrastructure. |
| `docs/operations/CON-681_PHASE6_ROLLBACK_DRILL_SIMULATION.md` | **Public-safe** | Drill scenario and outcomes. Environment identifiers in Linear. | Drill artifact for gate evidence without exposing live infrastructure. |
| `docs/operations/CON-780_LIGHTNING_COVERAGE_TRACKER.md` | **Public-safe** | Test matrix and ownership split. Coverage percentages and status public. | Test coverage tracking is safe to expose. |

## Items Identified for Stronger Isolation

The following were identified during the #825 boundary review as needing explicit tracking:

| Item | Current State | Action Required | Tracking |
|------|--------------|-----------------|----------|
| Weekly growth-driver metrics values | CON-682 defines formulas (public-safe); actual values not yet produced | When implemented (#831), ensure metric VALUES stay in Linear/Supabase; only formulas and review process in Git | #831 |
| Partner scorecard dimension scores | Already in Linear (ZSE stubs in Git) | No action — boundary already enforced | CON-762 |
| Strategy narrative and scorecard artifacts | `Sovereign-Strategy-Nexus/` is a ZSE stub | No action — boundary already enforced | #825 |
| Commercial packaging and pricing doctrine | Does not yet exist in Git | When created (#829), ensure only public-safe summary exists; pricing details in Linear | #829 |
| Buyer-trust and readiness language | Scattered across READMEs and architecture docs | Audit in #830 to ensure consistency with implementation truth | #830 |

## Review Checklist

Before closing a boundary-affecting PR, verify:

- [ ] New `.clar` files pass contamination guard (no hardcoded `ST…`/`SP…` principals)
- [ ] New `.md` files classified as public-safe, public-safe stub, or internal-only
- [ ] No secrets, privileged identifiers, or operational runbooks in new files
- [ ] If referencing internal-only content, use hash commitments, not URLs
- [ ] Stub files include pointer to the canonical Linear issue
- [ ] This boundary decision log updated with new artifacts

## Related Documents

- [Zero Secret Egress (ZSE) Compliance](../AGENTS.md#zero-secret-egress-zse-compliance)
- [Contamination Guard](../scripts/verify_contamination_guard.py)
- [Sovereign-First Deployment Mandate](../AGENTS.md#sovereign-first-deployment-mandate)
- [Portfolio Business-Unit Map](PORTFOLIO_BUSINESS_UNIT_MAP.md)
- [BOS Preserve/Enhance/Replace Gap Matrix](architecture/BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX.md)
- [CON-762 Partner Scorecard](operations/CON-762_PARTNER_SCORECARD_AND_SHORTLIST.md)
