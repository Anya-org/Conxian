# Executable Concentrated Liquidity Pool V2

**Issue:** CON-1541

**Calculation version:** `clp-v2-linear-v1`
**Price source:** `pool-executable-state`

## Version boundary

`concentrated-liquidity-pool-v2` is a new custody and execution source of truth. It does not mutate, wrap, or silently route through the legacy `concentrated-liquidity-pool` contract. Legacy CLP and transferable CXLP APIs remain compatibility surfaces and are not executable V2 entitlements. The router and liquidity manager expose separately named V2 entrypoints; every legacy entrypoint and semantic remains unchanged.

V2 deliberately leaves CXLP outside the model. A transferable aggregate token cannot prove ownership of a specific pool, range, entry basis, fee checkpoint, or withdrawal lot. The canonical entitlement is the non-transferable V2 position ID and its immutable owner/range/liquidity record. V2 exposes no CXLP mint, burn, transfer, or compatibility authorization path, so there is only one entitlement model.

## Bounded model

| Bound | Value |
|---|---:|
| Fixed-point sqrt-price scale, `Q` | `1e12` |
| Tick envelope | `[-5000, 10000]` |
| Linear tick increment | `1e8` sqrt-price units |
| Position/pool liquidity | `<= 1e12` |
| Exact swap input | `<= 1e12` |
| Initialized ticks per pool | `<= 16` |
| Tick crossings per swap | `<= 8` |
| Fee tiers | `500`, `3000`, `10000` pips |
| Tick spacing | `10`, `60`, `200`, respectively |

The V1 V2-grid mapping is injective and linear:

```text
sqrtPrice(tick) = Q + tick * 1e8
```

It is not Uniswap's logarithmic tick grid and must not be represented as one. `sqrt-price-to-tick` returns the greatest grid tick whose price is less than or equal to the supplied sqrt price.

The initialized-tick list contains only currently initialized tick keys. Final removal compacts the bounded list, so closed ranges release their slots and later distinct ranges can reuse capacity. Nearest-tick scans therefore remain statically bounded to sixteen active keys without creating a lifetime exhaustion condition.

## Math and rounding

For `sa < sb`, current sqrt price `s`, and liquidity `L`:

```text
amount0 = L * Q * (sb - sa) / (sb * sa)
amount1 = L * (sb - sa) / Q
```

- At or below the lower boundary, the position is token0-only.
- Strictly inside the range, token0 covers `[s, sb]` and token1 covers `[sa, s]`.
- At or above the upper boundary, the position is token1-only.
- Entry requirements round up.
- Principal/output claims round down.
- Liquidity is derived from user maxima using the limiting side, then required amounts are recomputed with ceil rounding. V2 never mints liquidity that either maximum cannot support.

The declared bounds keep the largest relevant products below uint128. Every addition, subtraction, multiplication, divisor, and ceil division is nevertheless checked and returns a stable error instead of panicking.

Exact-input price steps use net input after that step's fee:

```text
token0 in, price down:
sNext = ceil(L * Q * s / (L * Q + x * s))

token1 in, price up:
sNext = s + floor(x * Q / L)
```

Each step clamps to the nearest initialized tick or the caller's price limit. A boundary step uses ceil input and floor output. Crossing updates fee-growth-outside after charging the liquidity active before that crossing, then applies the tick's signed upward liquidity net (or its inverse when crossing downward). The fixed eight-element fold makes a ninth crossing fail atomically. The full caller input must be consumed; otherwise the swap fails without state or custody changes.

## Custody and accounting invariants

Pool state separately tracks:

- token0/token1 principal;
- unpaid LP fee liabilities;
- protocol fees;
- fee-distribution dust;
- actual SIP-010 custody;
- direct-donation surplus or custody shortfall.

`get-reconciliation` is public rather than read-only because Clarity trait-dispatched SIP-010 balance calls are conservatively treated as potentially writing. The function performs no writes.

Add liquidity verifies the exact post-transfer custody increase for both token contracts. Swaps verify the exact input increase and exact output decrease. Failed second-token transfers, slippage checks, price-limit checks, crossing bounds, output transfers, and custody-delta checks roll back all prior writes and cross-contract transfers.

Principal claims can debit only tracked principal. LP fee collection can debit only tracked LP liabilities. Neither path can debit protocol fees, fee dust, or donation surplus. Direct token transfers to the contract are visible only as donation surplus.

## Positions and ticks

Positions are immutable liquidity lots:

- owner, pool, range, and liquidity do not change;
- there is no partial removal;
- `remove-liquidity` closes the full lot atomically;
- fee collection updates fee checkpoints/remainders but never principal or tick liquidity;
- close records actual cumulative settlement, close sqrt price, and close height.

Ticks track gross liquidity, signed upward liquidity net, and fee-growth-outside for each asset. Final removal marks a zero-gross tick uninitialized and decrements the pool's active initialized-tick count. Active pool liquidity contains only positions whose half-open range contains the executable current tick.

