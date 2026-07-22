# Conxian Protocol: Testing Index (Feb 2026)

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
5. ✅ **tests/agents/aye-pid.test.ts**: PID stability controller for borrow rates.
6. ✅ **tests/core-contracts.test.ts**: Basic contract deployment and status checks.

### Intermediate Leaf Tests (DEX & Governance)
7. ✅ **tests/dex/concentrated-liquidity-pool.test.ts**: Pool creation and state.
8. ✅ **tests/dex/concentrated-liquidity.test.ts**: Math library for CL.
9. ✅ **tests/dex/swap-router.test.ts**: Swap routing and fee logic.
10. ✅ **tests/governance/reputation-engine.test.ts**: Weighted voting power.
11. ✅ **tests/governance/proposal-engine.test.ts**: Governance signal processing.
12. ✅ **tests/governance/proposal-engine-core.test.ts**: Seat-based voting and submission.
13. ✅ **tests/governance/proposal-engine-admin.test.ts**: Admin overrides.
14. ✅ **tests/governance/enhanced-governance-nft.test.ts**: Seat minting and power tracking.
15. ✅ **tests/governance/proposal-registry.test.ts**: Persistent proposal storage.
16. ✅ **tests/governance/conxian-operations-engine.test.ts**: Root heartbeat coordination.
17. ✅ **tests/governance/executive-agents.test.ts**: Autonomous Staff (CRO/Sovereign-Financial-Office) logic.
18. ✅ **tests/governance/sab-election.test.ts**: Escrowed SAB election cycles, quorum/tie finalization, and stake claims.
19. ✅ **tests/governance/upgrade-controller.test.ts**: Release authorization, signer thresholds, timelock, rollout, and rollback.
20. ✅ **tests/governance/gauge-manager.test.ts**: Canonical escrowed gauge voting, caps, epoch finalization, and withdrawals.

### Vault & Custody Tests
21. ✅ **tests/vaults/sbtc-vault.test.ts**: Canonical-token-bound sBTC custody, cap/pause controls, share accounting, withdrawals, and disabled strategy allocation.

### System Root Tests (Integration)
22. ✅ **tests/system/full-protocol-journey.test.ts**: Coordination between Heartbeat, DEX, and Agents.
23. ✅ **tests/cybernetic-revenue.test.ts**: Dynamic "Fiscal Dam" allocation (CXIP-013).
24. ✅ **tests/cxip-012.test.ts**: Volatility-based DEX fee adjustments.
25. ✅ **tests/nakamoto_verification.test.ts**: Tenure info and block utility checks.

## How to Run Tests
```bash
npm install
npx vitest run tests/[path_to_test]
```

## Standards Compliance
All tests adhere to the Conxian Standards Framework:
- **Structural**: Standardized `initSimnet` pattern.
- **Dynamic Addressing**: No hardcoded `ST1PQ...` principals in test logic.
- **Verification**: Explicit assertion of `Cl.ok` and `Cl.error` responses.

Last Updated: Jul 22, 2026
