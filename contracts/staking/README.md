# Staking Module

The staking module coordinates two explicit legs without pretending that a
single Clarity transaction can atomically settle Stacks, external protocols,
and Bitcoin:

- `native-stacking-operator.clar` records delegated STX intent and the
  operator/PoX adapter commit lifecycle.
- `dual-stacking-orchestrator.clar` holds the configured SIP-010 native token,
  tracks positions and adapter exposure, and settles native-token/STX rewards.
- `contracts/traits/stacking-traits.clar` defines the injected PoX and generic
  stacking adapter boundaries.

The first implementation is compile-oriented and testable in Simnet. It is
**not a deployment declaration** and does not hardcode a production PoX
principal, native token, adapter, or Bitcoin payout route.

## Design boundaries

### Configurable native token

The second leg is any SIP-010 token that the administrator configures with
`set-native-token`. CXD can be configured initially, but the contracts do not
refer to CXD or the obsolete CXS name. The token principal supplied to every
custody/reward call must match the configured principal.

### Delegated PoX/operator accounting

The operator never transfers user STX into its own balance. A user registers a
delegation amount through the injected `<pox-adapter-trait>`. An authorized
keeper/operator then records a cycle-bound commit with a unique 32-byte
`auth-id`; the operator issues a monotonic local `commit-id` and snapshots the
adapter-returned cycle and unlock height.

PoX lifecycle timing uses `burn-block-height` and values returned by the
adapter. The contracts do not use a local `STAKING_CYCLE` constant. A real
deployment must provide an adapter whose production implementation is
authorized to interact with the applicable PoX system.

### Generic multi-protocol adapters

`register-adapter` adds an allowlisted adapter with a risk weight and maximum
exposure. Each position selects one registered adapter. `open-position`,
`request-native-unstake`, and `finalize-native-unstake` each perform at most one
state-changing adapter action. There is no arbitrary dynamic iteration over
protocols.

### Bitcoin rewards

Clarity cannot transfer native BTC. `record-btc-settlement` on the operator and
`record-btc-entitlement` on the orchestrator therefore record authorized,
cycle-bound settlement attestations keyed by unique proof hashes. A BTC claim
is a one-time accounting acknowledgement and returns the attested amount; it
does not transfer BTC or sBTC. An sBTC/SIP-010 payout path must be implemented
as a separately funded and explicitly configured integration before it is
enabled.

## Main APIs

### `native-stacking-operator.clar`

| Function | Purpose |
| --- | --- |
| `initialize(new-admin)` | One-time admin initialization. |
| `set-pox-adapter(adapter)` | Bind the injected `<pox-adapter-trait>` principal. |
| `set-keeper(keeper, enabled)` / `set-operator(principal)` | Authorize commit and settlement operators. |
| `register-delegation(amount, adapter)` | Register the caller's delegated STX amount without custody. |
| `revoke-delegation(adapter)` | Revoke an uncommitted delegation; allowed while paused. |
| `commit-delegation(user, amount, lock-period, auth-id, adapter)` | Record one adapter-backed, cycle-bound commit. |
| `finalize-commit(commit-id)` | Mark a commit mature at its adapter-returned unlock height. |
| `revoke-commit(commit-id)` | Revoke active accounting before maturity. |
| `record-btc-settlement(cycle-id, recipient, amount, proof-hash)` | Record a unique BTC settlement attestation. |

Useful views are `get-config`, `get-delegation`, `get-commit`,
`get-active-commit`, `get-cycle-ledger`, and `get-btc-settlement`.

### `dual-stacking-orchestrator.clar`

| Function | Purpose |
| --- | --- |
| `initialize(new-admin)` | One-time admin initialization. |
| `set-native-token(principal)` / `set-reward-token(principal)` | Configure SIP-010 custody and reward assets. |
| `register-adapter(adapter, risk-bps, max-exposure)` | Add an allowlisted stacking adapter. |
| `set-allocation-cap(cap)` / `set-liquid-reserve(native, stx)` | Bound aggregate exposure and minimum liquid balances. |
| `open-position(adapter, stx, native, token)` | Custody the native leg and prepare one adapter position. |
| `request-native-unstake(position-id, adapter)` | Start a native-token exit. |
| `finalize-native-unstake(position-id, adapter, token)` | Complete a matured exit while preserving the reserve floor. |
| `record-pox-commit(position-id, cycle-id, unlock-height, commit-id)` | Synchronize the separately committed PoX leg. |
| `finalize-pox-exit(position-id)` | Mark a delegated PoX leg unlocked after its burn-height boundary. |
| `fund-reward` / `claim-reward` | Fund and claim pro-rata SIP-010 rewards once per position. |
| `fund-stx-reward` / `claim-stx-reward` | Fund and claim pro-rata STX rewards. |
| `record-btc-entitlement` / `claim-btc-entitlement` | Record and acknowledge one-time BTC accounting entitlements. |

Position status values are `0 active`, `1 native-unlocking`, `2
native-unlocked`, and `3 closed`. `get-config`, `get-adapter`, `get-position`,
`get-reward-pool`, `get-stx-reward-pool`, and `get-btc-entitlement` expose the
state needed by off-chain keepers and reconciliation jobs.

## Safety invariants

- Pausing blocks new positions, delegated commits, and reward funding.
- Pausing does not block delegation revocation, matured native withdrawals,
  PoX exit finalization, or reward/BTC claims.
- Native custody is bounded by the configured SIP-010 principal; no token
  contract literal is embedded in the staking contracts.
- Adapter exposure and risk-weighted exposure are checked before position
  state is written and reduced only after a successful finalization.
- External adapter or token failures revert the transaction, including token
  custody and position ID advancement.
- Reward claims and BTC entitlements have explicit replay/one-time markers.
- New/modified staking contracts contain no hardcoded `ST...`/`SP...` network
  principals and no `unwrap-panic` paths.

## Tests

Run the focused suite with:

```bash
npx vitest run tests/staking/dual-stacking-orchestrator.test.ts
```

The suite covers initialization/authentication, adapter binding, exposure
caps, reserve enforcement, delegated commits, replayed auth IDs, exact
burn-height boundaries, revocation and matured exits, pro-rata token rewards,
BTC proof replay/claims, pause behavior, and failed external calls.

## Deployment status

The contracts are not deployed by this change. Production deployment still
requires a reviewed PoX adapter, explicit native-token and reward-token
wiring, funded reserves, an operator/keeper policy, and a separately reviewed
Bitcoin settlement or sBTC payout integration. The checked-in deployment
plans are generator-owned; this change registers the sources in both Clarinet
manifests but does not hand-edit the large generated release YAML files.
