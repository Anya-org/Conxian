# DEX Module

## Scope

The DEX module currently provides **oracle, deterministic policy,
liquidity-intent infrastructure, and a canonical CXLP share primitive**. It
does not yet provide a complete LP execution or custody system. In particular,
the liquidity-manager ledger does not transfer tokens, custody assets, mutate
a pool, collect fees, or prove that an LP position was executed.

The existing swap and concentrated-liquidity contracts remain separate
integration surfaces. This README describes the production-safe behavior of
the DEX contracts covered by the current implementation and tests.

## Architecture

- **Oracle facade** (`oracle.clar`) — canonical aggregate spot and TWAP
  validation.
- **Policy helpers** — pure/read-only checks for invariants, rebalancing, and
  bounded scaling decisions.
- **Liquidity intent ledger** (`liquidity-manager.clar`) — records validated
  position and rebalance intents plus a price-movement risk proxy.
- **CLP state foundation** (`concentrated-liquidity-pool.clar`) — authorized,
  validated pool identity; configured current tick/price reads; and bounded
  pure amount previews. Reserve and fee accounting are deliberately deferred
  until custody and execution can update them atomically.
- **Execution prerequisites** — token custody, executable position ownership,
  reserve/fee mutation, and settlement are still required before the intent
  ledger can execute or settle LP operations.

Pool IDs and token principals accepted by the liquidity-manager are
**caller-supplied intent metadata**. They are stored and emitted for later
execution, but they are not verified against an on-chain pool or token
registry.

## Core Contracts (Reference)

### `swap-router.clar`
The Apex Universal Router.

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
| `swap` | `(pool-id uint) (is-token-0 bool) (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (recipient principal)` | Legacy execution path. It now requires an existing pool and binds both token contracts to the registered pair in the requested orientation before fee calculation or custody movement. It does not add reserve math, price movement, or new swap economics. |
| `create-pool` | `(token-0 principal) (token-1 principal) (fee uint) (initial-price uint) (initial-tick int)` | Admin- or registrar-only creation of validated configured pool state. Tokens must differ, fee must be 1–10,000 on the existing 1,000,000 denominator, tick must be in the bounded execution range, initial price must match the deterministic linear tick approximation, and duplicate pair/fee pools are rejected in either token order. |
| `initialize` | `(new-admin principal)` | One-time deployment-admin bootstrap that transfers both admin and registrar authority. Replays fail. |
| `get-pool` | `(pool-id uint)` | Compatibility read for the original pool tuple. |
| `get-pool-id` | `(token-a principal) (token-b principal) (fee uint)` | Resolves a pool in either token order. |
| `get-pool-state` | `(pool-id uint)` | Returns the validated, stored pool configuration using the original pool tuple shape. It is not reserve, custody, or oracle truth. |
| `get-current-tick` | `(pool-id uint)` | Returns the pool's stored configured tick. |
| `get-current-sqrt-price` | `(pool-id uint)` | Returns the pool's stored configured sqrt price at the documented 1e12 scale. |
| `preview-position-amounts` | `(pool-id uint) (tick-lower int) (tick-upper int) (liquidity uint) (round-up bool)` | Pure bounded amount preview from stored pool price and a valid range. Uses the deterministic linear tick model and explicitly does not claim exact V3 math. |
| `get-pool-registrar` | `()` | Reads the principal authorized to create pools alongside the admin. |
| `set-pool-registrar` | `(registrar principal)` | Admin-only principal injection for the pool-creation authority. Authorization uses the immediate contract caller. |
| `mint-shares` | `(pool-id uint) (owner principal) (amount uint)` | Settlement-authority-only atomic CXLP mint plus increment of the selected pool's outstanding-share total and the protocol-wide outstanding-share total. Does not custody pool assets. |
| `burn-shares` | `(pool-id uint) (owner principal) (amount uint)` | Settlement-authority-only atomic CXLP burn after checking the canonical owner balance, selected pool total, and protocol-wide total. Does not settle a withdrawal. |
| `get-pool-outstanding-shares` | `(pool-id uint)` | Reads the selected pool's aggregate outstanding CXLP share total. |
| `get-total-outstanding-shares` | `()` | Reads the protocol-wide outstanding CXLP share total, which must equal canonical CXLP supply. |
| `get-recorded-share-supply` | `()` | Compatibility alias for `get-total-outstanding-shares`. |
| `collect-protocol-fees` | `(token <sip-010-ft-trait>)` | Fails closed with `u1008`; CLP fees are not segregated from pool/user custody and untracked assets must not be transferred. |
| `get-protocol-status` | `()` | Get the status of the CL pool contract. |

