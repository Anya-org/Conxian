# Staking Module

The staking module coordinates two explicit legs without pretending that a
single Clarity transaction can atomically settle Stacks, external protocols,
and Bitcoin:

- `native-stacking-operator.clar` records delegated STX intent and owns the
  authoritative operator/PoX commit and settlement lifecycle.
- `dual-stacking-orchestrator.clar` holds the configured SIP-010 native and
  reward tokens, binds positions to unique operator commits, tracks adapter
  exposure, and settles native-token/STX rewards.
- `contracts/traits/stacking-traits.clar` defines the injected PoX, native
  operator, and generic stacking adapter boundaries.

The first implementation is compile-oriented and testable in Simnet. It is
**not a deployment declaration** and does not hardcode a production PoX
principal, native token, adapter, or Bitcoin payout route.

## Design boundaries

### Configurable tokens and operator

The native and reward legs are trait-typed SIP-010 contracts configured with
`set-native-token` and `set-reward-token`; only their injected principals are
stored. The configured native operator is likewise trait-typed and stored by
principal. CXD can be configured initially, but the contracts do not refer to
CXD or the obsolete CXS name. Every custody, reward, operator, and adapter call
must match the configured principal.

### Authoritative STX commitment

The operator never transfers user STX into its own balance. A user registers a
delegation amount through the injected `<pox-adapter-trait>`. An authorized
keeper/operator then records a cycle-bound commit with a unique 32-byte
`auth-id`; the operator issues a monotonic local `commit-id` and snapshots the
adapter-returned cycle and unlock height.

Opening a position requires a unique, active operator commit. The orchestrator
calls `bind-commit`, which is restricted to the configured orchestrator and
returns the authoritative owner, committed STX amount, cycle, unlock height,
operator principal, and lifecycle state. The same commit cannot be bound twice;
if token custody or adapter preparation fails, the whole transaction rolls back
the binding, position ID, exposure, and custody effects.

The verified STX commitment is a required eligibility leg, but v1 does not add
STX units to generic SIP-010 units. The custody-backed native-token amount is
the reward-share weight because asset decimals are not combined. STX exposure is
tracked and capped separately from native-token and risk-weighted exposure.

PoX lifecycle timing uses `burn-block-height` and values returned by the
adapter. The contracts do not use a local `STAKING_CYCLE` constant. A real
deployment must provide an adapter whose production implementation is
authorized to interact with the applicable PoX system.

An active commit cannot be locally revoked. Delegation revocation is separate
and is rejected while a commit is active. `finalize-commit` calls the configured
external adapter before marking the local commit mature, so premature maturity
or external finalization failure leaves local state unchanged.

### Generic multi-protocol adapters

`register-adapter` adds an allowlisted adapter with a risk weight and maximum
exposure. Each position selects one registered adapter. `open-position`,
`request-native-unstake`, and `finalize-native-unstake` each perform at most one
state-changing adapter action. There is no arbitrary dynamic iteration over
protocols.

### Bitcoin settlement accounting

Clarity cannot transfer native BTC. A matured operator commit receives one
authorized settlement record keyed by a proof hash. `record-btc-entitlement`
asks the configured operator to consume that exact settlement, binding cycle,
recipient, amount, proof, and commit to one position. The position must already
have completed authoritative PoX exit finalization. A BTC claim is a one-time
accounting acknowledgement and returns the attested amount; it does not
transfer BTC or sBTC. An sBTC/SIP-010 payout path must be implemented as a
separately funded and explicitly configured integration before it is enabled.

## Main APIs

### `native-stacking-operator.clar`

| Function | Purpose |
| --- | --- |
| `initialize(new-admin)` | One-time admin initialization. |
| `set-pox-adapter(adapter)` | Bind the injected `<pox-adapter-trait>` principal. |
| `set-keeper(keeper, enabled)` / `set-operator(principal)` | Authorize commit and settlement operators. |
| `set-orchestrator(principal)` | Set the only orchestrator allowed to bind commits and settlements. |
| `register-delegation(amount, adapter)` | Register the caller's delegated STX amount without custody. |
| `revoke-delegation(adapter)` | Revoke an uncommitted delegation; active commits must mature first. |
| `commit-delegation(user, amount, lock-period, auth-id, adapter)` | Record one adapter-backed, cycle-bound commit. |
| `bind-commit(commit-id)` | Bind one active commit to the configured orchestrator and return authoritative metadata. |
| `finalize-commit(commit-id, adapter)` | Finalize the external lock at or after its exact unlock height. |
| `record-btc-settlement(commit-id, amount, proof-hash)` | Record a unique settlement for a matured commit. |
| `bind-btc-settlement(commit-id, proof-hash, expected-amount)` | Consume one exact settlement for the configured orchestrator. |

