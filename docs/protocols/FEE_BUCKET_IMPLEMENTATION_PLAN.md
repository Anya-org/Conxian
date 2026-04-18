# Fee-bucket implementation plan (CON-481)

This document translates the current **fee-bucket model** into an implementation plan with:

- a concrete bucket set,
- deterministic ordering rules,
- explicit activation conditions, and
- a clear split between **policy-only** decisions vs **implementation-ready** work.

The plan is grounded in the current Conxian mainnet and ALEX readiness posture as recorded in:

- `docs/CSF_MAINNET_READINESS_GATE.md` (snapshot **2026-04-06**)
- `openspec/changes/external-settlement-proposal-only-tee/*` (yield routing invariants)

## 0) Definitions

- **Fee bucket**: a named allocation of an amount (usually expressed in basis points) to a recipient category.
- **Bucket set**: a deterministic list of buckets that applies to a specific fee or yield flow.
- **Recipient category** (economics separation):
  - **Protocol-owned**: protocol treasury / reserve / insurance / buyback.
  - **Labs-owned**: explicit operator/service compensation (must not be implicitly mixed into protocol treasury).
  - **Founder**: founder royalty / founder vault allocations.
  - **Contributor**: bounties, grants, LP incentives, worker/industrial payouts.
- **BPS math**: basis points, where `10000 = 100%`.

## 1) Bucket sets (canonical)

Conxian currently has two materially different “fee-like” flows that need explicit bucket sets:

1. **Productive streaming (yield routing)**: applies to capital locked as transit bond / escrow.
2. **Captured protocol fees**: applies to protocol-retained fees extracted from protocol actions (DEX/lending/etc).

These are intentionally separated so we can keep “5/5/90 productive streaming” invariant logic independent from CSF / ALEX referral and payout toggles.

### 1.1 Bucket set: `productive_streaming.v1` (5/5/90)

Source of truth:

- “Yield routing invariance” requirement in `openspec/changes/external-settlement-proposal-only-tee/specs/external-settlement-proposal-only-tee/spec.md`.
- Existing data model in `conxian-gateway/pkg/conxian-core/src/settlement.rs` (`ProductiveStreaming` defaults to 5/5/90).

| Order | Bucket name | Category | BPS | Recipient (resolved) | Activation |
|---:|---|---|---:|---|---|
| 1 | `founder_royalty` | Founder | 500 | `operational-treasury` principal key: `founder-vault` | Always on (mainnet) |
| 2 | `ecosystem_reserve` | Protocol-owned | 500 | `operational-treasury` principal key: `ecosystem-reserve-vault` | Always on (mainnet) |
| 3 | `productive_yield` | Contributor | 9000 | Flow-specific beneficiary (see §2.3) | Always on (mainnet) |

Notes:

- Labs-owned buckets are intentionally not part of `productive_streaming.v1`.
- If governance later introduces an explicit operator fee, it must be a new versioned bucket set (e.g., `productive_streaming.v2`) so invariants remain testable.

### 1.2 Bucket set: `captured_protocol_fees.v1` (fee extraction + internal allocation)

Source of truth:

- “Founder’s Cut” carve-out rule: `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md`.
- Internal allocation model: `Conxian/contracts/treasury/cxd-treasury.clar` (6-way split).

This bucket set is defined as **a two-stage deterministic pipeline**:

1. **Stage A (3rd-party / growth distributions)**: applied first, before “captured protocol fees” are computed.
2. **Stage B (captured fee allocation)**: applied to the remaining captured protocol fee amount.

Stage A buckets (policy-gated):

| Order | Bucket name | Category | BPS (of total fee) | Recipient | Activation |
|---:|---|---|---:|---|---|
| A1 | `referrer_reward` | Contributor | 500 | Referrer principal | Requires referral engine + payout readiness |
| A2 | `referee_reward` | Contributor | 500 | Referee principal | Requires referral engine + payout readiness |
| A3 | `protocol_health_lock` | Protocol-owned | 500 | `operational-treasury` principal key: `protocol-health-vault` | Requires policy toggle |

Gate semantics (Stage A):

- Stage A is a **partial carve-out** stage; it is not a full `10000`-BPS split.
- When a policy gate for a Stage A bucket is off, that bucket is disabled (its effective BPS is `0`).
- Stage A BPS values are never renormalized across the remaining buckets.
- Any amount not carved out in Stage A becomes `captured_protocol_fees` and flows into Stage B.

Stage B buckets (implementation-ready, with policy parameters):

