# DEX Module

## Scope

The DEX module provides **oracle, deterministic policy, legacy liquidity-intent
infrastructure, a canonical CXLP compatibility primitive, and bounded V2
custody/execution**. Legacy manager and router entrypoints retain their prior
semantics. Separately named V2 surfaces execute only against
`concentrated-liquidity-pool-v2`, whose position ID is the canonical LP lot.

The existing swap and concentrated-liquidity contracts remain separate
integration surfaces. This README describes the production-safe behavior of
the DEX contracts covered by the current implementation and tests.

## Architecture

- **Oracle facade** (`oracle.clar`) — canonical aggregate spot and TWAP
  validation.
- **Policy helpers** — pure/read-only checks for invariants, rebalancing, and
  bounded scaling decisions.
- **Liquidity intent ledger** (`liquidity-manager.clar`) — preserves validated
  legacy intents and the oracle movement proxy, while separate V2 functions
  manage canonical pool lots without changing legacy APIs.
- **V2 execution** (`concentrated-liquidity-pool-v2.clar`) — authoritative
  custody, immutable full-close lots, fee accounting, tick accounting, swaps,
  reconciliation, and executable-state PnL/IL.

Pool IDs and token principals accepted by the liquidity-manager are
**caller-supplied intent metadata**. They are stored and emitted for later
execution, but they are not verified against an on-chain pool or token
registry. This statement applies only to the legacy intent functions. V2
functions read and validate the canonical V2 pool and token order directly.

## Core Contracts (Reference)

### `swap-router.clar`
The Apex Universal Router.

`exact-input-single-v2` is a separate direct-custody route. It reads the V2
pool, derives direction from canonical token order, validates the limit against
the current V2 sqrt price, preserves router pause and V2-source isolation
policy, and calls V2 without pre-transfer or `as-contract` custody. Legacy
router behavior is unchanged.

| Function | Signature | Description |
|----------|-----------|-------------|
| `csf-swap` | `(liquidity-source <csf-liquidity-trait>) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (min-amount-out uint)` | Executes a swap through any registered CSF source. |
| `claim-external-yield` | `(liquidity-source <csf-liquidity-trait>) (reward-token <sip-010-ft-trait>) (amount uint)` | Bridges rewards from third-party protocols to the user. |
| `update-volatility-fees` | `()` | Update the protocol fees based on current market volatility. |
| `exact-input-single` | `(pool-id uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (min-amount-out uint)` | Execute a swap on a single pool with exact input amount. |
| `get-protocol-status` | `()` | Get the current operational status of the swap router. |

### `dex-factory.clar`
CSF Discovery and Registry.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-pool` | `(token-a principal) (token-b principal) (type uint) (pool-contract principal)` | Registers a new liquidity pool in the factory. |
| `register-csf-protocol` | `(protocol principal) (name (string-ascii 256))` | Registers a CSF-compliant external contract for discovery. |
| `toggle-csf-protocol` | `(protocol principal)` | Toggle the active state of a registered CSF protocol. |
| `get-pool` | `(token0 principal) (token1 principal) (type uint)` | Returns the contract principal for a specific pool. |
| `get-pool-count` | `()` | Returns the total number of registered pools. |
| `get-csf-protocol` | `(protocol principal)` | Returns metadata for a registered external protocol. |
| `get-csf-registry-count` | `()` | Returns the total number of registered CSF protocols. |
| `get-csf-protocol-by-index` | `(index uint)` | Returns the protocol principal at a specific registry index. |

### `concentrated-liquidity-pool.clar`
Native High-Efficiency Liquidity.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-liquidity-marker` | `(marker (string-ascii 256))` | Register a liquidity marker for the protocol. |
| `execute-csf-swap` | `(token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount-in uint) (recipient principal)` | Execute a swap through the Common Settlement Framework. |
| `request-flash-liquidity` | `(token <sip-010-ft-trait>) (amount uint) (payload (buff 32))` | Request flash liquidity from the pool. |
| `settle-arbitrage` | `(token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (amount uint) (route (list 10 principal))` | Settle an arbitrage path through the CSF. |
| `claim-conxian-yield` | `(reward-token <sip-010-ft-trait>) (amount uint) (recipient principal)` | Claim protocol yield through the CSF. |
| `get-csf-health` | `()` | Get the health metrics of the CSF integration. |
| `swap` | `(pool-id uint) (is-token-0 bool) (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (recipient principal)` | Execute a swap in a concentrated liquidity pool. |
| `create-pool` | `(token-0 principal) (token-1 principal) (fee uint) (initial-price uint) (initial-tick int)` | Create a new concentrated liquidity pool. |
| `mint-shares` | `(pool-id uint) (owner principal) (amount uint)` | Settlement-authority-only atomic CXLP mint plus increment of the selected pool's outstanding-share total and the protocol-wide outstanding-share total. Does not custody pool assets. |
| `burn-shares` | `(pool-id uint) (owner principal) (amount uint)` | Settlement-authority-only atomic CXLP burn after checking the canonical owner balance, selected pool total, and protocol-wide total. Does not settle a withdrawal. |
| `get-pool-outstanding-shares` | `(pool-id uint)` | Reads the selected pool's aggregate outstanding CXLP share total. |
| `get-total-outstanding-shares` | `()` | Reads the protocol-wide outstanding CXLP share total, which must equal canonical CXLP supply. |
| `get-recorded-share-supply` | `()` | Compatibility alias for `get-total-outstanding-shares`. |
| `collect-protocol-fees` | `(token <sip-010-ft-trait>)` | Fails closed with `u1008`; CLP fees are not segregated from pool/user custody and untracked assets must not be transferred. |
| `get-protocol-status` | `()` | Get the status of the CL pool contract. |

