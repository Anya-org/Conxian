# Weekly Growth-Driver Metrics Review

> **Issue**: [#831](https://github.com/Conxian/conxian-business/issues/831) — Implement weekly growth-driver metrics review for remote-first execution
> **Status**: Canonical
> **Last updated**: 2026-07-03
> **Owner**: GTM lane (per [OPERATING_LANE_BOUNDARIES.md](OPERATING_LANE_BOUNDARIES.md))

## Purpose

This document defines the weekly growth-driver operating loop for the remote-first commercial motion. It connects commercial progress to a recurring review cadence while ensuring claims stay aligned with implementation readiness and evidence discipline.

## Operating Loop

### Cadence

| Event | When | Duration | Participants |
|-------|------|----------|-------------|
| **GTM metric refresh** | Monday 09:00 UTC | Automated (data pull) | — |
| **GTM weekly review** | Monday 14:00 UTC | 30 min | GTM lead, Packaging rep, Ops observer |
| **BOS metric review** | Monday 15:00 UTC | 30 min | Ops lead, GTM observer (see CON-682) |
| **Cross-lane sync** | Bi-weekly Wednesday | 45 min | All lane leads |

### Rules

1. **No metric outruns evidence.** Every growth claim must reference a verifiable artifact (demo recording, proposal doc, proof asset).
2. **Readiness-gated.** If a component is Beta (per TRUST_AND_READINESS_VERIFICATION.md), growth claims about it must include the Beta qualifier.
3. **Durable artifacts only.** "Had a good call" is not a metric. "Qualified conversation logged with outcome and next step" is.
4. **ZSE boundary.** Metric VALUES (pipeline counts, win rates, revenue projections) stay in Linear/Supabase. Only the review PROCESS and formula DEFINITIONS live in Git.

## Weekly Growth-Driver Metrics

### Primary Metrics (Reported Every Week)

| Metric | Definition | Evidence Required | Target |
|--------|------------|-------------------|--------|
| **Qualified conversations** | Conversations with buyers who match the current packaging persona and qualification criteria | Conversation log with stage, outcome, next step | Growth trend |
| **Demos delivered** | Completed product demonstrations against the current implementation state (not target-state) | Demo recording or demo summary artifact | Growth trend |
| **Pilot proposals submitted** | Formal pilot proposals sent to qualified buyers | Proposal document (public-safe summary; details in Linear) | Growth trend |
| **Pilot starts** | Pilots that have begun with signed agreements | Pilot start date and scope | Growth trend |
| **Proof assets created** | Claim-safe, evidence-backed proof assets (case studies, benchmarks, integration examples) | Link to proof asset | ≥ 1 per week |
| **Claim-safe assets shipped** | Proof assets published to public surfaces after readiness verification | Published URL | ≥ 1 per fortnight |
| **Responsiveness quality** | Average time to first meaningful response for qualified inbound | Timestamped conversation log | < 24 hours |
| **Follow-up quality** | Percentage of conversations with documented follow-up within 5 business days | Conversation log audit | > 90% |

### Secondary Metrics (Contextual, Reported Monthly)

| Metric | Definition | Evidence Required |
|--------|------------|-------------------|
| **Conversion rate** | Qualified conversation → pilot start rate | Pipeline audit |
| **Pilot → production rate** | Pilot completion → production adoption rate | Pilot close-out report |
| **Buyer segment distribution** | Breakdown by institution type, region, use case | Pipeline snapshot (public-safe summary) |
| **Doctrine alignment drift** | Instances where buyer expectations diverged from packaging doctrine | Packaging lane report |

## Cross-Reference: BOS Operational Metrics

The GTM review should cross-reference, not duplicate, the BOS operational metrics defined in [`CON-682_APPROVED_METRIC_SPEC.md`](operations/CON-682_APPROVED_METRIC_SPEC.md):

| BOS Metric | Relevance to GTM | Read During |
|------------|-----------------|-------------|
| **$V_X$** (Execution Velocity) | Indicates whether the engineering pipeline can support GTM commitments | BOS review (Mon 15:00) |
| **$A_S$** (System Autonomy) | Indicates operational maturity — higher autonomy means more reliable demo/pilot environments | BOS review (Mon 15:00) |
| **$C_R$** (Cost of Reproduction) | Structural moat — informs competitive positioning in GTM conversations | BOS review (Mon 15:00) |
| **$O_C$** (Opportunity Cost) | Founder's tax — lower means more capacity for GTM support | BOS review (Mon 15:00) |
| **$N_E$** (Network Effects) | Ecosystem growth — informs total addressable market narrative | BOS review (Mon 15:00) |

## Weekly Review Agenda

### 1) Metric Rollup (5 min)

- Review primary metrics against previous week
- Flag any metric that moved >20% week-over-week (positive or negative)
- Confirm all metrics have evidence artifacts linked

### 2) Pipeline Deep-Dive (10 min)

- Review each active qualified conversation: stage, next step, blocker
- Identify conversations that need Packaging lane input (doctrine questions)
- Identify conversations that need Operations lane input (technical readiness questions)

### 3) Readiness Alignment Check (5 min)

- Cross-reference active demos/pilots against TRUST_AND_READINESS_VERIFICATION.md
- Flag any demo/pilot that uses target-state features not yet implemented
- Confirm all proof assets reference the correct implementation state

### 4) Doctrine Drift Check (5 min)

- Review any buyer requests that fall outside current packaging doctrine
- Escalate to Packaging lane if doctrine may need updating
- Document in Packaging lane backlog

### 5) Actions & Blockers (5 min)

- Assign owners for follow-up actions
- Escalate cross-lane blockers to the bi-weekly sync
- Update the weekly review log (Linear)

## Weekly Review Log Template

```markdown
## GTM Weekly Review — YYYY-MM-DD

### Primary Metrics
| Metric | This Week | Last Week | Δ | Notes |
|--------|-----------|-----------|---|-------|
| Qualified conversations | | | | |
| Demos delivered | | | | |
| Pilot proposals | | | | |
| Pilot starts | | | | |
| Proof assets created | | | | |
| Claim-safe assets shipped | | | | |
| Responsiveness (hrs) | | | | |
| Follow-up quality (%) | | | | |

### BOS Context (from Mon 15:00 review)
| Metric | Current | Trend |
|--------|---------|-------|
| V_X | | |
| A_S | | |
| C_R | | |
| O_C | | |

### Pipeline Highlights
- 

### Readiness Flags
- 

### Actions
- [ ] 
```

## Alignment Rules

1. **GTM metrics are NOT operational metrics.** GTM tracks commercial motion; Operations tracks system health. Do not conflate.
2. **GTM claims must not outrun evidence.** If a feature is Beta, GTM materials must say Beta. See [TRUST_AND_READINESS_VERIFICATION.md](TRUST_AND_READINESS_VERIFICATION.md).
3. **Proof assets are claim-safe by default.** Before publishing any proof asset externally, verify against the Trust & Proof Messaging framework.
4. **Pipeline detail stays in Linear.** The weekly review log template above is for the public-safe process definition. Actual pipeline values and buyer names live in Linear per ZSE.

## Related Documents

- [Operating Lane Boundaries](OPERATING_LANE_BOUNDARIES.md)
- [CON-682 Approved Metric Spec](operations/CON-682_APPROVED_METRIC_SPEC.md)
- [Trust & Readiness Verification](TRUST_AND_READINESS_VERIFICATION.md)
- [Trust & Proof Messaging](TRUST_AND_PROOF_MESSAGING.md)
- [Boundary Decision Log](BOUNDARY_DECISION_LOG.md)
