# Dual Stacking Architecture (Issue #501)

## Scope

This document describes the first complete compile-oriented staking boundary.
It is deliberately narrower than a promise of atomic cross-chain staking.

```text
user
  │ native SIP-010 custody
  ▼
dual-stacking-orchestrator ── one adapter action/tx ──> allowlisted protocol adapter
  │        │
  │        └── authoritative PoX commit binding and exit reconciliation
  │
  └── reward pools / reserve floor / BTC entitlement accounting

keeper/operator
  │ delegated intent + auth-id
  ▼
native-stacking-operator ── injected pox-adapter-trait ──> PoX-compatible adapter
```

## Trust boundaries

### PoX adapter

The boot PoX contract is not assumed to nominally implement the local trait in
Simnet. `native-stacking-operator` stores the configured adapter principal and
checks `(contract-of adapter)` on every adapter call. Production wiring must
supply an adapter that enforces the real PoX delegation, commit, and finalization
rules. The external PoX adapter remains a deployment trust boundary: the
Simnet mock is deterministic and is not a production oracle.

### Generic stacking adapters

The orchestrator stores adapter principals, risk basis points, exposure caps,
current exposure, and active status. A caller must pass the trait implementation
on every operation; the contract verifies that its principal is registered and
re-queries its current policy at open. The v1 surface intentionally does not
iterate over arbitrary adapter lists or claim atomic settlement across
protocols.

### Token custody

The orchestrator is the custody contract for the configured native SIP-010
token and optional SIP-010 reward token. The operator does not custody STX.
Every token operation validates the injected trait's principal against stored
configuration. Native, reward-token, and STX reserves are separate minimum
balance floors; native custody is never used as the reward-token reserve.

### Bitcoin settlement

Native BTC stays outside Clarity. An authorized operator records a matured
commit's cycle, recipient, amount, and unique proof hash. The orchestrator asks
the configured operator to consume that exact settlement, binding the proof to
one position and commit. The position must have completed authoritative PoX exit
finalization before the entitlement is recorded or claimed. The one-time claim
is accounting-only: no native BTC transfer, sBTC mint, or sBTC payout is implied.

## Lifecycle

1. An administrator initializes each contract once and configures trait-typed
   native/reward tokens, the native operator, the PoX adapter, and allowlisted
   stacking adapters. Operator wiring also names the orchestrator that may bind
   commits.
2. A user registers delegated STX intent through the native operator. The
   operator asks the adapter to delegate and records no user STX balance.
3. A keeper commits a user's delegated amount with a unique auth hash. The
   adapter returns the cycle snapshot and unlock height; both are stored with a
   monotonic local commit ID.
4. A user opens a dual position with a native-token amount and commit ID. The
   orchestrator atomically binds the unique active operator commit, derives the
   owner/STX amount/cycle/unlock metadata, re-queries adapter policy, transfers
   only the native SIP-010 leg into custody, checks native/STX/risk caps, and
   calls exactly one adapter preparation action. If a later action fails, the
   binding and all local accounting roll back.
5. Native unstake is a prepare/finalize flow. Requests remain available while
   paused; finalization requires the local burn-height cooldown, a successful
   adapter finalization, and enough token balance to retain the reserve floor.
6. PoX exit is finalized through the configured operator and adapter only at or
   after the authoritative unlock height. STX remains delegated to the external
   PoX system, and STX exposure is decremented once on reconciled exit.
7. Reward pools are funded before claims begin. The first funding freezes the
   cycle denominator; later positions cannot dilute it, claims do not close the
   pool for other positions, and total claimed cannot exceed funded total. The
   native-token amount is the v1 reward-share weight; STX and generic-token units
   are not combined.
8. A matured operator settlement is consumed once to record a position-bound BTC
   entitlement. The later claim only marks accounting state and returns the
   attested amount.

## Clocks and arithmetic

- PoX cycle and unlock boundaries use adapter-returned values and
  `burn-block-height`.
- Native cooldowns use `burn-block-height` as an internal slow-path boundary.
- No local two-week/PoX cycle constant is used for the external PoX lifecycle.
- Add/subtract and pro-rata helpers return optionals and fail with explicit
  error constants on overflow or underflow.

## Pause semantics

Pause is a risk gate, not a custody freeze. It blocks new positions, new PoX
commits, and reward funding. It preserves delegation revocation, matured
native withdrawals, PoX exit finalization, and already-funded reward/BTC
claims.

## Deployment posture

The source contracts and mocks are registered in `Clarinet.toml` and
`Clarinet.complete.toml`. The local Clarinet CLI is not installed in the
implementation environment, so the repository's Clarinet SDK/test
initialization regenerates `deployments/default.simnet-plan.yaml`. The release
plans are then regenerated with `scripts/gen-deployment-plans.py`; the new test
mocks remain in `TEST_HELPERS`, while `stacking-traits` and the issue-501
production contracts are retained in the release dependency order. These
contracts are not production deployed by this change.
