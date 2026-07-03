# Operating Lane Boundaries — Packaging, GTM, and Operations

> **Issue**: [#832](https://github.com/Conxian/conxian-business/issues/832) — Sharpen routing boundaries between packaging, GTM, and operations lanes
> **Status**: Canonical
> **Last updated**: 2026-07-03

## Purpose

This document defines explicit, durable boundaries between three operating lanes:

| Lane | Primary Function | Owns |
|------|-----------------|------|
| **Packaging** | Define doctrine — what we offer, to whom, at what price, with what evidence | Product architecture, commercial model, buyer journey, pricing logic |
| **GTM (Go-to-Market)** | Execute outward-facing work — qualified conversations, demos, pilots, proposals | Pipeline generation, buyer engagement, deal execution, marketing |
| **Operations** | Support transition and coordination — CI/CD, release governance, metrics, runbooks | Infrastructure, deployment, monitoring, promotion pipeline, scorecard tracking |

These lanes replace the previous ambiguous overlap where operations acted as a parallel growth lane rather than a supporting function.

## Lane Definitions

### Packaging Lane

**Core obligation**: Define the commercial doctrine set and keep it aligned with implementation truth.

**Owned artifacts**:
- Commercial packaging matrix (what's in each offer tier)
- Pricing and packaging doctrine
- Customer consumption journeys
- Buyer personas and qualification criteria
- Public-safe executive derivative / one-pager

**Boundary rules**:
- Packaging defines WHAT is offered; GTM defines HOW it is sold
- Pricing logic must not drift from implementation truth (what the code actually does)
- Gateway, Wallet, and SDK remain the primary offer structure
- Changes to the offer structure require packaging lane approval

**Dependencies**:
- Reads from: Architecture docs, REPO_PORTFOLIO.md, TRUST_AND_READINESS_VERIFICATION.md
- Does NOT own: Implementation code, deployment pipelines, operational metrics

### GTM (Go-to-Market) Lane

**Core obligation**: Execute qualified commercial motion against the packaging doctrine.

**Owned artifacts**:
- Qualified conversation tracking
- Demo and pilot proposal pipeline
- Proof assets (claim-safe, evidence-backed)
- Buyer engagement metrics and follow-up quality
- Remote-first growth doctrine

**Boundary rules**:
- GTM executes outward-facing work; it does not define the offer
- GTM metrics feed into the weekly growth-driver review but do not replace BOS operational metrics
- GTM claims about the product must reference TRUST_AND_READINESS_VERIFICATION.md (no over-claims)
- Demo and pilot environments must match current implementation state, not target-state

**Dependencies**:
- Reads from: Packaging doctrine, TRUST_AND_READINESS_VERIFICATION.md, Developer Quickstart
- Does NOT own: Product architecture, CI/CD pipelines, release governance

### Operations Lane

**Core obligation**: Support transition and coordination without acting as a parallel growth lane.

**Owned artifacts**:
- CI/CD pipeline (Conxian Unified CI)
- Release governance and promotion pipeline (dev → staged → main)
- BOS operational metrics (C_R, O_C, V_X, A_S, N_E)
- Deployment runbooks and rollback procedures
- Contamination guard and ZSE enforcement
- Submodule integrity and repo hygiene
- Incident response and observability

**Boundary rules**:
- Operations supports GTM and Packaging; it does not drive commercial decisions
- Operational metrics (C_R, O_C, V_X, A_S, N_E) are system-health metrics, NOT growth metrics
- Operations owns the promotion pipeline; Packaging and GTM consume release artifacts
- Infrastructure decisions are made by Operations; commercial implications are communicated to Packaging

**Dependencies**:
- Reads from: Architecture docs, deployment plans, Linear runbooks
- Does NOT own: Commercial strategy, buyer pipeline, pricing, marketing

## Cross-Lane Coordination

### Weekly Operating Loop

| Cadence | Lane | Activity |
|---------|------|----------|
| Weekly | GTM | Growth-driver metrics review (qualified conversations, demos, pilots, proofs) |
| Weekly | Operations | BOS metric review (C_R, O_C, V_X, A_S, N_E) |
| Weekly | Packaging | Doctrine alignment check (offers match implementation) |
| Bi-weekly | All | Cross-lane sync: blockers, readiness, promotion decisions |

### Escalation Path

| Scenario | Escalate To | Rationale |
|----------|------------|-----------|
| Buyer requests feature outside current offer | Packaging | May require doctrine update |
| CI pipeline blocks release needed for demo | Operations → GTM | Operations owns pipeline; GTM owns demo schedule |
| Implementation diverges from packaging claims | Packaging → Operations | Packaging defines truth; Operations enforces it |
| Metric signals potential over-claim risk | GTM → Packaging | GTM must not outrun evidence |
| Security or compliance issue | Operations | Operations owns incident response |

## Anti-Patterns (Explicitly Prohibited)

| Anti-Pattern | Why It's Wrong |
|-------------|----------------|
| Operations making pricing decisions | Operations supports; Packaging defines |
| GTM rewriting product architecture docs | GTM consumes architecture; Packaging owns it |
| Packaging committing CI/CD changes directly | Packaging may request; Operations implements |
| GTM claiming "production-ready" without Operations verification | Trust claims must be evidence-backed |
| Operations tracking commercial pipeline metrics | That's GTM's lane; Operations owns system health |
| Any lane bypassing the promotion pipeline | dev → staged → main is non-negotiable |

## Alignment with Existing Architecture

These lane boundaries are derived from and consistent with:

- **Three-Lane Runtime Deployment Architecture**: Community, Business-managed, and Enterprise lanes define deployment ownership; operating lanes (Packaging, GTM, Operations) define organizational ownership
- **Portfolio Business-Unit Map**: Conxius (B2C), CSF (Protocol), Fusion (B2B/B2G), Nexus (State) are the four business units; operating lanes cut across them
- **BOS Preserve/Enhance/Replace Gap Matrix**: Strategy artifacts live in Linear (ZSE); public-safe pointers only in Git

## Related Documents

- [Three-Lane Runtime Deployment Architecture](architecture/THREE_LANE_RUNTIME_DEPLOYMENT_ARCHITECTURE.md)
- [Portfolio Business-Unit Map](PORTFOLIO_BUSINESS_UNIT_MAP.md)
- [Trust & Readiness Verification](TRUST_AND_READINESS_VERIFICATION.md)
- [Boundary Decision Log](BOUNDARY_DECISION_LOG.md)
- [BOS Preserve/Enhance/Replace Gap Matrix](architecture/BOS_PRESERVE_ENHANCE_REPLACE_GAP_MATRIX.md)