Useful views are `get-config`, `get-delegation`, `get-commit`,
`get-active-commit`, `get-cycle-ledger`, and `get-btc-settlement`.

### `dual-stacking-orchestrator.clar`

| Function | Purpose |
| --- | --- |
| `initialize(new-admin)` | One-time admin initialization. |
| `set-native-token(token)` / `set-reward-token(token)` | Configure trait-typed SIP-010 custody and reward assets. |
| `set-native-operator(operator)` | Configure the trait-typed authoritative native operator. |
| `register-adapter(adapter, risk-bps, max-exposure)` | Add an allowlisted stacking adapter. |
| `set-allocation-cap(cap)` / `set-stx-allocation-cap(cap)` | Bound native-token and verified STX exposure separately. |
| `set-liquid-reserve(native, reward, stx)` | Set independent native, reward-token, and STX reserve floors. |
| `open-position(adapter, native, token, operator, commit-id)` | Bind one authoritative STX commit, custody the native leg, and prepare one adapter position. |
| `request-native-unstake(position-id, adapter)` | Start a native-token exit. |
| `finalize-native-unstake(position-id, adapter, token)` | Complete a matured exit while preserving the reserve floor. |
| `finalize-pox-exit(position-id, operator, adapter)` | Reconcile the configured operator's authoritative matured commit. |
| `fund-reward` / `claim-reward` | Fund and claim pro-rata SIP-010 rewards once per position. |
| `fund-stx-reward` / `claim-stx-reward` | Fund and claim pro-rata STX rewards. |
| `record-btc-entitlement` / `claim-btc-entitlement` | Consume a bound operator settlement and acknowledge one-time BTC accounting. |

Position status values are `0 active`, `1 native-unlocking`, `2
native-unlocked`, and `3 closed`. `get-config`, `get-adapter`, `get-position`,
`get-reward-pool`, `get-stx-reward-pool`, and `get-btc-entitlement` expose the
state needed by off-chain keepers and reconciliation jobs.

## Safety invariants

- Pausing blocks new positions, delegated commits, and reward funding.
- Pausing does not block delegation revocation, matured native withdrawals,
  PoX exit finalization, or reward/BTC claims.
- Native custody and reward payout are bounded by their respective configured
  SIP-010 principals; a reward-token reserve is never compared with native-token
  custody.
- Every position has one authoritative, unique STX commit. The committed amount,
  owner, cycle, unlock height, and operator principal are read from that commit,
  not supplied as trusted orchestrator metadata.
- A position's native-token amount is its v1 reward-share weight. STX exposure is
  accounted for and capped separately; units are never combined without decimal
  normalization.
- Adapter exposure and risk-weighted exposure are checked before position
  state is written and reduced only after a successful finalization.
- External adapter or token failures revert the transaction, including token
  custody and position ID advancement.
- Reward denominators are snapshotted before claims, later positions cannot
  dilute a funded cycle, and funding stops once claims begin. Reward claims and
  BTC entitlements have explicit replay/one-time markers and total-claimed
  bounds. Dust sweeps also require the orchestrator's actual reward-token or STX
  balance to cover the swept remainder plus its configured reserve floor; a
  failed solvency check leaves `swept` false.
- An active PoX commit cannot be locally canceled. External finalization is
  authoritative and must succeed before local maturity/exit state is written.
- The external PoX adapter remains a deployment trust boundary; mocks validate
  the lifecycle in Simnet but are not production PoX implementations.
- New/modified staking contracts contain no hardcoded `ST...`/`SP...` network
  principals and no `unwrap-panic` paths.

## Tests

Run the focused suite with:

```bash
npx vitest run tests/staking/dual-stacking-orchestrator.test.ts
```

The focused suite covers typed configuration, authoritative unique commit
binding, separate native/STX/risk exposure across two adapters, rollback on
token/adapter/PoX failures, exact maturity boundaries, frozen two-position
SIP-010 and STX reward pools, reserve separation, settlement proof binding,
replay protection, pause behavior, and accounting-only BTC claims. It is
Simnet-focused coverage, not a production deployment or full protocol audit.

## Deployment status

The contracts are **not production deployed** by this change. Production
deployment still requires a reviewed PoX adapter, explicit native-token and
reward-token wiring, funded reserves, an operator/keeper policy, and a
separately reviewed Bitcoin settlement or sBTC payout integration. The checked-
in deployment plans are generator-owned and are regenerated from the Clarinet
SDK/default Simnet plan; the regression check only asserts issue-501 production
contracts and their `stacking-traits` dependency are present and ordered.