The CLP's SIP-010 surface proxies transfer and read methods to `.cxlp-token`
so it cannot return fabricated success, zero balances, or a divergent token
identity. Canonical CXLP balances are the aggregate, transferable ownership
record. The share hooks validate pool existence, positive amounts, the
canonical owner balance for burns, canonical supply, and the CLP aggregate
totals before updating the selected pool and protocol-wide totals. Clarity
transaction rollback keeps the token and local totals atomic when a downstream
mint or burn fails.

`settlement-authority` is injected through `set-settlement-authority` by the
CLP admin. It is trusted only to select the correct pool and position for these
primitive hooks. This is an integration boundary for #536; it is not a
substitute for #536's per-position/per-pool attribution, custody,
settlement-validation, add/remove-liquidity, fee, or exact IL logic.
`create-pool` intentionally mints no CXLP because a zero-liquidity pool has no
backing share operation.

The CLP and `swap-aggregator` trait entrypoints for `collect-protocol-fees`
remain ABI-compatible but fail closed (`u1008` and `u1003`, respectively) for
every caller. Dedicated, segregated DEX fee custody and canonical settlement
must exist before either entrypoint can transfer assets. Until then, these
surfaces must not be composed with legacy or canonical fee collection on the
same base.

### `liquidity-manager.clar`
The legacy liquidity-manager surface remains a validated, unexecuted intent
ledger. Every legacy record starts with `accounted-liquidity: u0`; no token or
pool mutation is performed. Separately named V2 functions execute against the
authoritative V2 pool and use a separate map keyed by canonical V2 position ID.

