# CON-137: Community funding model for system delivery

This document is the policy artifact for [CON-137](https://linear.app/conxian-labs/issue/CON-137/community-funding-model-for-system-delivery).

It defines which work can be community-funded, which work must remain internal-only, and how to size bounties in a consistent, reviewable way.

## Definitions

- **Community-contributable**: work that external contributors may submit via PR, but payout is not implied.
- **Community-funded**: work that is explicitly funded and payable via **ConxianCSF**, where the sole source of bounty funds is the **ALEX launch path**.

Until ConxianCSF is verifiably deployed and ALEX launch-path funding is enabled, treat all external contributions as community-contributable only.

## Funding constraints (normative)

1. Do not advertise an issue as a paid bounty unless it is ConxianCSF-backed and ALEX-funded.
   - Concretely: do not claim/label it as funded, do not publish payout amounts, and do not apply the `Bounty Open` label (see [`BOUNTY_WORKFLOW.md`](./BOUNTY_WORKFLOW.md)) unless the ConxianCSF/ALEX gates are met.
   - Eligibility classification (community-contributable vs internal-only) is allowed and is not a payout promise.
2. Maintainers MUST NOT request, confirm, or act on payout instructions (addresses, payment rails, etc.) in issue threads.
3. Payout-enabling controls remain maintainer-only (see [`MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`](./MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md)).

## Eligibility: which work can be community-funded

An issue may be eligible for community funding only if all of the following are true:

1. It has PR-shaped acceptance criteria that can be validated from the repo (tests/docs/screenshots) without privileged access.
2. It requires no secrets, privileged deployment access, signer/key handling, or treasury/principal changes.
3. It is not classified as internal-only, security-sensitive, or payout-gated.

Examples of commonly eligible categories:

- Docs/specs/diagrams that do not disclose sensitive ops.
- UI/UX and SDK ergonomics that do not touch wallet/signer/security-critical flows.
- “Data-shape only” adapters (encoders/decoders, schema mapping, validation) with deterministic tests.
- Reproducible bug fixes in non-sensitive areas.

## Internal-only: which work must never be community-funded

The following categories remain internal-only even if they are “code work”:

- Deployment, release gating, and mainnet cutover runbooks.
- Wallet/signer/key material or any signing flows.
- Treasury, operational principal management, payout controls, and payout enablement.
- Security-sensitive work (authn/authz, permissions, coordinated disclosure fixes).
- Operational configuration or anything that would require disclosing “how production is run.”

If an issue is covered by [`CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md`](./CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md), that classification is the source of truth for whether it is externally claimable at all; this document only further constrains which claimable issues may also be treated as community-funded.

## Claim discipline (anti-parking)

Claim semantics and timeboxing follow the canonical workflow in [`BOUNTY_WORKFLOW.md`](./BOUNTY_WORKFLOW.md) (status model, `/claim` flow, and timeouts). This funding model only adds that an issue must first pass the eligibility gate above before any claim can be treated as community-funded.

## Bounty sizing rubric (Bounty Points)

Size bounties off **reviewable delivery**, not hours spent.

### Step 0 — eligibility gate

If the issue fails eligibility (see above), it is not community-funded and must not be marked or communicated externally as a community-funded bounty or given a public BP size. Internal planning estimates are allowed, but must not be framed as payout promises.

### Step 1 — base size

Pick the smallest base size (S/M/L) that matches the acceptance criteria. If the work would naturally size as XL, treat that as a decomposition signal and split it into multiple issues before assigning BP.

| Size | Base BP | Typical “done” shape |
|---|---:|---|
| S | 5 | Small doc/spec change or isolated fix; low review load |
| M | 10 | Feature slice or adapter module; tests included |
| L | 20 | Multi-module but still reviewable; integration tests or end-to-end local sim |

BP = “Bounty Points” (token-agnostic).

### Step 2 — multipliers

Apply multipliers for review cost and priority (round to nearest 5 BP).

**Review/Risk multiplier (R)** (review complexity; not “security-sensitive” work)

- Low = 1.0
- Medium = 1.25
- High = 1.5

**Impact/Priority multiplier (P)**

- Nice-to-have = 0.75
- Unblocks internal deliverable = 1.0
- Critical unblocker = 1.25

**Formula**

`TotalBP = BaseBP * R * P` (round to nearest 5)

### Step 3 — limits

- Do not publish base sizes above `L` (BaseBP > 20).
- Treat any sizing that rounds to **40 BP** (or higher) as an “XL” smell and split the work into multiple S/M/L issues before marking them community-funded; there is intentionally no XL row in the base-size table for a single bounty.

## ConxianCSF mapping (post-ALEX)

Once ConxianCSF is live and ALEX funding is the active bounty source of funds, store the bounty entry with:

- `issue_url` (Linear + GitHub/PR links when applicable)
- `total_bp`
- `max_payout` (derived from a governance-set conversion rate)
- `expiry` (explicit timebox)
- `acceptance_criteria_ref`
- `maintainer_reviewer`

## References

- [`BOUNTY_WORKFLOW.md`](./BOUNTY_WORKFLOW.md)
- [`CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md`](./CON-231_BOUNTY_CLASSIFICATION_2026-04-12.md)
- [`MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md`](./MAINTAINER_PAYOUT_ENABLEMENT_RUNBOOK.md)
