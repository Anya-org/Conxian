---
layout: default
title: Protocol Fee KPI Specification
permalink: /docs/PROTOCOL_FEE_KPI_SPEC/
---

# Protocol Fee KPI Specification (Phase 1 + approved Phase 2)

This document defines the evidence model for the canonical protocol-fee
collector introduced for issue #488. It is an indexed reporting specification,
not an on-chain activation policy. Native-unit accounting in Clarity remains
authoritative for settlement state; USD-normalized metrics are derived only
after the required asset metadata and oracle evidence are available.

## 1. Canonical fee-base policy

### 1.1 Eligible fee base

The canonical eligible fee-base volume for a reporting window is:

```text
eligible_fee_base_native(window, asset, stream)
  = sum(eligible-fee-base from successful protocol-fee-collected events
        whose (source, settlement-id) is unique and whose block is in window)
```

The collector emits exactly one `protocol-fee-collected` event per accepted
`(source, settlement-id)` pair. An indexer must de-duplicate by
`(source, settlement-id, tx-id, event-index)` and must exclude reverted
transactions. The source integration owns the fee-base definition and must call
the collector once for that base.

The following rules prevent double counting:

- A DEX flow counts the documented gross input once. Do not also count the
  output leg, an intermediate hop, or a legacy protocol tax on the same base.
- A lending flow counts the approved interest/reserve component, not principal,
  and must replace rather than add to an older charge on that component.
- An integration amount that is already fee revenue is not charged again by a
  percentage overlay. It can be routed into the canonical revenue path as a
  separate stream.
- A multi-hop or aggregator transaction is represented by the one registered
  source stream that owns the fee base. Intermediate transfer events are not
  additional eligible volume.
- Internal treasury transfers, deposits, withdrawals, rewards, and downstream
  allocations are excluded unless governance registers a separate fee-bearing
  stream.

### 1.1.1 Source-custody settlement contract

The source-custody API preserves the same eligible-base and scheduled-rate
policy while changing who supplies the assessed fee. A source's single atomic
entrypoint must call `preview-source-ft` or `preview-source-stx`, store a
private pending record containing the exact assessed amount, and immediately
call `settle-source-ft` or `settle-source-stx` in the same call stack. The
collector recomputes the preview and passes only the computed amount and fixed
`.protocol-fee-collector` recipient to the source callback. A separate public
prepare-then-consume flow is not an accepted implementation pattern, and a
`block-height` equality is not evidence that state was created in the same
transaction.

The callback authenticates the collector, fixed recipient, exact token (for
FT), exact amount, and the source's private pending record. The collector
authenticates the source/callback relationship and proves source custody with
an exact live-balance delta around the callback: the collector balance must
increase by exactly `assessed_native`. Underpay, overpay, no-transfer,
wrong-destination, callback, replay, transfer, or accounting failure reverts
the whole transaction. A zero-assessed settlement does not attempt a
zero-value transfer, but it still records the base, residual, and accounting
row and consumes the authenticated pending record. Existing untracked excess
remains outside collected-fee totals.

#### Indexer-derived custody mode

`custody_mode` is a normalized indexer field, not an explicit member of the
collector's on-chain settlement tuple or `protocol-fee-collected` event. Derive
it deterministically from the successful collector public function recorded in
the transaction call trace:

- `settle-ft` or `settle-stx` means `custody_mode = payer`;
- `settle-source-ft` or `settle-source-stx` means `custody_mode = source`.

The rule must use the collector function actually called for the accepted
settlement. Do not infer the value only from the `payer`, `source`, or transfer
events, and do not report that an on-chain `custody_mode` field exists. If the
call trace cannot identify one of these four entrypoints, retain the receipt
for audit but mark the normalized field unavailable rather than guessing.

The approved lending migration uses this API only for the interest component
`floor(amount * 1000 / 10000)`. The fee replaces the legacy 1% full-repayment
charge on that designated base; principal is never an eligible fee base, and
the lending manager credits reserves with net interest after the protocol fee.

### 1.2 Scheduled rates and residual arithmetic

The schedule is driven by the burn-block policy clock, not wall time:

