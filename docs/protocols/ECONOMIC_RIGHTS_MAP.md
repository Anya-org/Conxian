# ECONOMIC_RIGHTS_MAP (canonical registry)

This document is the canonical **human-readable** registry for Conxian economic-rights routing.

Machine-readable companion:

- `docs/protocols/data/ECONOMIC_RIGHTS_MAP.v1.csv`

Schema contract (v1):

- `flow`
- `bucket`
- `principal`
- `beneficiary`
- `gate`
- `change-authority`
- `source`

## Canonical rights map (v1)

| flow | bucket | principal | beneficiary | gate | change-authority | source |
| --- | --- | --- | --- | --- | --- | --- |
| `productive_streaming.v1` | `founder_royalty` | `operational-treasury::founder-vault` | Founder royalty vault | `GATE_MAINNET_BASELINE` | Frozen mechanics per bucket-set version; SAB executes within fixed permissions before DAO handoff; policy mutation requires `DAO_TIMELOCK` once `GATE_DAO_POLICY_QUORUM` is true. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.1, §6.1-§6.2); `docs/BOS_WALLET_CONTROL_MODEL.md` (§Governance boundary) |
| `productive_streaming.v1` | `founder_delta_to_labs` | `operational-treasury::conxian-labs-wallet` | Labs treasury key (founder-decay delta) | `GATE_MAINNET_BASELINE` | Same as above; no ad hoc upward founder changes on active versions. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.1, §1.1.3, §6.2) |
| `productive_streaming.v1` | `ecosystem_reserve` | `operational-treasury::ecosystem-reserve-vault` | Protocol reserve | `GATE_MAINNET_BASELINE` | SAB operational execution pre-quorum; DAO timelock authority for policy-level changes post-quorum. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.1, §3.2, §6.2); `docs/BOS_WALLET_CONTROL_MODEL.md` (§Governance boundary) |
| `productive_streaming.v1` | `productive_yield` | `flow_recipient` (flow payload input) | Worker/beneficiary principal or LP incentive route bound by flow intent | `GATE_MAINNET_BASELINE` | Recipient is input-bound; policy-surface changes require governance authority, not trigger-source inference. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.1, §2.3) |
| `productive_streaming.v2` | `founder_royalty` | `operational-treasury::founder-vault` | Founder royalty vault (v2 schedule) | `GATE_MAINNET_BASELINE` + explicit selection of `productive_streaming.v2` | Frozen mechanics per version; any upward founder-rate change requires new version + quorum/timelock gate. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2, §1.1.3, §6.1) |
| `productive_streaming.v2` | `founder_decay_to_protocol` | `operational-treasury::ecosystem-reserve-vault` | Protocol reserve from founder-decay delta (10%→5% region) | `GATE_MAINNET_BASELINE` + explicit selection of `productive_streaming.v2` | Same versioned-mechanics governance rule as v2 family. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2) |
| `productive_streaming.v2` | `founder_delta_to_labs` | `operational-treasury::conxian-labs-wallet` | Labs treasury key from founder-decay delta below 5% | `GATE_MAINNET_BASELINE` + explicit selection of `productive_streaming.v2` | Same versioned-mechanics governance rule as v2 family. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2, §1.1.3) |
| `productive_streaming.v2` | `ecosystem_reserve_base` | `operational-treasury::ecosystem-reserve-vault` | Protocol reserve base allocation | `GATE_MAINNET_BASELINE` + explicit selection of `productive_streaming.v2` | SAB executes active policy; DAO mutates policy surfaces after timelock handoff. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2, §6.2) |
| `productive_streaming.v2` | `productive_yield` | `flow_recipient` (flow payload input) | Worker/beneficiary principal or LP incentive route bound by flow intent | `GATE_MAINNET_BASELINE` + explicit selection of `productive_streaming.v2` | Recipient binding is payload-defined; governance controls policy changes only. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2, §2.3) |
| `captured_protocol_fees.v1.stage_a` | `referrer_reward` | Referrer principal | Referrer | `GATE_PAYOUT_READY_ALEX` (and referral engine readiness) | Policy and gate lifecycle follow SAB-execution/DAO-policy boundary; gate toggles execution readiness, not BPS math. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.1-§3.2); `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md` (§5-5-5 Referral Engine) |
| `captured_protocol_fees.v1.stage_a` | `referee_reward` | Referee principal | Referee | `GATE_PAYOUT_READY_ALEX` (and referral engine readiness) | Same as `referrer_reward`. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2); `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md` (§5-5-5 Referral Engine) |
| `captured_protocol_fees.v1.stage_a` | `protocol_health_lock` | `operational-treasury::protocol-health-vault` | Protocol health reserve | `GATE_MAINNET_BASELINE` + explicit policy toggle | Policy toggle is governance-owned; execution path remains gate constrained. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2, §5.1) |
| `captured_protocol_fees.v1.stage_b` | `founders_cut` | `operational-treasury::founder-vault` | Founder vault (10 bps carve-out from captured fees) | `GATE_MAINNET_BASELINE` | Founder-cut mechanics are normative and version-bound; policy mutations require timelocked governance after handoff. | `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md` (§Founder's Cut Fee Logic); `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2) |
| `captured_protocol_fees.v1.stage_b` | `treasury` | `cxd-treasury::treasury` (resolved to protocol treasury principal) | Protocol reserve / operations | `GATE_MAINNET_BASELINE` | Percent vector is policy-managed on-chain; authority transitions from SAB execution controls to DAO policy timelock governance. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §2.1, §6.2); `docs/BOS_WALLET_CONTROL_MODEL.md` (§Governance boundary) |
| `captured_protocol_fees.v1.stage_b` | `buyback` | `cxd-treasury::buyback` (policy-resolved destination) | Buyback route / reserve | `GATE_MAINNET_BASELINE` | Policy surface is governance-controlled; concrete destination principal is a governance-approved parameter. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §2.1) |
| `captured_protocol_fees.v1.stage_b` | `insurance` | `cxd-treasury::insurance` -> `operational-treasury::insurance-vault` | Insurance reserve | `GATE_MAINNET_BASELINE` | Same governance boundary as Stage B policy rows. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §5.1) |
| `captured_protocol_fees.v1.stage_b` | `bounty` | `cxd-treasury::bounty` -> `operational-treasury::bounty-vault` | Contributor bounty pool | Accrual under `GATE_MAINNET_BASELINE`; payout execution requires `GATE_PAYOUT_READY_ALEX` | Payout execution remains gate-controlled while policy parameters stay timelock-governed post-handoff. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2, §5.1) |
| `captured_protocol_fees.v1.stage_b` | `grant` | `cxd-treasury::grant` -> `operational-treasury::grant-vault` | Contributor grant pool | Accrual under `GATE_MAINNET_BASELINE`; payout execution requires `GATE_PAYOUT_READY_ALEX` | Same as `bounty` payout governance semantics. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2, §5.1) |
| `captured_protocol_fees.v1.stage_b` | `lp` | `cxd-treasury::lp` -> `operational-treasury::lp-incentives-vault` | LP incentives route | `GATE_MAINNET_BASELINE` | Policy percentages are governance surfaces; execution follows active bucket-set mechanics. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §5.1) |
| `captured_protocol_fees.v2` (policy-only candidate) | `labs_opex` | `operational-treasury::labs-opex-vault` | Labs operator fee allocation | Requires `GATE_OPERATOR_FEE_APPROVED` + explicit version bump | Not active in v1; requires explicit governance approval and versioned bucket-set introduction. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2 Labs-owned bucket note, §3.2) |

