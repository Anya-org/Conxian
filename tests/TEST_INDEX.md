# Test-Contract Index & Repair Plan

## Completed Work Summary (Feb 2026)

### Phase 1: Infrastructure Fixes ✅ COMPLETED

- ✅ Added `wallet_1` to `settings/Devnet.toml`
- ✅ Fixed `Clarinet.toml` dependency ordering (agent-risk, agent-treasury, ops-engine)
- ✅ Fixed agent-risk.clar liquidate function return type to match trait
- ✅ Created mock contracts (`mock-token.clar`, `mock-proposal.clar`) in `contracts/test-helpers/`
- ✅ Added mock contracts to `Clarinet.toml`
- ✅ Regenerated `default.simnet-plan.yaml` for address consistency

### Phase 2: DEX Test Fixes ✅ COMPLETED

- ✅ Migrated `concentrated-liquidity-pool.test.ts` from `Clarinet.new()` to `initSimnet` pattern
- ✅ Fixed mint function argument count (4 args, not 5)
- ✅ Added pool creation step in tests before minting
- ✅ Fixed BigInt overflow issue with sqrt price
- ✅ Fixed swap-router.test.ts pool funding (mint CXS to pool before swap)
- ✅ Implemented `math-lib-concentrated.clar` with `get-sqrt-ratio-at-tick` function
- ✅ Fixed `math-lib-concentrated.test.ts` with proper `initSimnet` setup
- ✅ All DEX tests now passing (5/5 tests)

### Phase 3: Contract Implementation ✅ COMPLETED

- ✅ Implemented `burn` function in `concentrated-liquidity-pool.clar`
- ✅ Implemented `collect` function in `concentrated-liquidity-pool.clar`
- ✅ Fixed `ops-engine.clar` - commented out calls to non-existent functions
- ✅ Added `trigger-emergency-pause` function to `ops-engine.clar`
- ✅ Added `pause` function to `conxian-protocol.clar`
- ✅ Added `is-contract-paused` function to `agent-risk.clar`
- ✅ Contract passes `clarinet check` with only warnings (no errors)

### Phase 4: Test File Fixes ✅ COMPLETED

- ✅ Fixed `executive-agents.test.ts` - removed incorrect `Cl.contractCall` usage
- ✅ Fixed `executive-agents.test.ts` - replaced `toBeOk` with `toEqual(Cl.ok(...))`

## Test Results Summary

| Test File | Status | Notes |
|-----------|--------|-------|
| dex/concentrated-liquidity-pool.test.ts | ✅ PASS | 3/3 tests passing |
| dex/swap-router.test.ts | ✅ PASS | 1/1 test passing |
| math/math-lib-concentrated.test.ts | ✅ PASS | 1/1 test passing |
| governance/executive-agents.test.ts | ⚠️ PARTIAL | Tests fail due to missing contract functions (authorization, distribute) |
| Full test suite | ⚠️ PARTIAL | 55+ tests passing, many legacy tests need migration |

## Files Modified in This Session

### Contracts

- `contracts/test-helpers/mock-token.clar` (NEW)
- `contracts/test-helpers/mock-proposal.clar` (NEW)
- `contracts/math/concentrated-math.clar` (implemented math functions)
- `contracts/core/ops-engine.clar` (fixed broken calls, added trigger-emergency-pause)
- `contracts/core/conxian-protocol.clar` (added pause function)
- `contracts/agents/agent-risk.clar` (added is-contract-paused)

### Tests

- `tests/dex/concentrated-liquidity-pool.test.ts` (migrated to initSimnet)
- `tests/dex/swap-router.test.ts` (verified working)
- `tests/math/math-lib-concentrated.test.ts` (added initSimnet setup)
- `tests/governance/executive-agents.test.ts` (fixed syntax errors)

### Configuration

- `Clarinet.toml` (added mock contracts, renamed math-lib-concentrated)
- `deployments/default.simnet-plan.yaml` (regenerated)

Last Updated: Feb 4, 2026

### High Priority - Legacy Test Migration ✅ COMPLETED

The following tests have been migrated from deprecated `Clarinet.new()` pattern to `initSimnet`:

- ✅ `tests/governance/reputation-engine.test.ts` - Migrated from .skip, fixed assertion methods, **MOVED to governance/**
- ✅ `tests/governance/proposal-engine-core.test.ts` - Migrated from .skip, fixed assertion methods, **MOVED to governance/**
- ✅ `tests/governance/proposal-registry.test.ts` - Migrated from .skip, fixed assertion methods, **MOVED to governance/**
- ✅ `tests/governance/enhanced-governance-nft.test.ts` - Migrated from .skip, fixed assertion methods, **MOVED to governance/**
- ✅ `tests/governance/proposal-engine-admin.test.ts` - Migrated from .skip, fixed file structure, **MOVED to governance/**
- ✅ `tests/governance/conxian-operations-engine.test.ts` - Migrated from .skip, fixed assertion methods, **MOVED to governance/**
- ✅ `tests/governance/proposal-engine.test.ts` - Migrated from security.skip, **MOVED to governance/**
- ✅ `tests/p0-circuit-breaker.test.ts` - Migrated from security.skip, **MOVED to tests root**
- ✅ `tests/temp-check.test.ts` - Migrated from integration.skip, **MOVED to tests root**
- ⏳ `tests/office-worker.test.ts` - Still needs migration

### Contract Functions Added ✅ COMPLETED

Added missing functions to `proposal-engine.clar`:

- ✅ `set-voting-period`
- ✅ `set-quorum-percentage`
- ✅ `set-proposal-executor`
- ✅ `transfer-ownership`
- ✅ `set-protocol-coordinator`
- ✅ `set-proposal-registry`
- ✅ `propose` (legacy compatibility)

### Medium Priority - Stub Contract Implementation

Contracts with TODO/stub comments requiring full production implementation:

1. **swap-manager.clar** - 3 TODOs
2. **swap-router.clar** - 3 TODOs (core swap logic can be enhanced)
3. **dimensional-oracle.clar** - 3 TODOs
4. **monitoring/finance-metrics.clar** - 1 TODO (get-tvl implementation)

Last Updated: Feb 3, 2026

## Test Pattern Analysis

### Pattern 1: Legacy Clarinet.new() (DEPRECATED - NEEDS MIGRATION)

**Files using this pattern:**

- tests/office-worker.test.ts

**Pattern characteristics:**

```typescript
import { Clarinet, Tx, Chain, Account } from '@stacks/clarinet-sdk';
let clarinet: Clarinet;
let chain: Chain;
beforeEach(async () => {
  clarinet = await Clarinet.new();
  chain = clarinet.getChain();
  deployer = clarinet.getDeployerAccount();
  [wallet1] = clarinet.getAccounts(['wallet-1']);
});
```

### Pattern 2: Modern initSimnet() (CORRECT - USE THIS)

**Files using this pattern:**

- tests/dex/swap-router.test.ts
- tests/tokens-utility.test.ts
- tests/governance/executive-agents.test.ts
- tests/system/full-protocol-journey.test.ts
- tests/core-contracts.test.ts
- tests/dex/concentrated-liquidity.test.ts
- tests/lending/*.test.ts
- tests/agents/*.test.ts
- tests/governance/reputation-engine.test.ts 
- tests/governance/proposal-engine-core.test.ts 
- tests/governance/proposal-registry.test.ts 
- tests/governance/enhanced-governance-nft.test.ts 
- tests/governance/proposal-engine-admin.test.ts 
- tests/governance/conxian-operations-engine.test.ts 
- tests/governance/proposal-engine.test.ts 
- tests/p0-circuit-breaker.test.ts 
- tests/temp-check.test.ts 

**Pattern characteristics:**

```typescript
import { initSimnet, type Simnet } from '@stacks/clarinet-sdk';
import { Cl } from '@stacks/transactions';
let simnet: Simnet;
beforeAll(async () => {
  simnet = await initSimnet('Clarinet.toml');
});
beforeEach(() => {
  const accounts = simnet.getAccounts();
  deployer = accounts.get('deployer')!;
  wallet1 = accounts.get('wallet_1')!;
});
```

## Root Cause Issues

### Issue 1: Account Naming Inconsistency

- **Problem**: Some tests use `wallet-1` (hyphen), others use `wallet_1` (underscore)
- **Solution**: Standardize on `wallet_1` (underscore) in all tests and Devnet.toml

### Issue 2: Missing wallet_1 in Devnet.toml

- **Problem**: Only `deployer` account defined, tests need `wallet_1`
- **Status**: Fixed in previous session

### Issue 3: Test Assertion Methods

- **Problem**: Some tests use `.toBeOk()` which doesn't exist in current vitest setup
- **Solution**: Use `toEqual(Cl.ok(Cl.bool(true)))` or `toEqual(Cl.ok(Cl.uint(value)))`

### Issue 4: Import Path Inconsistencies

- **Problem**: Some tests import from `@stacks/clarinet-sdk` directly, others use relative paths
- **Solution**: Standardize imports

## Contract-Test Mapping

| Contract | Test File(s) | Pattern | Status |
|----------|--------------|---------|--------|
| cxd-token | tokens-utility.test.ts, dex/swap-router.test.ts | initSimnet | Working |
| cxs-token | tokens-utility.test.ts, dex/swap-router.test.ts | initSimnet | Working |
| concentrated-liquidity-pool | dex/concentrated-liquidity-pool.test.ts, dex/swap-router.test.ts | Mixed | Needs migration |
| swap-router | dex/swap-router.test.ts | initSimnet | Funded pool fix needed |
| agent-risk | agents/aye-pid.test.ts | initSimnet | Unknown |
| reputation-engine | governance.skip/reputation-engine.test.ts | Clarinet.new | Needs migration |
| proposal-registry | governance.skip/proposal-registry.test.ts | Clarinet.new | Needs migration |

## Systematic Repair Order (Leaf to Root)

### Phase 1: Fix Infrastructure (Root Issues)

1. ✅ Add wallet_1 to Devnet.toml (DONE)
2. Create shared test utilities for common patterns
3. Fix Clarinet.toml dependency order

### Phase 2: Fix Leaf Unit Tests

1. Migrate concentrated-liquidity-pool.test.ts to initSimnet
2. Fix swap-router.test.ts pool funding issue
3. Verify tokens-utility.test.ts passes

### Phase 3: Fix Governance Tests

1. Migrate all governance.skip tests to initSimnet
2. Update assertion methods
3. Remove .skip suffix when tests pass

### Phase 4: Integration Tests

1. Fix full-protocol-journey.test.ts
2. Review and fix remaining integration tests

### Phase 5: Validation

1. Run full test suite
2. Document any remaining gaps

## Current Blockers

1. **concentrated-liquidity-pool.test.ts** - Uses deprecated Clarinet.new(), needs migration
2. **reputation-engine.test.ts** - Uses Clarinet.fromStream(), needs migration
3. **swap-router.test.ts** - Pool needs token funding before swap can work

## Next Actions

1. Create shared test setup utility
2. Migrate concentrated-liquidity-pool.test.ts
3. Fix swap-router.test.ts funding issue
4. Batch migrate governance tests