- launch: 200 bps from `activation` through `activation + 52,559`;
- growth: 150 bps from `activation + 52,560` through
  `activation + 157,679`; and
- mature: 100 bps from `activation + 157,680` onward.

`52,560` is the 365-day approximation at six burn blocks per hour and
`157,680` is the three-year approximation. Bitcoin burn-block production is not
exactly six blocks per hour, so these are policy boundaries rather than exact
calendar dates. A future activation height returns `not active` before launch.

Settlement arithmetic carries a numerator remainder per registered
`(source, stream, asset)`:

```text
numerator = eligible_base * rate_bps + prior_remainder
assessed  = floor(numerator / 10,000)
remainder = numerator mod 10,000
```

The remainder is retained across phase changes because every phase uses the
same denominator. A positive base can therefore produce an assessed amount of
zero; the collector records the accepted base, zero assessed/settled amount,
and new remainder without attempting a zero-value transfer. Stream asset and
route identity is immutable after registration, so a later configuration call
cannot erase economically relevant residual state.

### 1.3 Native units and USD normalization

On-chain values are stored and summed per asset in native base units. No value
such as `u1000000` is interpreted as `$1M` without all of the following:

1. the asset contract or native-asset identifier;
2. the asset decimal precision and metadata version;
3. the oracle source, price pair, oracle round/version, and quote timestamp;
4. a freshness limit and the rule for stale or missing prices; and
5. a fixed aggregation window and time zone.

Cross-asset totals are therefore a separate indexed view:

```text
eligible_fee_base_usd(window)
  = sum(native_amount / 10^decimals * oracle_price_usd)
```

Rows missing any required normalization evidence are retained in native units
but excluded from the USD total and marked `usd_status = unavailable`.

The `$1M daily eligible volume` milestone is this indexed, USD-normalized KPI. It is
not an activation gate and does not change the collector's burn-block schedule.

## 2. Fee and revenue vocabulary

| Measure | Definition | Phase-1 evidence |
| --- | --- | --- |
| Eligible fee-base volume | Registered source base before the scheduled rate | `protocol-fee-collected.eligible-fee-base` event |
| Fees assessed | Scheduled fee computed with the stream's residual numerator | `assessed-amount` event field and collector accounting |
| Fees settled at collector ingress | Assessed amount atomically received by `.protocol-fee-collector` either from payer custody or an authenticated source callback; may be zero when only a residual is carried | `settled-amount`, fixed `recipient`, exact custody delta, transfer event when nonzero, and collector accounting |
| Fees routed to operational treasury | Amount later forwarded from collector custody to the immutable `.operational-treasury` destination | `protocol-fee-routed-to-operational-treasury` event and asset accounting |
| Realized downstream protocol revenue | Amount later accepted by a downstream revenue, swap, burn, or Fiscal Dam operation | Downstream transfer/route events; never inferred from ingress assessment |
| Treasury inflows | Amount actually received by the treasury or its configured vault | Destination transfer events and vault state |
| Executed allocation | Amount released by the approved Fiscal Dam/vault allocation | Allocation approval/release events and vault state |

In phase 1, the collector writes `assessed-fees` and `settled-fees` only after
the payer-to-collector transfer succeeds; it does not call a downstream route in
that transaction. For a positive base whose residual calculation yields zero,
the accepted event and accounting row are still evidence, but no zero-value
transfer is attempted. A `protocol-fee-collected` event proves collection at
collector ingress only. A separate route event proves only the fixed
collector-to-treasury transfer; neither event alone proves realized downstream
revenue or later allocation execution.

## 3. KPI formulas

All window formulas use half-open intervals `[window_start, window_end)` and
the same finalized event set. Window boundaries are UTC calendar boundaries
for daily metrics and rolling 30 * 24-hour windows for `30d`; the indexer must
record the exact block timestamp used for each row.

### 3.1 Rate and coverage

```text
realized_take_rate(window)
  = realized_protocol_revenue_usd(window)
    / eligible_fee_base_usd(window)

settlement_coverage(window)
  = fees_settled_native(window) / fees_assessed_native(window)
```

The take-rate numerator and denominator must use the same asset set and price
evidence. If a denominator is zero, the KPI is `null`, not zero. Coverage is
reported per asset and stream before any cross-asset rollup.

