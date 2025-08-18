## VAULT PRD (v1.1)

**Reference**: AIP-5 (Precision), Architecture doc, `vault.clar` implementation, SDK 3.5.0 testing compliance

**Status**: **STABLE** - Production Ready with SDK 3.5.0 compliance  
**Last Updated**: 2025-08-18  
**Next Review**: 2025-09-15

## 1. Summary & Vision

Core capital aggregation primitive providing share-based accounting, configurable fees, caps, and guarded parameterization via DAO & automation traits.

### 2. Goals

- Deterministic share math w/ precision safety.
- Fast deposits/withdrawals (O(1) storage writes typical).
- Extensible via strategy & admin traits (no internal upgrade logic).

### 3. Non-Goals

- Off-chain yield strategy definitions (handled by adapters).  
- Complex rebalance batching (future v2).

### 4. User Stories

| ID | Story | Priority |
|----|-------|----------|
| VAULT-US-01 | As a user I deposit tokens and receive proportional shares | P0 |
| VAULT-US-02 | As a user I redeem shares for underlying minus fees | P0 |
| VAULT-US-03 | As governance I set caps & fees within bounds | P0 |
| VAULT-US-04 | As automation module I adjust parameters w/ constraints | P1 |

### 5. Functional Requirements

| ID | Requirement |
|----|-------------|
| VAULT-FR-01 | Provide `deposit(amount)` returning minted shares. |
| VAULT-FR-02 | Provide `withdraw(shares)` returning underlying amount. |
| VAULT-FR-03 | Store & enforce global deposit cap. |
| VAULT-FR-04 | Support configurable deposit & withdraw bps fee (separate). |
| VAULT-FR-05 | Emit events on deposit, withdraw, fee-change. |
| VAULT-FR-06 | Enforce pause flag (AIP-1) on mutating ops. |
| VAULT-FR-07 | Use precision library for 18-dec calc (AIP-5). |
| VAULT-FR-08 | Expose read-only getters for TVL, sharePrice. |
| VAULT-FR-09 | Governance-only mutable operations gated & timelocked. |
| VAULT-FR-10 | Reentrancy-safe via Clarity state model & single write order. |

### 6. Non-Functional Requirements

- Gas efficiency: <= 2 map writes per deposit/withdraw (excluding fee param updates).  
- Deterministic math: No overflow; rounding direction documented.  
- Upgrade path: Migrate by deploying new vault & registry pointer update.  
- Test coverage: 100% for invariants & FR IDs.

### 7. Invariants

| ID | Invariant |
|----|-----------|
| VAULT-INV-01 | totalUnderlying == (sharePrice * totalShares) within rounding tolerance. |
| VAULT-INV-02 | totalShares never decreases except via withdrawals/burn logic. |
| VAULT-INV-03 | Fees collected cannot exceed configured bps bounds. |
| VAULT-INV-04 | Deposit after cap reached reverts. |

### 8. Data / State (Conceptual)

```clarity
maps: balances(principal) -> uint
vars: totalUnderlying, totalShares, depositFeeBps, withdrawFeeBps, cap, paused
```

### 9. Public Interface (Key)

- `deposit(u amount) -> (response (tuple (shares uint) (fee uint)) error)`
- `withdraw(u shares) -> (response (tuple (amount uint) (fee uint)) error)`
- `set-fees(u depBps, u wdBps)` (governance)
- `set-cap(u newCap)` (governance)
- `pause()` / `unpause()` (multi-sig / governance)

### 10. Core Flows

Deposit: validate !paused -> compute shares = (amount *totalShares)/totalUnderlying or bootstrap -> apply fee -> mint -> emit.  
Withdraw: compute underlying = (shares* totalUnderlying)/totalShares -> fee -> burn shares -> transfer underlying.

### 11. Edge Cases

- First deposit (bootstrap share price).  
- Zero amount deposit (reject).  
- Withdraw all shares → ensure totals zeroed consistently.  
- Cap boundary exactly equal to cap.

### 12. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Rounding extraction arbitrage | Consistent direction & invariant tests |
| Parameter grief (fee spike) | Timelock + bounds + event monitoring |
| Pause abuse | Multi-sig + transparency events |

### 13. Metrics

- TVL, sharePrice variance, deposit/withdraw counts, failed tx rate.  
- Time from proposal→execution for fee changes.

### 14. Monitoring

Circuit breaker ties into abnormal sharePrice delta > threshold. Health script logs metrics.

### 15. Open Questions

- Should performance fee be introduced pre v2?  
- Share price caching vs recompute each call.

### 16. Changelog

- **v1.1 (2025-08-18)**: SDK 3.5.0 compliance validation, production readiness confirmation, mainnet deployment approval
- **v1.0 (2025-08-17)**: Initial stable PRD extracted from implementation & docs

**Approved By**: Protocol WG, SDK Compliance Team  
**Next Review**: 2025-09-15  
**Mainnet Status**: **APPROVED FOR DEPLOYMENT**