## Current gate states and active bucket-set version references

### Active bucket-set version references (canonical)

| bucket-set | current reference state | gate context | source |
| --- | --- | --- | --- |
| `productive_streaming.v1` | Legacy default reference for productive-yield routing | Enabled under `GATE_MAINNET_BASELINE` | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.1, §3.2, §6.2) |
| `productive_streaming.v2` | Defined and selectable (versioned alternative) | Requires explicit selection + `GATE_MAINNET_BASELINE` | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.1.2, §3.2) |
| `captured_protocol_fees.v1` | Canonical captured-fee pipeline reference | Stage A policy-gated; Stage B baseline accrual with payout-gated withdrawals | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2) |
| `captured_protocol_fees.v2` | Reserved policy-only future reference (not active) | Requires `GATE_OPERATOR_FEE_APPROVED` + governance-approved version bump | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§1.2, §3.2, §4.2) |

### Gate state snapshot (as documented)

| gate | documented state | source |
| --- | --- | --- |
| `GATE_MAINNET_BASELINE` | Gate definition is explicit; current true/false evidence is not explicitly declared in listed source docs. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§3.2) |
| `GATE_PAYOUT_READY_ALEX` | **Not payout-ready** (snapshot date: 2026-04-06). | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§3.1, §3.2); `docs/CSF_MAINNET_READINESS_GATE.md` (§Current gate status) |
| `GATE_OPERATOR_FEE_APPROVED` | Defined gate; no current approval evidence declared in listed source docs. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§3.2, §4.2) |
| `GATE_DAO_POLICY_QUORUM` | Boolean criteria defined; current true/false evidence not explicitly declared in listed source docs. | `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` (§6.1) |

