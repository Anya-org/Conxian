## DEX / Liquidity Layer PRD (v0.3 Draft)

### Summary

AMM subsystem (factory, pools, router, future variants) to support internal price discovery, vault strategy interactions, and external liquidity.

### Current Scope (Phase 0)

- Constant product pools (baseline)  
- Router single-hop swaps  
- Factory for pool creation  

### Planned (Phase 1)

- Multi-hop routing (path discovery)  
- Stable & weighted pool math hardening  
- Circuit breaker hooks & TWAP surfaces  

### Out of Scope (Future)

- Concentrated liquidity, MEV auctions, batch matching.

### Key Functional Requirements

| ID | Requirement |
|----|-------------|
| DEX-FR-01 | Create pool with token pair & fee tier. |
| DEX-FR-02 | Add/remove liquidity receiving LP tokens. |
| DEX-FR-03 | Swap exact-in & exact-out paths (single hop phase 0). |
| DEX-FR-04 | Fee accrual tracked per pool. |
| DEX-FR-05 | Events for swap, add, remove, fee-update. |
| DEX-FR-06 | Circuit-breaker integration halts abnormal price delta. |
| DEX-FR-07 | Oracle interface exposes cumulative price for TWAP. |

### Metrics

- Liquidity depth, swap volume, fee APR, price divergence vs external.

Changelog: v0.3 (2025-08-17) initial draft consolidation.
