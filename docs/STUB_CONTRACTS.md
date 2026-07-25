# Stub Contracts Reference (Updated Feb 2026)

## Overview
This document catalogs the status of placeholder (stub) contracts in the Conxian Protocol.

**Total Contracts:** ~218 (as per Clarinet.complete.toml)
**Active Implementations:** ~40+

---

## Recently Implemented Stubs

| Contract | Status | Description |
|----------|--------|-------------|
| `bond-token.clar` | ✅ Active | SIP-010 Bond Token implementation |
| `batch-auction.clar` | ✅ Active | MEV-protected batch auction engine |
| `oracle.clar` | ✅ Active | Canonical aggregate/TWAP oracle facade; raw spot and TWAP-validated price paths are explicit, while `set-price` remains advisory compatibility metadata |
| `protocol-invariant-monitor.clar` | ✅ Active | Deterministic solvency and constant-product invariant helpers with bounded tolerance and overflow handling |
| `rebalancing-rules.clar` | ✅ Active | Deterministic strict-threshold rebalance delta and direction helpers |
| `predictive-scaling-system.clar` | ✅ Active | Deterministic bounded activity, volatility-fee, and depth-liquidity helpers |
| `liquidity-manager.clar` | 🟡 Partial | Validated position/rebalance intent ledger and price-movement risk proxy; no LP custody, pool execution, fee accounting, or exact IL calculation |
| `automation-manager.clar` | ✅ Active | Automation coordination |
| `batch-processor.clar` | ✅ Active | Batch transaction helper |
| `rate-limiter.clar` | ✅ Active | Operation-specific rate limiting |
| `proof-of-reserves.clar` | ✅ Active | Cryptographically signed, live-reconciled quorum snapshots; deployment/oracle qualification not claimed |

---

## Remaining Stubs (Selection)

| Contract | Status | Size | Priority |
|----------|--------|------|----------|
| `real-time-monitoring-dashboard.clar` | 🚧 Stub | 1B | LOW |
| `pool-type-registry.clar` | 🚧 Stub | 1B | LOW |
| `pool-implementation-registry.clar` | 🚧 Stub | 1B | LOW |
| `nakamoto-compatibility.clar` | 🚧 Stub | 1B | MEDIUM |
| `on-chain-router-helper.clar` | 🚧 Stub | 1B | LOW |

---

## Implementation Priority Legend
- **HIGH**: Required for protocol security or revenue generation
- **MEDIUM**: Important for feature completeness
- **LOW**: Nice-to-have enhancements

Last Updated: February 2026
