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
