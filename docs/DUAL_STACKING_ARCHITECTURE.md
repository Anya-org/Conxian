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
  │        └── explicit PoX commit synchronization
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
Simnet. `native-stacking-operator` instead stores the configured adapter
principal and checks `(contract-of adapter)` on every adapter call. Production
wiring must supply an adapter that enforces the real PoX delegation and commit
rules. The Simnet mock is deterministic and is not a production oracle.

### Generic stacking adapters

The orchestrator stores adapter principals, risk basis points, exposure caps,
current exposure, and active status. A caller must pass the trait implementation
on every operation; the contract verifies that its principal is registered.
The v1 surface intentionally does not iterate over arbitrary adapter lists or
claim atomic settlement across protocols.

### Token custody

The orchestrator is the custody contract for the configured native SIP-010
token and optional SIP-010 reward token. The operator does not custody STX.
Every token operation validates the injected trait's principal against stored
configuration. The liquid reserve is an absolute minimum balance floor checked
before native withdrawals and reward payouts.

### Bitcoin settlement

Native BTC stays outside Clarity. An authorized operator records a cycle,
recipient, amount, and unique proof hash. The orchestrator records one
position-bound entitlement for that proof and exposes a one-time accounting
claim. No native BTC transfer, sBTC mint, or sBTC payout is implied.

## Lifecycle

1. An administrator initializes each contract once and configures the native
   token, reward token, operator, PoX adapter, and allowlisted stacking adapter.
2. A user registers delegated STX intent through the native operator. The
   operator asks the adapter to delegate and records no user STX balance.
3. A keeper commits a user's delegated amount with a unique auth hash. The
   adapter returns the cycle snapshot and unlock height; both are stored with a
   monotonic local commit ID.
4. A user opens a dual position. The orchestrator transfers only the native
   SIP-010 leg into custody, checks total/adapter/risk caps, and calls exactly
   one adapter preparation action.
5. Native unstake is a prepare/finalize flow. Requests remain available while
   paused; finalization requires the local burn-height cooldown, a successful
   adapter finalization, and enough token balance to retain the reserve floor.
6. PoX commits are synchronized explicitly with `record-pox-commit`; the exit
   is finalized only at the stored burn-height boundary. STX remains delegated
   to the external PoX system.
7. Reward pools are funded before claims begin. Each position receives a
   deterministic pro-rata share from its cycle weight and can claim once.
8. BTC proofs are recorded and acknowledged independently from token rewards.

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
implementation environment. The Clarinet SDK can compile the manifest but
rewrites `deployments/default.simnet-plan.yaml` with a different generated
format/version, so that generator-owned artifact is intentionally restored
and not hand-edited. `scripts/gen-deployment-plans.py` excludes the new test
mocks from future release plans; release-plan regeneration is a follow-up
once the pinned Clarinet generator is available.
