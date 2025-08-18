## Oracle Aggregator PRD (v0.2 Draft)

### Summary

Aggregate multiple oracle sources (internal DEX TWAP, external signed feeds) with configurable weighting & staleness limits feeding vault & risk modules.

### Functional Requirements

| ID | Requirement |
|----|-------------|
| ORA-FR-01 | Register oracle sources with type + decimals. |
| ORA-FR-02 | Validate update freshness (max age). |
| ORA-FR-03 | Compute median or weighted median price. |
| ORA-FR-04 | Expose read-only `get-price(asset)` with last update block. |
| ORA-FR-05 | Emit events on source add/remove & price update. |
| ORA-FR-06 | Circuit-break if deviation > threshold vs last TWAP. |

### Risks

| Risk | Mitigation |
|------|------------|
| Stale data | Max age enforcement & monitoring |
| Single-source manipulation | Require min N sources for consensus |
| Precision mismatch | Normalize decimals & invariant tests |

Changelog: v0.2 (2025-08-17) draft skeleton.

### Current Implementation Status (2025-08-18)

| Area | Implemented | Notes |
|------|-------------|-------|
| Pair Registration | Yes | `register-pair` enforces admin + min-sources ≤ oracles length |
| Oracle Whitelist | Yes | Explicit map `oracle-whitelist`; enforced in `submit-price` (ERR_NOT_ORACLE u102) |
| Price Submission | Yes | Aggregates when min-sources reached; returns tuple `{ aggregated, sources, price }` |
| Median | Simplified | Uses incremental stats + per-oracle map then a simplified median helper (not full weighted median yet) |
| History / TWAP | Basic | Fixed-size ring buffer (size 5) + simple average in `get-twap`; no time-weight weighting yet |
| Manipulation Detection | Minimal | No dedicated deviation threshold check yet (placeholder in design) |
| Circuit Breaker Hook | Pending | To integrate deviation output once detection implemented |
| Staleness / Max Age | Pending | Need block-age guard in `submit-price` & consumer read paths |
| Decimals Normalization | Pending | Assumes uniform precision for now |
| Governance Controls | Partial | Admin mutable; not yet timelock/DAO-routed |

### Immediate Roadmap (v0.3 Targets)

1. Implement deviation + staleness guards (ORA-FR-02 / ORA-FR-06) with configurable thresholds.
2. Upgrade median to deterministic weighted median with >5 sources (sorting window) and gas benchmarks.
3. Expand history window & introduce time-weight in TWAP (block delta weighting) replacing naive average.
4. Add decimal normalization & per-source metadata (source type, decimals, reliability score).
5. Emit dedicated events: `oa-submit`, `oa-aggregate`, `oa-manipulation` with structured codes.
6. Governance integration: route admin mutations via timelock + DAO vote (align with AIP controls).
7. Add staleness failure code (u106 provisional) and manipulation code range (u120+).
8. Formalize gas cost ceiling (<3 STX deploy, <150k execution typical path) with benchmark doc.

### Test Coverage Summary

| Test Suite | Coverage Intent |
|------------|-----------------|
| `oracle_aggregator_test.ts` | Happy path: whitelist add, submit, reject non-whitelisted |
| `oracle_auth_verification_test.ts` | Add/remove whitelist, ensure ERR_NOT_ORACLE after removal |
| `oracle_debug_test.ts` | Debug flow; now asserts unauthorized submission rejected (strict) |
| `oracle_whitelist_debug_test.ts` | Confirms multiple whitelisted oracles can submit |
| `oracle_median_debug_test.ts` | Verifies price count, median progression |

### Security Notes

Current whitelist enforcement is critical; median & TWAP simplifications mean manipulation resistance depends on min-sources configuration. Until deviation + staleness checks land, recommend:

* Min sources ≥2 for production pairs.
* Circuit breaker external monitoring of large single update deltas.
* Accelerated implementation of roadmap items 1 & 2 above before mainnet activation of multi-asset feeds.

---
