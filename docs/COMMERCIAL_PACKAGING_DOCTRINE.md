# Commercial Packaging Doctrine — Offer Structure, Pricing, and Customer Journey

> **Issue**: [#829](https://github.com/Conxian/conxian-business/issues/829) — Maintain canonical packaging, customer journey, and pricing doctrine set
> **Status**: Canonical scaffold (pricing details in Linear per ZSE)
> **Last updated**: 2026-07-03
> **Owner**: Packaging lane (per [OPERATING_LANE_BOUNDARIES.md](OPERATING_LANE_BOUNDARIES.md))

## Purpose

This document defines the canonical commercial packaging doctrine for Conxian-Labs (Pty) Ltd. It ensures:

- The commercial packaging set is internally consistent
- Gateway, Wallet, and SDK remain the primary offer structure
- Pricing, buyer journeys, and packaging logic do not drift from implementation truth

**ZSE note**: This document defines the public-safe offer architecture, customer journey model, and packaging logic. Actual pricing tiers, revenue projections, and partner-specific commercial terms are maintained in the Conxian Linear workspace. See [BOUNDARY_DECISION_LOG.md](BOUNDARY_DECISION_LOG.md).

---

## 1) Primary Offer Structure

Conxian-Labs offers three primary products, consistent across all packaging tiers:

| Product | Type | What It Is | Maturity |
|---------|------|------------|----------|
| **Conxian Gateway** | B2B Infrastructure | ISO 20022 compliance pipe bridging Bitcoin/Stacks with legacy banking. Includes ZKC (Zero-Knowledge Compliance) and SYI (Sovereign Yield Index). | Beta |
| **Conxius Wallet** | B2C / Enterprise Client | Sovereign Bitcoin command center (Android-first, offline-first). Hardware-enforced key custody via StrongBox/TEE. | Stable (v1.9.2) |
| **Conxius Enclave SDK** | Developer Tool | Cross-platform Rust/WASM SDK for hardware enclave abstractions. Enables third-party builders to integrate sovereign key management. | Beta |

**Supporting products** (not primary offers, but available to partners):
- Conxian Nexus: Multi-protocol state verification node (API access)
- Conxius Platform: Local developer deployment orchestrator
- Conxius Orbit: Stacks smart contract deployment toolkit

---

## 2) Packaging Tiers

| Tier | Target Buyer | Includes | Key Differentiator |
|------|-------------|----------|-------------------|
| **Community** | Individual developers, researchers, sovereign users | Wallet (self-custody), SDK (open-source), docs | Self-hosted, bring-your-own infrastructure |
| **Business** | SMEs, fintechs, regional banks | Gateway (managed), Wallet (managed distribution), SDK + support, Nexus API access | Managed hosting, shared compliance controls |
| **Enterprise** | Global banks, governments, large institutions | Gateway (dedicated), Wallet (enterprise distribution), SDK + priority support, Nexus (dedicated), private-cloud deployment | Customer-operated control plane, dedicated infrastructure, custom compliance |

**Invariant**: The same three products (Gateway, Wallet, SDK) form the backbone of every tier. Tiers differ in deployment model, support level, and infrastructure ownership — not in product capability.

---

## 3) Pricing Doctrine

### 3.1 Pricing Principles

1. **Value-based, not cost-plus.** Pricing reflects the structural moat (C_R) and operational savings (O_C reduction), not infrastructure cost.
2. **Sovereignty premium.** Self-hosted (Community) is lowest cost because the user operates their own infrastructure. Managed (Business) and dedicated (Enterprise) include infrastructure and compliance overhead.
3. **No custody tax.** Conxian-Labs is a non-custodial software vendor. Pricing does not include asset-under-management (AUM) fees, custody spreads, or transaction-volume percentages.
4. **Transparent tiers.** Every feature in a tier is documented. No hidden enterprise-only capabilities that should be in lower tiers.

### 3.2 Pricing Model

| Component | Community | Business | Enterprise |
|-----------|-----------|----------|------------|
| **Gateway** | Self-hosted (open-core) | Managed instance, SLA-backed | Dedicated instance, custom SLA |
| **Wallet** | Self-hosted build | Managed distribution, update channel | Enterprise distribution, custom branding |
| **SDK** | Open-source (Apache 2.0 / BSL) | Support SLA, prioritized fixes | Dedicated support, custom integrations |
| **Nexus** | Self-hosted | Shared API access | Dedicated node |
| **Support** | Community (GitHub, docs) | Business-hours, email/Slack | 24/7, dedicated account manager |
| **Compliance** | Self-assessment | ZKC reports included | Custom compliance pipeline |

**ZSE boundary**: Actual price points, volume discounts, and enterprise contract values are maintained in Linear. Contact [commercial@conxian-labs.com] for current pricing.

### 3.3 Pricing Governance

- Pricing changes require Packaging lane approval
- Pricing must be reviewed against implementation truth quarterly (does the product still do what the price says it does?)
- Any feature gated behind a higher tier must be documented as such in the product's public documentation

---

## 4) Customer Consumption Journey

### 4.1 Journey Stages

| Stage | Community | Business | Enterprise |
|-------|-----------|----------|------------|
| **Discovery** | GitHub, docs, technical content | Inbound, conference, partner referral | Direct outreach, RFP response |
| **Evaluation** | Self-serve: clone, build, test | Guided demo against implementation state | Technical deep-dive, architecture review, proof-of-concept |
| **Onboarding** | Documentation, community support | Managed onboarding, integration support | Dedicated onboarding, custom integration, training |
| **Operation** | Self-operated | Managed operations, monitoring | Dedicated operations, custom monitoring |
| **Expansion** | Community contribution, plugin dev | Additional Gateway capacity, new corridors | Multi-region deployment, custom protocol adapters |

### 4.2 Qualification Criteria

A qualified buyer for each tier must meet:

| Tier | Minimum Criteria |
|------|-----------------|
| **Community** | Technical capability to self-host. No commercial agreement required. |
| **Business** | Registered business entity. Defined use case. Integration timeline. |
| **Enterprise** | Institutional procurement process. Security review requirements. Compliance jurisdiction identified. |

### 4.3 Pilot Path

1. **Scope definition**: What Gateway corridors, Wallet features, or SDK integrations will be exercised
2. **Technical validation**: Deploy against current implementation state (not target-state)
3. **Success criteria**: Defined mutually; measured objectively
4. **Duration**: 30-90 days depending on complexity
5. **Exit**: Production agreement, extended pilot, or close-out with findings

---

## 5) Public-Safe Executive Derivative

### One-Pager Template

The following is the canonical one-pager structure for external use (investors, partners, media). Fill from this doctrine; do not invent new claims.

```markdown
# Conxian-Labs: Sovereign-First Financial Infrastructure

**What we build**: Non-custodial financial operating system for the Bitcoin ecosystem.

**Three products**:
- **Gateway**: ISO 20022 compliance pipe — bridge Bitcoin to legacy banking without custody
- **Wallet**: Sovereign Bitcoin command center — hardware-enforced key custody (StrongBox/TEE)
- **SDK**: Cross-platform enclave abstractions — let developers build sovereign apps

**Three tiers**: Community (self-hosted), Business (managed), Enterprise (dedicated)

**What makes us different**:
- Keys never leave user hardware — zero custody, by design
- Cryptographic proof of correct operation via BitVM2 verification
- Open-core: verification is public, operational detail is internal
- Honest maturity: Wallet is Stable, Gateway is Beta — no over-claims

**Who it's for**: Banks, fintechs, governments, and developers who need Bitcoin-native infrastructure without surrendering sovereignty.

**Status**: Active. CI 9/9 green. Conxius Wallet v1.9.2 (Stable). ConxianCSF pre-mainnet.

**Contact**: [commercial@conxian-labs.com]
```

---

## 6) Doctrine Alignment Rules

1. **Gateway, Wallet, SDK** are the only primary offers. Do not create new primary product categories without Packaging lane approval.
2. **Maturity labels must match implementation.** If the TRUST_AND_READINESS_VERIFICATION.md says Beta, packaging says Beta.
3. **Pricing must not drift from product.** If a feature is removed or changed, pricing must be reviewed.
4. **Customer journey stages must match operational readiness.** Do not offer "managed operations" for a component that lacks monitoring and rollback runbooks.
5. **Public-safe only in Git.** Pricing figures, partner-specific terms, and revenue projections live in Linear.

---

## 7) Review Cadence

| Review | Frequency | Owner |
|--------|-----------|-------|
| Offer structure alignment | Quarterly | Packaging lane lead |
| Pricing vs implementation truth | Quarterly | Packaging + Operations |
| Customer journey accuracy | Bi-annually | Packaging + GTM |
| Executive one-pager refresh | Per major release | Packaging lane lead |

---

## Related Documents

- [Operating Lane Boundaries](OPERATING_LANE_BOUNDARIES.md)
- [Trust & Readiness Verification](TRUST_AND_READINESS_VERIFICATION.md)
- [Trust & Proof Messaging](TRUST_AND_PROOF_MESSAGING.md)
- [Boundary Decision Log](BOUNDARY_DECISION_LOG.md)
- [Weekly Growth-Driver Review](operations/WEEKLY_GROWTH_DRIVER_REVIEW.md)
- [Technical Whitepaper Outline](TECHNICAL_WHITEPAPER_OUTLINE.md)