The existing fixed-route callers remain deliberately narrow in this phase.
`execute-csf-swap`, `swap-and-burn`, and `swap-router.exact-input-single`
retain their legacy pool-`u1`/token-0 assumptions; they are not general route
selection. The CLP pool/token binding makes an unknown pool, a reverse-order
explicit pool, or any token mismatch fail closed before CLP transfers. A later
fee-aware routing design must select the canonical pair-and-fee pool and its
orientation without changing this patch's public router or CSF signatures.

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
backing share operation. It records no reserves, fee growth, fee dust,
protocol-fee balances, or executed positions in this phase because the legacy
swap path cannot update such counters atomically. Those accounting surfaces are
deferred to the custody/execution phase while the original `get-pool` tuple ABI
is preserved.

`pool-registrar` starts as the deployment `tx-sender`. The one-time `initialize`
bootstrap transfers both admin and registrar together; later `set-admin` calls
do not mutate the registrar, and only the current admin may call
`set-pool-registrar`. Future execution wiring must inject the approved registrar
contract before delegating pool creation; this phase intentionally does not wire
an unresolved production principal. Both admin and registrar checks use
`contract-caller`, preventing an unconfigured forwarding contract from
inheriting an admin transaction sender's authority.

The CLP and `swap-aggregator` trait entrypoints for `collect-protocol-fees`
remain ABI-compatible but fail closed (`u1008` and `u1003`, respectively) for
every caller. Dedicated, segregated DEX fee custody and canonical settlement
must exist before either entrypoint can transfer assets. Until then, these
surfaces must not be composed with legacy or canonical fee collection on the
same base.
Legacy swap deductions are calculation behavior only: they are not segregated,
tracked as collectible protocol fees, or evidence that fee custody exists.

### `liquidity-manager.clar`
The liquidity-manager is a validated, unexecuted intent ledger. Every recorded
position starts with `accounted-liquidity: u0`; no token or pool mutation is
performed.

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
| `get-rebalance-advice` | `(position-id uint) (observed-tick int)` | Evaluates a caller-observed tick against the stored range. This intent-only advisory path deliberately does not consult or attribute a pool observation, and no rebalance is executed. `pool-current-tick-available: false` means unavailable to/unused by this path, not absent from the global pool API. |

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
- `concentrated-math.clar` — concentrated-liquidity tick and amount helpers.
  Execution-facing APIs are bounded, use a 1e12 price scale, and expose
  explicit round-down/round-up responses. Tick conversion remains a documented
  linear approximation rather than exact V3 math.

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

## Remaining prerequisites for full LP execution

The CXLP primitive, atomic share reconciliation hooks, and trusted zero-state
CLP read foundation are now available, but the integration still needs:

1. #536-owned token custody and transfer authorization for deposits/withdrawals;
2. on-chain LP position creation, ownership, and settlement accounting;
3. authorized reserve/liquidity and fee-growth mutation reconciled to custody;
4. executable current-tick/current-price transitions for swaps and rebalance;
5. position fee checkpoints, collection, protocol routing, and dust settlement;
6. exact concentrated-liquidity math and realized IL accounting.

CXLP is one global fungible token. Direct CXLP transfers and transfers through
the CLP proxy are real SIP-010 transfers: they change canonical owner balances
without changing supply or either CLP aggregate total. The CLP deliberately
does not maintain a duplicate owner or owner/pool ledger that ordinary
transfers could stale. Before any burn is exposed to users, #536 must supply
the per-position/per-pool attribution, custody, and settlement validation that
identifies the correct pool and owner amount; these hooks do not invent that
attribution.

Until those prerequisites exist, `liquidity-manager` remains a validated intent
ledger and deterministic risk proxy, not an LP executor.
