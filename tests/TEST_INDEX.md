# Conxian Protocol: Testing Index (July 2026)

## Overview
The Conxian Protocol utilizes a "Dual-Mode" testing architecture. This ensures that contracts are fully compatible with current simulation environments (Clarinet SDK / Simnet) while remaining pre-wired for the Clarity 4 Mainnet Standard (Stacks Epoch 3.0).

## Dual-Mode Architecture
- **block-utils.clar**: Acts as a compatibility layer, providing safe wrappers for Nakamoto primitives (`stacks-block-time`, `secp256r1-verify`, etc.).
- **Principal Injection**: Circular dependencies are broken by using `data-vars` for external contract principals instead of hardcoded literals.

## Verified Test Suites (Leaf-to-Root)

### Leaf Unit Tests (Core & Agents)
1. ✅ **tests/core/conxian-protocol.test.ts**: Protocol management, pausing, and module registration.
2. ✅ **tests/core/dimensional-engine.test.ts**: Executive facade for leverage trading.
3. ✅ **tests/core/founder-vesting.test.ts**: Time-locked vesting logic.
4. ✅ **tests/core/conxian-protocol-batch.test.ts**: Batch operations availability.
5. ✅ **tests/core/risk-manager.test.ts**: Canonical risk-unit initialization, math, cache freshness, score bounds, facade safety, and agent publication.
6. ✅ **tests/agents/aye-pid.test.ts**: Agent-risk compatibility/PID entrypoint coverage; full PID dynamics remain outside this suite.
7. ✅ **tests/core-contracts.test.ts**: Basic contract deployment and status checks.

### Intermediate Leaf Tests (DEX & Governance)
8. ✅ **tests/dex/concentrated-liquidity-pool.test.ts**: Pool creation and state.
9. ✅ **tests/dex/concentrated-liquidity.test.ts**: Math library for CL.
10. ✅ **tests/dex/protocol-fee-collection.test.ts**: CLP and aggregator fee collection fail closed for admin/non-admin callers, preserve token balances, and stop fiscal orchestration before BME minting.
11. ✅ **tests/tokens/cxlp-token.test.ts**: CXLP role authorization, aggregate pool/supply accounting, direct/proxy transfer preservation, rollback, and canonical proxies.
12. ✅ **tests/dex/swap-router.test.ts**: Swap routing and fee logic.

#### CLP V2 Focused Suites

- ✅ **tests/math/concentrated-math-v2.test.ts**: Fixed-scale linear tick mapping, bounded math, rounding, principal/liquidity deltas, and exact-input swap-step vectors.
- ✅ **tests/dex/concentrated-liquidity-pool-v2.test.ts**: Canonical V2 pool creation, custody deltas, range positions, tick/fee accounting, full closes, bounded swaps, and reconciliation.
- ✅ **tests/dex/clp-v2-intermediary.test.ts**: Intermediary-call regressions for `tx-sender`, ownership, custody, and manager/router V2 isolation.
- ✅ **tests/dex/liquidity-manager-v2.test.ts**: Separately named V2 open, owner-only full close, atomic rebalance, canonical position linkage, and PnL/IL proxies.
- ✅ **tests/dex/swap-router-v2.test.ts**: Direct-custody V2 routing, canonical direction and price-limit orientation, pause/source isolation, recipients, and rollback.

These paths are source inventory entries. Executed/collected test totals are run-specific evidence and must be recorded separately with a date and run reference.