### 3.2 Activity and retention

```text
active_fee_paying_principals(window)
  = count(distinct payer where at least one qualifying settlement event exists)

repeat_use_rate(window)
  = count(distinct payer with >= 2 qualifying settlement IDs in window)
    / active_fee_paying_principals(window)

30d_retention(cohort_window, followup_window)
  = count(distinct payer active in cohort_window and followup_window)
    / count(distinct payer active in cohort_window)
```

Settlement IDs, not transaction count, define repeat use. A source may submit
multiple streams in one transaction; each registered stream remains one
qualifying settlement only when its settlement ID is unique and successful.

### 3.3 Allocation realization

```text
allocation_realization(window)
  = executed_allocation_usd(window)
    / realized_protocol_revenue_usd(window)
```

The numerator is based on successful vault/allocation releases, not planned,
approved, or reserved amounts. The KPI is reported by Fiscal Dam category and
asset before aggregation. The collector does not implement a direct gross
50/30/20 split; CXIP-013/Fiscal Dam remains the governing allocation policy.

## 4. Evidence schema

The minimum normalized settlement row is:

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `tx_id` | hex string | yes | Stacks transaction identifier |
| `event_index` | integer | yes | Indexer event position in the transaction |
| `settlement_id` | 32-byte hex | yes | Collector replay-protection key scoped by `source` |
| `source` | principal | yes | Registered immediate caller; production KPI evidence should prefer a contract source |
| `stream_id` | uint | yes | Registered fee stream |
| `payer` | principal | yes | `tx-sender` that funded the atomic transfer |
| `asset_kind` | enum | yes | `ft` or `stx` |
| `asset` | optional principal | yes | FT contract when present; `none` for native STX plus `asset_kind = stx` |
| `eligible_base_native` | uint | yes | Fee base in the asset's native units |
| `rate_bps` | uint | yes | Resolved on-chain rate: 200, 150, or 100 |
| `phase` | enum | yes | Launch, growth, or mature |
| `assessed_native` | uint | yes | Fee calculated by the collector, including zero-fee residual settlements |
| `settled_native` | uint | yes | Amount transferred to `.protocol-fee-collector`; equal to assessed in phase 1 |
| `fee_remainder` | uint | yes for accounting snapshots | Numerator remainder modulo 10,000 after the settlement |
| `recipient` | principal | yes | Fixed `.protocol-fee-collector` settlement custody principal |
| `burn_height` | uint | yes | Burn-block context emitted by Clarity |
| `stacks_height` | uint | yes | Stacks-block context emitted by Clarity |
| `block_time` | timestamp | yes for USD windows | Indexer-resolved block timestamp |
| `custody_mode` | enum (indexer-derived) | yes | `payer` or `source`, derived from the collector public function; not an on-chain tuple/event field |
| `decimals` | integer | yes for USD | Immutable/versioned asset metadata |
| `oracle_source` | string | yes for USD | Price source identifier |
| `oracle_round` | string/uint | yes for USD | Price round/version |
| `oracle_price_usd` | decimal | yes for USD | Price used for normalization |
| `oracle_observed_at` | timestamp | yes for USD | Price observation time |
| `usd_status` | enum | yes | `available`, `stale`, `missing`, or `invalid` |
| `eligible_base_usd` | decimal/null | yes | Normalized amount or null when unavailable |

Asset metadata, oracle evidence, and KPI window definitions should be stored
alongside the row or in versioned dimension tables so a historical KPI can be
reproduced after an oracle or decimal registry update.

## 5. Source of truth and current limits

| KPI/evidence | Authoritative source | Available from current SDK alone? |
| --- | --- | --- |
| Rate, phase, activation, stream config | Collector Clarity read-only state | Yes for a connected simnet/node call |
| Assessed/settled native amounts | Collector state and successful `print` event | Yes for transaction receipts in tests; historical production data needs an indexer |
| `(source, settlement-id)` uniqueness | Collector replay map plus indexed transaction events | No, not as a chain-wide historical query |
| Payer/source/asset/fee-base event fields | Hiro transaction `contract_log` / `print` events | No, use the indexed API or equivalent indexer |
| Daily and 30d windows | Indexed finalized events plus block timestamps | No |
| Decimals and token identity | Clarity token metadata and a versioned asset registry | Partially |
| USD-normalized volume and take rate | Indexed native values plus oracle rounds/freshness | No |
| Treasury inflows and executed allocations | Destination transfer events, vault state, and Fiscal Dam records | No |
| Active principals and retention | Indexed unique payer/event history | No |