Fee growth uses scale `Q`. Per-step LP growth is floored; the undistributed residue is explicit pool dust. Each position carries its own fractional numerator remainder between collections, preventing repeated collection from discarding or double-counting fractional entitlement.

## Public API

### Pool and state

- `create-pool(token-0, token-1, fee-pips, initial-tick)`
- `create-pool-checked(token-0, token-1, fee-pips, initial-sqrt-price, initial-tick)`
- `set-pool-active(pool-id, active)`
- `get-pool(pool-id)`
- `get-tick(pool-id, tick)`
- `get-position(position-id)`

There is no price setter. Executable sqrt price and current tick change only in a successful `swap-exact-input` transaction.

### Liquidity and fees

- `add-liquidity(pool-id, token-0, token-1, lower-tick, upper-tick, max-amount0, max-amount1, min-liquidity)`
- `collect-fees(position-id, token-0, token-1, recipient)`
- `remove-liquidity(position-id, token-0, token-1, min-amount0, min-amount1, recipient)`

### Execution and reconciliation

- `swap-exact-input(pool-id, token-in, token-out, zero-for-one, amount-in, sqrt-price-limit, min-amount-out, recipient)`
- `get-reconciliation(pool-id, token-0, token-1)`
- `get-position-pnl(position-id)`
- `get-exact-il(position-id)`

### Versioned integration surfaces

- `liquidity-manager.open-position-v2` validates compliance and canonical V2 pool/token state, then calls V2 without pre-custody. Its manager map is keyed by the canonical V2 position ID and stores linkage metadata only after the pool succeeds.
- `liquidity-manager.close-position-v2` is owner-only even if the caller is the legacy manager admin. It validates the manager record against the authoritative V2 owner, active lot, pool, range, liquidity, and token order before a full close to `tx-sender`.
- `liquidity-manager.rebalance-position-v2` closes the old immutable lot to `tx-sender`, opens the replacement from `tx-sender`, and updates manager metadata only after both calls succeed. A replacement failure rolls back the close, custody transfers, ticks, accounting, and metadata atomically.
- `liquidity-manager.get-v2-position-pnl` and `get-v2-exact-il` proxy V2 executable-state valuation. They do not use the legacy configured oracle and do not relabel outperformance as IL.
- `swap-router.exact-input-single-v2` reads canonical token order and current sqrt price from V2, derives direction internally, applies router pause/source-isolation policy, and calls `swap-exact-input` without router custody.

These V2 entrypoints accept amount, liquidity, and price-limit constraints only. They do not accept a trusted caller-supplied tick, oracle price, execution price, sqrt price, or direction.

## PnL and exact IL semantics

PnL values use token1 as the valuation unit and the executable pool price:

```text
price(token1/token0) = sqrtPrice^2 / Q
```

The view reports actual entry debits, current principal (or actual cumulative settlement for a closed position), claimable fees, HODL value, LP principal value, fee value, net LP value, signed PnL as sign plus magnitude, loss-only underperformance/IL, and separate outperformance. A gain is never labeled positive IL. Closed positions use their recorded close price and actual settlement.

This is distinct from any oracle-based price-movement proxy. V2 does not use an oracle to rewrite executable state or call an oracle proxy “IL.”

## Release gates

Protocol fees remain separately accounted and locked. `release-protocol-fees-disabled` always returns `ERR-PROTOCOL-RELEASE-DISABLED`; there is no sweep, direct transfer, or no-op success path.

The exact blocker is a rate-base mismatch: V2 already reserves a fixed 10% share of each assessed swap fee, while `protocol-fee-collector.settle-source-ft` applies the collector's own governed schedule to an eligible fee base. Passing either the gross swap amount or the already-reserved V2 amount through that API would respectively double-rate the trade or assess the reserved amount again; transferring first would also strand or misstate source custody relative to the collector's exact-delta callback model.

Governance must choose and audit one of two explicit designs before release can be enabled:

1. **Collector replaces the fixed V2 share.** Remove the fixed 10% reservation from V2 accounting and let the collector compute the only protocol assessment from a precisely defined eligible base.
2. **Collector accepts reviewed fixed-amount ingress.** Add a separately reviewed collector API that authenticates V2, accepts the already-calculated fixed amount without applying another schedule, enforces replay protection, and proves the exact same-transaction custody delta.

Until one option is approved and implemented end to end, V2 must not call `settle-source-ft`, transfer or sweep protocol reserves, or publish collector accounting that implies settlement occurred.

CSF compatibility methods return `ERR-COMPATIBILITY-UNAVAILABLE`. They do not fabricate marker registration, flash liquidity, arbitrage settlement, yield, health, or an implicit pool `u1` route. The versioned router/manager entrypoints call V2 directly and do not misrepresent it as a CSF-compatible source.
