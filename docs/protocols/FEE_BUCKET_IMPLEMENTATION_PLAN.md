# Fee-bucket implementation plan (CON-481)

This document translates the current **fee-bucket model** into an implementation plan with:

- a concrete bucket set,
- deterministic ordering rules,
- deterministic founder-fee decay + protocol/Labs pivot mechanics,
- explicit activation conditions, and
- hybrid SAB-to-DAO governance transition conditions, and
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

These are intentionally separated so productive streaming can evolve through explicit versioned mechanics (`productive_streaming.v1`, `productive_streaming.v2`) while remaining independent from CSF / ALEX referral and payout toggles.

### 1.1 Bucket family: `productive_streaming` (versioned)

#### 1.1.1 `productive_streaming.v1` (legacy, unchanged; 5/5/90 with founder-decay bracket)

Source of truth:

- “Yield routing invariance” requirement in `openspec/changes/external-settlement-proposal-only-tee/specs/external-settlement-proposal-only-tee/spec.md`.
- Existing data model in `conxian-gateway/pkg/conxian-core/src/settlement.rs` (`ProductiveStreaming` defaults to 5/5/90).

| Order | Bucket name | Category | BPS | Recipient (resolved) | Activation |
|---:|---|---|---:|---|---|
| 1 | `founder_royalty` | Founder | `founder_bps(year)` | `operational-treasury` principal key: `founder-vault` | Always on (mainnet) |
| 2 | `founder_delta_to_labs` | Labs-owned | `labs_pivot_bps(year) = 500 - founder_bps(year)` | `operational-treasury` principal key: `conxian-labs-wallet` | Always on (mainnet) |
| 3 | `ecosystem_reserve` | Protocol-owned | 500 | `operational-treasury` principal key: `ecosystem-reserve-vault` | Always on (mainnet) |
| 4 | `productive_yield` | Contributor | 9000 | Flow-specific beneficiary (see §2.3) | Always on (mainnet) |

Normative compatibility note:

- `productive_streaming.v1` remains unchanged for legacy compatibility.
- `founder_royalty + founder_delta_to_labs` is always exactly `500` BPS, preserving top-level 5/5/90 invariants.
- `conxian-labs-wallet` is a principal **key** resolved through `operational-treasury` (no hardcoded address).

Founder-decay schedule (normative, unchanged):

- `launch_ts` = immutable launch timestamp set when `productive_streaming.v1` is activated.
- `year = floor((block_ts - launch_ts) / SECONDS_PER_YEAR) + 1`.
- If `block_ts < launch_ts`, routing MUST fail closed with an explicit epoch error.

Founder bracket (`founder_bps(year)`):

- Years `1..3`: `500` (5.00%)
- Year `4`: `400` (4.00%)
- Year `5`: `300` (3.00%)
- Year `6`: `200` (2.00%)
- Year `7`: `100` (1.00%)
- Year `8+`: `100` (1.00%) — founder allocation is capped at the year-7 floor.

Labs pivot bracket:

- `labs_pivot_bps(year) = 500 - founder_bps(year)`
- Years `1..3`: `0`
- Year `4`: `100`
- Year `5`: `200`
- Year `6`: `300`
- Year `7+`: `400`

This ensures founder decay is deterministic and the delta from the initial 5% founder allocation is always routed to the `conxian-labs-wallet` principal key.

#### 1.1.2 `productive_streaming.v2` (Option 1: widened founder bracket + deterministic decay-delta routing)

`productive_streaming.v2` introduces a widened founder-decay bracket (`1000` BPS max vs `500` in v1) while preserving deterministic recipient routing.

| Order | Bucket name | Category | BPS | Recipient (resolved) | Activation |
|---:|---|---|---:|---|---|
| 1 | `founder_royalty` | Founder | `founder_bps_v2(year)` | `operational-treasury` principal key: `founder-vault` | When `productive_streaming.v2` is selected |
| 2 | `founder_decay_to_protocol` | Protocol-owned | `protocol_decay_bps(year) = min(500, 1000 - founder_bps_v2(year))` | `operational-treasury` principal key: `ecosystem-reserve-vault` | When `productive_streaming.v2` is selected |
| 3 | `founder_delta_to_labs` | Labs-owned | `labs_pivot_bps_v2(year) = max(0, 500 - founder_bps_v2(year))` | `operational-treasury` principal key: `conxian-labs-wallet` | When `productive_streaming.v2` is selected |
| 4 | `ecosystem_reserve_base` | Protocol-owned | 500 | `operational-treasury` principal key: `ecosystem-reserve-vault` | When `productive_streaming.v2` is selected |
| 5 | `productive_yield` | Contributor | 8500 | Flow-specific beneficiary (see §2.3) | When `productive_streaming.v2` is selected |

