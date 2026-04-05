# CSF-first operating sequence and proof gates (CON-426)

This document locks the operating order:

1. **ConxianCSF first** (launch + proof discipline)
2. **Creator/community economy second** (builder freedom + payout discipline)
3. **Gateway third** (distribution + UX, anchored to CSF + economy truth)

The goal is to keep launch, economy design, and go-to-market work consistent: **later layers can iterate, but they cannot over-claim or create new trust assumptions ahead of earlier proof gates**.

Canonical trackers:

- Linear: https://linear.app/conxian-labs/issue/CON-426/lock-csf-first-operating-sequence-and-proof-gates

## Terms

**Proof gate**
A decision boundary that is only considered "met" when it has **linked evidence** (commit-pinned docs, reproducible scripts, on-chain txids, or equivalent).

**Claim surface**
Any public or semi-public artifact that can be misunderstood as a guarantee (README, website copy, launch posts, partner decks, pinned repo descriptions, docs).

## Non-negotiable rules

1. **Evidence over assertion**
   - A gate is not satisfied by intent, a roadmap, or a checklist marked complete.
   - If the evidence is not linkable, treat it as not done.

2. **No orphan launch/payout claims**
   - Any claim that implies "live", "mainnet", "payouts enabled", or "revenue live" must cite the specific gate + evidence.
   - For public surfaces, follow `docs/TRUST_AND_PROOF_MESSAGING.md`.

3. **Creator/developer freedom is a core system rule**
   Economy design must encourage participation by builders, users, agents, and system-level operators without requiring discretionary approval.

## Minimum proof gates

These are the smallest set of gates needed to keep the CSF-first sequence aligned.

### Gate A: CSF launch gate (authoritative)

**Gate artifact (canonical):** `docs/CSF_MAINNET_READINESS_GATE.md` (CON-129)

**Decision rule:** Any claim that Conxian is "launched" (or that payouts are "ready") must be consistent with the current `Go / Conditional Go / No-Go` and `payout-readiness` values in CON-129.

**Minimum evidence (examples):**

- Mainnet deploy evidence (txids + contract principals) recorded in the gate.
- Commit-pinned mainnet deployment plan reference.
- Explicit ALEX funding path verification before implying bounty payout certainty.

### Gate B: Creator/community economy gate (freedom + discipline)

This gate exists to ensure the economy is both:

- **freedom-preserving** (permissionless participation), and
- **proof/payout disciplined** (no implied guarantees without enforceable rules + funding proof).

**Decision rules:**

- "Builder incentives" may be discussed as a _proposal_ at any time, but cannot be described as "live" unless the ruleset is anchored to evidence.
- The economy must not require privileged approvals for normal participation (builders/users/agents), except where a narrowly-defined safety boundary is explicitly documented.
- Any payout language must be tied to an explicit funding source and an enforcement mechanism (on-chain or equivalently auditable).

**Minimum evidence (must be linkable):**

- A public-safe ruleset document that answers:
  - what participation means (builder/user/agent/operator)
  - what is earned, when, and under which constraints
  - what is explicitly **not** promised
- A clearly defined enforcement surface (contracts or an auditable service boundary).
- A funding boundary (what source backs payouts, and what happens when it is not available).

### Gate C: Gateway gate (distribution that cannot over-claim)

Gateway work is allowed to proceed early, but it must stay downstream of CSF + economy proof.

**Decision rules:**

- Gateway must not present "live" status, network support, or payout availability in a way that can contradict Gate A or Gate B.
- Gateway interfaces should preferentially expose **verifiable** state (txids, block heights, contract principals, checkpoint hashes) rather than narrative claims.

**Minimum evidence (must be linkable):**

- Gateway configuration and documentation references the exact contract principals / deployment identifiers it is fronting.
- Public-facing status language is consistent with:
  - the CON-129 gate snapshot, and
  - the ruleset status from Gate B.

## Practical claim ladder (for go-to-market alignment)

When in doubt, downshift language to avoid implied guarantees.

- **Before Gate A**: "prototype", "testnet", "research", "draft", "not launched"
- **After Gate A = Conditional Go**: "limited launch", "guarded rollout", "payouts not enabled unless explicitly stated"
- **After Gate A = Go**: "mainnet" claims are allowed only when accompanied by the evidence links referenced in the gate

This does not require all systems to be complete before communication; it requires communication to be **proof-aligned**.