### Governance handoff stage snapshot (SAB/DAO)

| handoff stage | documented status | source |
| --- | --- | --- |
| Stage 1 — Personal bootstrap | Current (bootstrap-only) | `docs/SAB_DAO_HANDOFF_PROTOCOL.md` (§Stage 1) |
| Stage 2 — SAB-controlled custody | Required for initial mainnet release | `docs/SAB_DAO_HANDOFF_PROTOCOL.md` (§Stage 2) |
| Stage 3 — DAO-aligned governance | Post-launch maturity | `docs/SAB_DAO_HANDOFF_PROTOCOL.md` (§Stage 3) |

## Policy placeholders (do not fabricate)

The following values are intentionally unresolved in public docs and must remain policy placeholders unless governance evidence updates them:

- Concrete wallet principal addresses / signer identities (`admin/SECRETS.md` is the public-safe pointer).
- Exact Stage B 6-way percentage vector values in `cxd-treasury`.
- `protocol_health_lock` policy toggle owner/process details.
- Any Labs operator-fee percentage for `captured_protocol_fees.v2`.

Use explicit placeholders (for example `governance-approved-parameter`) when implementation artifacts need a value slot.

## Source coverage map

| source doc | rights-map contribution |
| --- | --- |
| `docs/protocols/FEE_BUCKET_IMPLEMENTATION_PLAN.md` | Canonical bucket sets, bucket names, gates, and policy-vs-implementation boundaries. |
| `docs/SAB_WALLET_ARCHITECTURE_AND_CONTROL_MATRIX.md` | Wallet class boundaries, principals-over-addresses rule, and custody constraints. |
| `docs/BOS_WALLET_CONTROL_MODEL.md` | SAB execution vs DAO policy authority boundary and staged governance migration semantics. |
| `docs/SAB_DAO_HANDOFF_PROTOCOL.md` | Stage-status signals for custody/policy handoff lifecycle. |
| `openspec/changes/csf-autonomous-launch/specs/launch-mechanics/spec.md` | Founder's Cut carve-out and referral 5-5-5 normative requirements. |
| `docs/PORTFOLIO_BUSINESS_UNIT_MAP.md` | Portfolio authority/source-of-truth direction (`Protocol -> Nexus -> Gateway -> UI/Wallet`). |
| `docs/CONXIAN_PROTOCOL_BOS_BUILDOUT.md` | Separation rule: internal fee-split specifics and treasury policy details remain Linear-governed. |