Founder bracket (`founder_bps_v2(year)`):

- Year `1`: `1000` (10.00%)
- Year `2`: `750` (7.50%)
- Year `3`: `550` (5.50%)
- Year `4`: `400` (4.00%)
- Year `5+`: `max(35, 400 - 50 * (year - 4))`
  - This is a deterministic `-0.5` percentage-point/year decay from year 4 onward.
  - Floor clamp is explicit at `35` BPS (`0.35%`).

Deterministic decay-delta routing arithmetic (`productive_streaming.v2`):

- `decay_delta_bps(year) = 1000 - founder_bps_v2(year)`
- `protocol_decay_bps(year) = min(500, decay_delta_bps(year))`
- `labs_pivot_bps_v2(year) = max(0, decay_delta_bps(year) - 500)` (equivalent to `max(0, 500 - founder_bps_v2(year))`)
- Invariant: `founder_bps_v2 + protocol_decay_bps + labs_pivot_bps_v2 = 1000` for all valid years.

Economic interpretation for v2 deltas:

- Founder decay from `10.00%` down to `5.00%` routes to protocol treasury (`ecosystem-reserve-vault`) via `founder_decay_to_protocol`.
- Any decay below `5.00%` routes to Labs treasury key (`conxian-labs-wallet`) via `founder_delta_to_labs`.

#### 1.1.3 Guardrails (normative)

- **Explicit floor clamp:** `founder_bps_v2(year)` MUST be clamped at `35` BPS and must never route below `0.35%`.
- **Deterministic year boundaries:**
  - `year = floor((block_ts - launch_ts) / SECONDS_PER_YEAR) + 1`
  - Year `N` applies over `[launch_ts + (N-1)*SECONDS_PER_YEAR, launch_ts + N*SECONDS_PER_YEAR)`.
  - If `block_ts < launch_ts`, routing MUST fail closed with an explicit epoch error.
- **Governance controls (no ad hoc upward changes):**
  - `productive_streaming.v1` mechanics remain frozen for legacy compatibility.
  - Any upward change to founder allocation in active schedules MUST NOT be applied ad hoc.
  - Upward changes require both DAO quorum + timelock controls (`GATE_DAO_POLICY_QUORUM`) and a new versioned bucket set (for example `productive_streaming.v3`).

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
- For bucket sets with fixed BPS vectors, any BPS change should be expressed as a new bucket set version.
- For schedule-driven mechanics (e.g., `founder_bps(year)` in `productive_streaming.v1`, or `founder_bps_v2(year)` + delta routing in `productive_streaming.v2`), the schedule functions and constants (`launch_ts`, year brackets, decay rate, floor clamp, routing thresholds) are part of the frozen mechanics; any change requires a new bucket set version.
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
  - `productive_streaming.v2`: route remainder to `ecosystem_reserve_base`.
  - Stage B (6-way split of `post_cut_captured`): route remainder to `treasury`.

Remainders must never be routed to Labs or Founder.

This matches the Founder’s Cut remainder rule in `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md`.

### 2.2.1 Founder-decay arithmetic and fail-closed checks (`productive_streaming.v1`)

For input amount `T` and computed year `Y`, implementations MUST:

1. Compute `founder_bps = founder_bps(Y)` and `labs_bps = 500 - founder_bps`.
2. Validate invariant `founder_bps + labs_bps = 500`; otherwise fail closed.
3. Resolve both principal keys via `operational-treasury`:
   - `founder-vault`
   - `conxian-labs-wallet`
4. Fail closed if either key is missing or invalid.
5. Compute bucket amounts from the same `T`:
   - `founder_amount = floor(T * founder_bps / 10000)`
   - `labs_amount = floor(T * labs_bps / 10000)`
   - `ecosystem_amount = floor(T * 500 / 10000)`
   - `productive_amount = floor(T * 9000 / 10000)`
6. Route `remainder = T - (founder_amount + labs_amount + ecosystem_amount + productive_amount)` to `ecosystem_reserve`.

Implementations MUST NOT infer or substitute recipient principals from off-chain config if the canonical key lookup fails.

### 2.2.2 Founder-decay arithmetic and fail-closed checks (`productive_streaming.v2`)

For input amount `T` and computed year `Y`, implementations MUST:

1. Compute `founder_bps = founder_bps_v2(Y)` using the v2 schedule.
2. Enforce guardrails on founder schedule output:
   - `founder_bps <= 1000`
   - `founder_bps >= 35`
3. Compute deterministic decay-routing basis points:
   - `decay_delta_bps = 1000 - founder_bps`
   - `protocol_decay_bps = min(500, decay_delta_bps)`
   - `labs_bps = max(0, decay_delta_bps - 500)`