1. Compute `captured_protocol_fees = total_fee - sum(stage_A)`.
2. Compute Founder’s Cut as a 10-BPS carve-out on `captured_protocol_fees`:
   - `founders_cut = floor(captured_protocol_fees * 10 / 10000)`
   - `post_cut_captured = captured_protocol_fees - founders_cut`
   - Any rounding remainder stays in protocol custody as part of `post_cut_captured`.
3. Split `post_cut_captured` using the `cxd-treasury` 6-way basis-point policy.

Bucket mapping for Stage B:

- `founders_cut` → **Founder** → `operational-treasury` principal key: `founder-vault`
- `treasury` → **Protocol-owned** → `operational-treasury` (protocol reserve / ops)
- `buyback` → **Protocol-owned** → BME path / buyback vault (implementation-specific)
- `insurance` → **Protocol-owned** → insurance reserve vault
- `bounty` → **Contributor** → ConxianCSF / bounty vault (payout-gated)
- `grant` → **Contributor** → grant vault (payout-gated)
- `lp` → **Contributor** → LP incentives vault / emissions path

Payout-gated semantics (Stage B):

- “Payout-gated” means the bucket still accrues its share on-chain as soon as the corresponding bucket set is active under `GATE_MAINNET_BASELINE`, but withdrawal and downstream payout actions remain disabled until `GATE_PAYOUT_READY_ALEX` is satisfied.

Labs-owned bucket (explicit, optional):

- If Conxian-Labs requires an operator fee, introduce it as an **explicit Stage B bucket** (new version, e.g. `captured_protocol_fees.v2`) and route it to a `labs-opex-vault` principal resolved via `operational-treasury`.
- Do not “hide” Labs compensation inside the protocol treasury bucket.

## 2) Ordering and rounding rules (normative for implementation)

### 2.1 Deterministic ordering

For any fee/yield flow, the implementation MUST:

1. Evaluate buckets in the exact order defined by the bucket set.
2. Use integer math in atomic units of the fee asset.
3. Keep bucket ordering stable across releases; if order or membership changes, bump the bucket set version.

Versioning rule of thumb:

- Bucket-set versions freeze the mechanics (bucket membership, ordering, and computation rules).
- For bucket sets with fixed BPS vectors (e.g., `productive_streaming.v1`), any BPS change should be expressed as a new bucket set version.
- For bucket sets that reference an on-chain policy contract (e.g., the Stage B 6-way split sourced from `cxd-treasury`), percentage changes are treated as policy updates and should be logged/auditable via contract events rather than forcing a bucket set version bump.

### 2.2 Rounding / remainder behavior

To avoid ambiguous “lost unit” behavior:

- For any split stage, compute each bucket amount using integer division.
- For a split stage with total amount `T` and bucket basis points `bps_i`, compute each bucket amount as `amount_i = floor(T * bps_i / 10000)` using the same `T` for all buckets (no sequential “percentage of remaining” computation).
- Track `remainder = total - sum(bucket_amounts)`.

Remainder routing is stage-aware:

- For carve-out stages (e.g., Stage A of `captured_protocol_fees.v1`), `remainder` is the input amount for the next stage (`captured_protocol_fees`) and is not routed to any bucket.
- For terminal stages, route the `remainder` to a specific protocol-owned bucket:
  - `productive_streaming.v1`: route remainder to `ecosystem_reserve`.
  - Stage B (6-way split of `post_cut_captured`): route remainder to `treasury`.

Remainders must never be routed to Labs or Founder.

This matches the Founder’s Cut remainder rule in `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md`.

### 2.3 Beneficiary binding (productive yield)

For `productive_streaming.v1`, the `productive_yield` bucket recipient is flow-specific:

- If the yield is tied to a Job Card / industrial intent, the recipient is the worker/beneficiary principal bound by that intent.
- If the yield is tied to an LP position, the recipient is the LP incentive distribution mechanism.

This recipient must be treated as **input to the flow** (e.g., in the proposal/execution payload), not derived from trigger source.

## 3) Activation conditions (grounded in current reality)

### 3.1 Mainnet and ALEX posture (current snapshot)

As of **2026-04-06**, `docs/CSF_MAINNET_READINESS_GATE.md` records:

- Launch recommendation: `Conditional Go`
- Payout readiness (ALEX-funded bounties): `Not payout-ready`
- Remaining gating items include ALEX funding verification (CON-230) and signer/approval controls (CON-233)

Separately, the gateway’s ALEX execution path is explicitly not live yet (swap returns `501` until signer integration exists).

### 3.2 Bucket activation gates

Define 3 coarse activation gates that implementations can enforce consistently:

