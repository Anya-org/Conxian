---
layout: default
title: Protocol Fee KPI Specification
permalink: /docs/PROTOCOL_FEE_KPI_SPEC/
---

# Protocol Fee KPI Specification (Phase 1)

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
  = sum(eligible-fee-base from successful protocol-fee-settled events
        whose settlement-id is unique and whose block is in window)
```

The collector emits exactly one settlement event per accepted settlement ID.
An indexer must de-duplicate by `(settlement-id, tx-id, event-index)` and must
exclude reverted transactions. The source integration owns the fee-base
definition and must call the collector once for that base.

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

### 1.2 Native units and USD normalization

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

The `$1M daily volume` milestone is this indexed, USD-normalized KPI. It is
not an activation gate and does not change the collector's burn-block schedule.

## 2. Fee and revenue vocabulary

| Measure | Definition | Phase-1 evidence |
| --- | --- | --- |
| Eligible fee-base volume | Registered source base before the scheduled rate | `protocol-fee-settled.eligible-fee-base` event |
| Fees assessed | Scheduled fee computed from the base | `assessed-amount` event and collector accounting |
| Fees settled | Amount transferred successfully through the configured route | `settled-amount` event and collector accounting |
| Realized protocol revenue | Amount that reaches the protocol-owned downstream revenue route after settlement | Transfer/route events; not inferred from assessment alone |
| Treasury inflows | Amount actually received by the treasury or its configured vault | Destination transfer events and vault state |
| Executed allocation | Amount released by the approved Fiscal Dam/vault allocation | Allocation approval/release events and vault state |

In phase 1, the collector writes `assessed-fees` and `settled-fees` together
only after both the payer transfer and fixed downstream call succeed. The
separate vocabulary is retained so future routing can distinguish a fee that
was assessed from one that was realized or allocated. A collector event is not
proof that a later treasury allocation executed.

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
| `settlement_id` | 32-byte hex | yes | Collector replay-protection key |
| `source` | principal | yes | Registered immediate caller |
| `stream_id` | uint | yes | Registered fee stream |
| `payer` | principal | yes | `tx-sender` that funded the atomic transfer |
| `asset_kind` | enum | yes | `ft` or `stx` |
| `asset` | optional principal | yes | FT contract when present; `none` for native STX plus `asset_kind = stx` |
| `eligible_base_native` | uint | yes | Fee base in the asset's native units |
| `rate_bps` | uint | yes | Resolved on-chain rate: 200, 150, or 100 |
| `phase` | enum | yes | Launch, growth, or mature |
| `assessed_native` | uint | yes | Fee calculated by the collector |
| `settled_native` | uint | yes | Fee successfully routed by the collector |
| `burn_height` | uint | yes | Burn-block context emitted by Clarity |
| `stacks_height` | uint | yes | Stacks-block context emitted by Clarity |
| `block_time` | timestamp | yes for USD windows | Indexer-resolved block timestamp |
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
| Settlement ID uniqueness | Collector replay map plus indexed transaction events | No, not as a chain-wide historical query |
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

## 6. Research and implementation references

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