4. Validate invariant `founder_bps + protocol_decay_bps + labs_bps = 1000`; otherwise fail closed.
5. Resolve principal keys via `operational-treasury`:
   - `founder-vault`
   - `ecosystem-reserve-vault`
   - `conxian-labs-wallet`
6. Fail closed if any required key is missing or invalid.
7. Compute bucket amounts from the same `T`:
   - `founder_amount = floor(T * founder_bps / 10000)`
   - `protocol_decay_amount = floor(T * protocol_decay_bps / 10000)`
   - `labs_amount = floor(T * labs_bps / 10000)`
   - `ecosystem_base_amount = floor(T * 500 / 10000)`
   - `productive_amount = floor(T * 8500 / 10000)`
8. Route `remainder = T - (founder_amount + protocol_decay_amount + labs_amount + ecosystem_base_amount + productive_amount)` to `ecosystem_reserve_base`.

Implementations MUST NOT infer or substitute recipient principals from off-chain config if the canonical key lookup fails.

### 2.3 Beneficiary binding (productive yield)

For `productive_streaming.v1` and `productive_streaming.v2`, the `productive_yield` bucket recipient is flow-specific:

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
   - Enables: `productive_streaming.v1` (legacy default), `productive_streaming.v2` (when explicitly selected), and non-payout protocol-owned buckets.

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
- `productive_streaming.v2` routing (10% widened founder bracket + deterministic protocol/Labs decay routing), with v1 preserved unchanged for legacy positions.

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
   - `conxian-labs-wallet`
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
   - computes schedule outputs on-chain for both productive-streaming versions:
     - `productive_streaming.v1`: `founder_bps(year)`, `labs_pivot_bps(year)`
     - `productive_streaming.v2`: `founder_bps_v2(year)`, `protocol_decay_bps(year)`, `labs_pivot_bps_v2(year)`
   - validates that each full-split stage (e.g., `productive_streaming.v1`, or the Stage B split of `post_cut_captured`) has BPS that sum to `10000`,
   - treats partial carve-outs (e.g., Stage A of `captured_protocol_fees.v1`) as bounded by `<= 10000` rather than required to sum to `10000`,
   - recomputes all bucket amounts on-chain from the canonical BPS configuration and fails closed if any caller-supplied breakdown disagrees,
   - resolves any role-based recipients through `operational-treasury`,
   - fails closed with explicit errors if a required principal key is missing.

3. Wire productive-streaming routing into the lock/escrow primitive so external vs native triggers remain yield-invariant for both `productive_streaming.v1` and `productive_streaming.v2`.

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

## 6) Hybrid governance dynamics (SAB execution, DAO policy handoff)

This plan follows the governance split in:

- `docs/BOS_WALLET_CONTROL_MODEL.md`
- `docs/architecture/BOS_TREASURY_AND_YIELD_INTEGRATION_ARCHITECTURE.md`

Baseline model:

- SAB authorities execute allowlisted operational flows.
- DAO authorities mutate policy through `DAO_TIMELOCK` once quorum and timelock controls are live.

### 6.1 DAO handoff trigger (`GATE_DAO_POLICY_QUORUM`)

`GATE_DAO_POLICY_QUORUM` is true only when all are satisfied:

1. `DAO_TIMELOCK` is active and bound to policy-mutating routes.
2. `DAO_POLICY_AUTHORITY` signer quorum is verified per BOS wallet policy (target 3-of-5 end state).
3. Emergency pause/recovery routes remain independent of routine policy mutation routes.
4. The gate evidence is recorded in the active readiness/governance evidence surface.

### 6.2 Control transition semantics

- Before `GATE_DAO_POLICY_QUORUM`: routing executes under SAB operations with frozen mechanics for whichever productive-streaming version is active (`productive_streaming.v1` for legacy; `productive_streaming.v2` when explicitly selected).
- After `GATE_DAO_POLICY_QUORUM`: changes to fee-routing policy surfaces (including founder-decay schedule changes) must be timelock-governed by DAO authority.
- In both modes, value-bearing execution remains BOS-controlled; dashboards remain propose/observe surfaces only.

For avoidance of doubt:

- No ad hoc upward founder-rate changes are permitted on active schedule versions.
- Any upward founder-rate change requires quorum + timelock and a new bucket-set version.

### 6.3 Fail-closed transition behavior

- If quorum evidence is stale/missing, policy mutation routes stay disabled.
- Routing continues using the last valid on-chain configuration; no implicit fallback to ad hoc principals.
- Any missing timelock/admin binding must abort policy updates.