1. `GATE_MAINNET_BASELINE`
   - Contracts deployed on mainnet.
   - `operational-treasury` principal registry is populated for required vaults.
   - Enables: `productive_streaming.v1` and non-payout protocol-owned buckets.

2. `GATE_PAYOUT_READY_ALEX`
   - `docs/CSF_MAINNET_READINESS_GATE.md` payout readiness flips to payout-ready (post CON-230 + CON-233).
   - Enables: withdrawal / downstream payout actions for payout-gated buckets that require ALEX funding (bounties/grants), and any referral payouts.
   - This gate must not change the configured routing percentages for Stage B buckets; it only changes whether payouts can be executed.

3. `GATE_OPERATOR_FEE_APPROVED`
   - Explicit governance/policy approval exists for any Labs-owned operator fee.
   - Enables: any Labs-owned fee bucket (only in a versioned bucket set).

## 4) Policy-only vs implementation-ready

### 4.1 Implementation-ready now

These can be built immediately without depending on ALEX payout readiness:

- A shared “bucket set” schema (names, ordering, stage kind (full-split vs carve-out), BPS constraints, remainder rule).
- A routing interface that resolves principals dynamically via `Conxian/contracts/core/operational-treasury.clar` (no hardcoded production addresses).
- `productive_streaming.v1` routing (5/5/90), because it is invariant to trigger source.

### 4.2 Policy-only (must remain gated)

These should not be activated until their gates are explicitly satisfied:

- Stage-A 5/5/5 path (5% `referrer_reward`, 5% `referee_reward`, 5% `protocol_health_lock`) as a live distribution.
- Any ALEX-funded bounty/grant payout semantics.
- Any Labs-owned operator fee bucket and its percentage.
- ALEX liquidity provisioning rules (e.g., “pair 10% proceeds for 6 months”).

## 5) Implementation plan (repo-grounded)

This is the concrete “what to build where” plan.

### 5.1 On-chain (Conxian contracts)

Target locations:

- `Conxian/contracts/core/operational-treasury.clar`
- `Conxian/contracts/treasury/*`

Implementation steps:

1. Define the canonical principal keys in `operational-treasury` for bucket recipients:
   - `founder-vault`
   - `ecosystem-reserve-vault`
   - `protocol-health-vault`
   - `bounty-vault` (or `csf-bounty-vault`)
   - `grant-vault`
   - `lp-incentives-vault`
   - `insurance-vault`
   - (optional, policy-only) `labs-opex-vault`

2. Implement a fee routing surface that:
   - takes `(token, amount, bucket_set_id, flow_recipient)` inputs,
   - derives each stage’s validation rules from the bucket set’s stage-kind metadata (full-split vs carve-out), rather than hardcoding rules for specific bucket sets,
   - validates that each full-split stage (e.g., `productive_streaming.v1`, or the Stage B split of `post_cut_captured`) has BPS that sum to `10000`,
   - treats partial carve-outs (e.g., Stage A of `captured_protocol_fees.v1`) as bounded by `<= 10000` rather than required to sum to `10000`,
   - recomputes all bucket amounts on-chain from the canonical BPS configuration and fails closed if any caller-supplied breakdown disagrees,
   - resolves any role-based recipients through `operational-treasury`,
   - fails closed with explicit errors if a required principal key is missing.

3. Wire `productive_streaming.v1` routing into the lock/escrow primitive so external vs native triggers remain yield-invariant.

4. Keep “captured protocol fees” Stage A referral rewards behind `GATE_PAYOUT_READY_ALEX`.
   - Gate `protocol_health_lock` behind `GATE_MAINNET_BASELINE` plus an explicit policy toggle.

### 5.2 Off-chain (Gateway / proposal lane)

Target locations:

- `conxian-gateway/pkg/conxian-core/src/settlement.rs`
- `conxian-gateway/internal/engine/*` (proposal emission)

Implementation steps:

1. Make bucket computation explicit in the proposal artifact:
   - include the bucket set id and the flow beneficiary binding,
   - optionally include computed bucket amounts for observability and audit,
   - treat any precomputed bucket amounts as advisory only (on-chain routing must recompute and validate).

2. Add a cross-trigger invariant test:
   - “native trigger” vs “external trigger” must compute identical bucket outputs given the same lock type and asset path.

3. Leave ALEX swap execution as fail-closed (501 / explicit error) until signer integration is production-ready.

### 5.3 Derived accounting / oracle surfaces

Bucket routing should emit stable, indexable events so derived stores (Nexus / treasury oracle) can:

- produce a bucket-ledger view for reconciliation, and
- prove that “what dashboards show” is derived from on-chain events.

Per `docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md`, the derived stores must not become correctness dependencies.