| Function | Signature | Description |
|----------|-----------|-------------|
| `set-oracle` | `(oracle-source <oracle-trait>)` | Owner-only configuration. Only the canonical `.oracle` facade is accepted; the configured principal is stored and rechecked through `(contract-of oracle-source)`. |
| `set-oracle-source` | `(oracle-source <oracle-trait>)` | Compatibility alias with the same canonical-principal guard. |
| `set-contract-owner` | `(new-owner principal)` | Owner-only owner transfer. |
| `open-position` | `(pool-id uint) (tick-lower int) (tick-upper int) (liquidity uint)` | Records a compliant, unexecuted position intent. Pool ID is caller-supplied metadata; no pool registry lookup or token movement occurs. |
| `open-position-with-assets` | `(pool-id uint) (tick-lower int) (tick-upper int) (liquidity uint) (token-0 principal) (token-1 principal) (oracle-source <oracle-trait>) (max-price-move-bps uint)` | Records token metadata and captures both entry prices through `.oracle get-validated-price`. The supplied trait must be the configured canonical facade. |
| `get-position` | `(position-id uint)` | Reads the local intent record, including requested and accounted liquidity. |
| `close-position` | `(position-id uint)` | Closes only the local intent record. It does not withdraw or settle liquidity. |
| `update-risk-limit` | `(position-id uint) (max-price-move-bps uint)` | Updates the owner-managed movement threshold. |
| `set-risk-limit` | `(position-id uint) (max-price-move-bps uint)` | Compatibility alias for `update-risk-limit`. |
| `get-il-protection-status` | `(position-id uint) (oracle-source <oracle-trait>)` | Compares entry prices with current `.oracle get-validated-price` values. This is a deterministic price-movement proxy, not exact concentrated-liquidity impermanent-loss accounting. Equality at the threshold is safe. |
| `request-rebalance` | `(position-id uint) (target-tick-lower int) (target-tick-upper int) (target-liquidity uint)` | Records a position-owner-only rebalance intent without mutating position liquidity or pool state. |
| `get-rebalance` | `(position-id uint)` | Reads the rebalance intent. |
| `get-rebalance-plan` | `(position-id uint)` | Compatibility alias for `get-rebalance`. |
| `cancel-rebalance` | `(position-id uint)` | Cancels the local rebalance intent. |
| `get-rebalance-advice` | `(position-id uint) (observed-tick int)` | Evaluates a caller-observed tick against the stored range. The observation is advisory; the pool has no current-tick getter here and no rebalance is executed. |
| `open-position-v2` | `(pool-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>) (tick-lower int) (tick-upper int) (max-amount0 uint) (max-amount1 uint) (min-liquidity uint)` | Compliance-gated canonical V2 open. The pool pulls directly from `tx-sender`; manager metadata is written only after success. |
| `close-position-v2` | `(position-id uint) (token-0 <sip-010-ft-trait>) (token-1 <sip-010-ft-trait>) (min-amount0 uint) (min-amount1 uint)` | Canonical-owner-only full close to `tx-sender`; legacy manager-admin rights do not apply. |
| `rebalance-position-v2` | `(position-id uint) ... target range/max amounts/min liquidity/min close amounts` | Atomic full close/reopen from `tx-sender`; replacement failure rolls back all pool, token, tick, and manager changes. |
| `get-v2-managed-position` | `(position-id uint)` | Reads manager linkage metadata keyed by canonical V2 position ID. |
| `get-v2-authoritative-position` | `(position-id uint)` | Proxies the authoritative V2 lot. |
| `get-v2-position-pnl` / `get-v2-exact-il` | `(position-id uint)` | Proxies executable-state PnL/loss-only IL without the legacy oracle proxy. |

The risk endpoint fails closed when canonical aggregate/TWAP data is missing,
stale, zero, or excessively divergent. It does not call a dynamic oracle
implementation for pricing after the canonical principal check.

### `route-manager.clar`
Multi-hop Swap Routing.

| Function | Signature | Description |
|----------|-----------|-------------|
| `swap-route` | `(amount-in uint) (amount-out-min uint) (token-in <sip-010-trait>) (token-out <sip-010-trait>) (route (list 5 principal))` | Execute a multi-hop swap route. |

### `oracle.clar`
Canonical aggregate/TWAP oracle facade implementing
`defi-traits.oracle-trait`.

| Function | Signature | Description |
|----------|-----------|-------------|
| `get-price` | `(token principal)` | Returns the nonzero raw aggregate spot from `oracle-aggregator`; it does not apply the TWAP deviation policy. |
| `fetch-price` | `(token principal)` | Public compatibility wrapper for the same raw aggregate spot. |
| `get-twap-price` | `(token principal)` | Returns the nonzero TWAP from `twap-oracle`. |
| `get-price-decimals` | `()` | Returns the shared price precision only when `oracle-aggregator` and `twap-oracle` declare the same explicit decimal scale. |
| `get-price-diagnostics` | `(token principal)` | Returns spot, TWAP, and absolute deviation in basis points. |
| `get-validated-price` | `(token principal)` | Returns aggregate spot only when spot-vs-TWAP deviation is at or below the configured inclusive limit. |
| `set-max-twap-deviation-bps` | `(new-deviation-bps uint)` | Owner-only inclusive deviation policy, bounded to 10,000 bps. |
| `set-price` | `(token principal) (price uint)` | Owner-only legacy advisory metadata. It is not read by canonical price or validation paths. |
| `get-legacy-price` | `(token principal)` | Reads retained advisory metadata, if present. |
| `transfer-ownership` | `(new-owner principal)` | Transfer contract ownership to a new principal. |