The Clarinet JS SDK is the local simulation/test harness, not a historical
production index. A production KPI job must persist transaction IDs, event
indices, block timestamps, normalization evidence, and the query version used
to build each window.

## 6. Source trust and phase-2 boundary

The collector accepts admin-authorized source principals so simnet fixtures and
controlled migrations can exercise the same settlement surface. This is an
operational authorization boundary, not proof that an EOA-derived base is
trustless. Production source registrations should be contract principals whose
own successful economic operation derives and submits the eligible base. An
admin-authorized EOA may be used operationally, but its events must not be
treated as independent KPI evidence without an external trust designation.

The collector's settlement ingress is the immutable relative
`.protocol-fee-collector` principal. Authorized admin or approved governance
contracts may route custody only to the immutable relative
`.operational-treasury` principal; no function accepts an arbitrary destination.
The collector requires the treasury's initialized flag before routing and
rejects any amount beyond the asset's collected-but-not-yet-routed balance.
Direct deposits are not collected fees: excess recovery computes the live
collector balance minus tracked collected-but-not-yet-routed custody with
checked subtraction, and only the positive remainder can be sent to that same
fixed treasury destination. Excess-recovered totals and events are separate
from collection and routing totals. A route or recovery transfer failure rolls
back its accounting and event. Neither collection, routing, nor recovery claims
Fiscal Dam allocation, DEX/lending routing, burning, or downstream realized
revenue in the same transaction. The approved phase-2 lending path is
implemented in `lending-manager.repay` but still requires explicit admin
asset-to-stream configuration before it can settle; no deployment or source
authorization is implied by these checked-in contracts. DEX migration remains
deferred because concentrated-liquidity-pool custody/execution is stubbed, and
`lending-orchestrator`, partnership splits, and deployment broadcasting remain
outside this slice.

The checked-in production deployment plans and generator intentionally defer
collector publication and wiring until network-correct deployer identities and
source migrations are approved. Production bootstrap must initialize the
operational treasury, configure the approved governance/timelock/multisig, and
hand collector admin to that approved contract before source registration;
deployer admin retention is not production-ready. Governance may pause or
execute fixed-destination custody operations but cannot redirect custody.

The `$1M daily eligible volume` milestone remains an indexed/oracle-derived KPI
and is not an activation gate.

## 7. Research and implementation references

These are the canonical references used for the schema and evidence model:

- [Stacks Clarity keywords](https://docs.stacks.co/reference/clarity/keywords):
  `burn-block-height`, `stacks-block-height`, `print`, and caller context.
- [Hiro Clarinet project guide](https://docs.hiro.so/stacks/clarinet/guides/anatomy-of-a-clarinet-project):
  Clarinet JS SDK and Simnet project/test structure.
- [Hiro transaction events API](https://docs.hiro.so/en/apis/stacks-blockchain-api/reference/transactions/get-transaction-events):
  transaction event indices and `contract_log`/`print` event payloads.
- [Hiro API architecture](https://docs.hiro.so/en/apis/stacks-blockchain-api/architecture):
  indexed smart-contract log and transfer data model.
- [DefiLlama data definitions](https://docs.llama.fi/analysts/data-definitions):
  distinction between user fees, protocol revenue, token-holder revenue, and
  DEX volume.
- [DefiLlama dimensions](https://docs.llama.fi/list-your-project/other-dashboards/dimensions):
  daily volume, daily fees, daily user fees, and daily protocol revenue
  attribution.
- [DefiLlama methodology overview](https://docs.llama.fi/):
  reproducible metric methodology and no-double-counting principles.

These references inform the reporting vocabulary; they do not replace the
collector's native-unit accounting or authorize any on-chain rate change.

Last updated: July 22, 2026