13. ✅ **tests/governance/reputation-engine.test.ts**: Weighted voting power.
14. ✅ **tests/governance/proposal-engine.test.ts**: Governance signal processing.
15. ✅ **tests/governance/proposal-engine-core.test.ts**: Seat-based voting and submission.
16. ✅ **tests/governance/proposal-engine-admin.test.ts**: Admin overrides.
17. ✅ **tests/governance/enhanced-governance-nft.test.ts**: Seat minting and power tracking.
18. ✅ **tests/governance/proposal-registry.test.ts**: Persistent proposal storage.
19. ✅ **tests/governance/conxian-operations-engine.test.ts**: Root heartbeat coordination.
20. ✅ **tests/governance/executive-agents.test.ts**: Autonomous Staff (CRO/Sovereign-Financial-Office) logic.
21. ✅ **tests/governance/sab-election.test.ts**: Escrowed SAB election cycles, quorum/tie finalization, and stake claims.
22. ✅ **tests/governance/upgrade-controller.test.ts**: Release authorization, signer thresholds, timelock, rollout, and rollback.
23. ✅ **tests/governance/gauge-manager.test.ts**: Canonical escrowed gauge voting, caps, epoch finalization, and withdrawals.

### Vault & Custody Tests
24. ✅ **tests/vaults/sbtc-vault.test.ts**: Canonical-token-bound sBTC custody, immutable token configuration, receipt reconciliation, token transfer/balance failure normalization, compliance adapter failure isolation, aggregate insolvency rejection, cap validation, pause controls, admin transfer, share accounting, withdrawals, and disabled strategy allocation.

### System Root Tests (Integration)
25. ✅ **tests/system/full-protocol-journey.test.ts**: Coordination between Heartbeat, DEX, and Agents.
26. ✅ **tests/cybernetic-revenue.test.ts**: Dynamic "Fiscal Dam" allocation (CXIP-013).
27. ✅ **tests/cxip-012.test.ts**: Volatility-based DEX fee adjustments.
28. ✅ **tests/nakamoto_verification.test.ts**: Tenure info and block utility checks.
29. ✅ **tests/protocol-fee-collector.test.ts**: Scheduled FT/STX compatibility, immutable fixed-100 FT registration and phase-independent policy introspection, payer/source custody settlement, residual/accounting/policy audit fields, excess recovery, routing, authorization, replay, exact events, and rollback.
30. ✅ **tests/partner-policy-registry.test.ts**: Dormant STX/microSTX v1 defaults, exact floor/remainder preview math, dynamic authorization handoff, immutable sequential policy periods, unsupported mode and role rejection, policy/partner lifecycle transitions, fail-closed missing/future/stale/revoked validation, event-bearing success paths, beneficiary version history, and legacy collector isolation.
31. ✅ **tests/lending/lending-manager.test.ts**: Publish-time-admin initialization handoff, fail-closed pause/health guards, wrong-source-trait rejection, interest-only `repay` fee base, atomic source-custody settlement, immutable stream binding validation, checked arithmetic rollback, scheduled launch fee replacement, net reserve accounting, principal exclusion, and absence of the legacy revenue-automation receipt.
32. ✅ **tests/lending/lending-orchestrator.test.ts**: Fixed-100 interest-only source custody, scheduled-stream binding rejection, executable unauthorized-callback rejection, runtime exact payer/orchestrator/collector custody deltas, collector/orchestrator evidence correlation, pending-state clearing, net reserves, replay/pause/transfer rollback, zero-fee no-transfer evidence, arithmetic overflow, principal exclusion, and no legacy path. Recipient/asset/amount callback invariants are exercised through the authenticated successful settlement path rather than malformed callback injection.
33. ✅ **tests/operational-treasury-init.test.ts**: Publish-time-owner initialization, first-caller front-run rejection, and STX/SIP-010 withdrawal custody.

## How to Run Tests
```bash
npm install
bash scripts/run-tests.sh tests/[path_to_test]
```

## Standards Compliance
All tests adhere to the Conxian Standards Framework:
- **Structural**: Standardized `initSimnet` pattern.
- **Dynamic Addressing**: No hardcoded `ST1PQ...` principals in test logic.
- **Verification**: Explicit assertion of `Cl.ok` and `Cl.error` responses.

Risk-specific limitations and wiring requirements are documented in
`docs/RISK_MANAGEMENT.md`. The focused risk suite intentionally does not claim
oracle-valued production solvency while `dimensional-core.get-position` is
placeholder-backed.

Last Updated: July 26, 2026