Canonical aggregate or TWAP data that is missing, stale, zero, or outside the
configured deviation limit returns an error; it no longer appears as
`(ok u0)`. Consumers that need a risk-safe price should call
`get-validated-price`, not raw `get-price`.

### Price-scale boundary

`oracle-aggregator` and `twap-oracle` expose owner-configured
`set-price-decimals`/`get-price-decimals` metadata. The DEX facade requires both
sources to declare the same scale before returning canonical prices or applying
the TWAP policy. It validates equality and does **not** invent a conversion
factor or normalize token-native decimals. Deployments must choose and record a
shared price precision before configuring the facade; token-specific
conversion remains outside this intent-only PR.

`twap-oracle.set-twap-window` rejects `u0`; `u1` is the minimum accepted window.

## Integration Examples (How-to)

### Routing through an External Protocol (e.g. Bitflow)
```clarity
(contract-call? .swap-router csf-swap
  .bitflow-csf-adapter
  .stx-token
  .usda-token
  u1000000
  u990000
)
```

## Deterministic policy helpers

These contracts are pure/read-only policy helpers and do not execute swaps or
move assets:

- `protocol-invariant-monitor.clar` — solvency and constant-product checks,
  including bounded tolerance and overflow handling.
- `rebalancing-rules.clar` — strict-threshold rebalance decisions, absolute
  deltas, and signed direction.
- `predictive-scaling-system.clar` — bounded activity scaling,
  volatility-adjusted fees, and depth-adjusted liquidity.
- `concentrated-math.clar` — concentrated-liquidity tick and math helpers used
  for input validation.

The removed `placeholder` entrypoints were nonfunctional stubs. Callers should
use the deterministic helper functions listed above rather than relying on
those compatibility-only no-op entrypoints.

## Focused tests

- `tests/dex/oracle.test.ts` — aggregate/TWAP facade behavior, diagnostics,
  inclusive deviation boundaries, zero/missing data, and overflow handling.
- `tests/dex/liquidity-manager.test.ts` — canonical oracle configuration,
  validated openings, missing/stale TWAP fail-closed behavior, intent
  isolation, movement-proxy thresholds, and rebalance/tick advice.
- `tests/dex/dex-policy-stubs.test.ts` — deterministic invariant and
  rebalancing helpers.

## V2 protocol-fee release gate

V2 reserves a fixed 10% share of assessed swap fees, while
`protocol-fee-collector.settle-source-ft` applies its own schedule to an
eligible base. Wiring them directly would double-rate the trade or reassess an
already-reserved amount and can strand custody relative to the collector's
exact-delta source callback. Release therefore remains disabled with no direct
transfer or sweep.

Governance must choose either: (1) the collector replaces V2's fixed share and
becomes the sole assessment, or (2) the collector gains a reviewed,
authenticated fixed-amount ingress that does not apply another schedule.

## Legacy CXLP integration boundary

The CXLP primitive and atomic share reconciliation hooks are now available, but
the CLP integration still needs:

1. #536-owned token custody and transfer authorization for deposits/withdrawals;
2. on-chain LP position creation, ownership, and settlement accounting;
3. pool reserve/liquidity reads and fee accrual/collection accounting; and
4. a trusted current-tick/current-price observation API for rebalance advice.

CXLP is one global fungible token. Direct CXLP transfers and transfers through
the CLP proxy are real SIP-010 transfers: they change canonical owner balances
without changing supply or either CLP aggregate total. The CLP deliberately
does not maintain a duplicate owner or owner/pool ledger that ordinary
transfers could stale. Before any burn is exposed to users, #536 must supply
the per-position/per-pool attribution, custody, and settlement validation that
identifies the correct pool and owner amount; these hooks do not invent that
attribution.

These prerequisites still apply to the legacy CXLP/CLP path. They do not alter
the separately versioned V2 position-ID entitlement or its manager/router
integration.
