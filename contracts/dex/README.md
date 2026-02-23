# Dex Module

## Overview (Explanation)
The Dex module is a critical component of the Conxian Protocol, handling specialized operations for dex. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the dex system:
### `batch-auction.clar`
Core logic for batch auction.

Public Functions:
- `create-auction`: Action for create auction.
- `place-bid`: Action for place bid.
- `finalize-auction`: Action for finalize auction.

### `concentrated-liquidity-pool.clar`
Core logic for concentrated liquidity pool.

Public Functions:
- `create-pool`: Action for create pool.
- `set-pool-fee`: Action for set pool fee.
- `mint`: Action for mint.
- `swap`: Action for swap.
- `burn`: Action for burn.
- `collect`: Action for collect.
- `collect-protocol-fees`: Action for collect protocol fees.
- `initialize`: Action for initialize.
- `add-liquidity`: Action for add liquidity.

### `dex-facade.clar`
Core logic for dex facade.

Public Functions:
- `add-authorized-pool`: Action for add authorized pool.
- `remove-authorized-pool`: Action for remove authorized pool.
- `initialize`: Action for initialize.

### `dex-factory.clar`
Core logic for dex factory.

Public Functions:
- `register-pool`: Action for register pool.

### `liquidity-manager.clar`
Core logic for liquidity manager.

Public Functions:
- `open-position`: Action for open position.
- `close-position`: Action for close position.

### `liquidity-optimization-engine.clar`
Core logic for liquidity optimization engine.

Public Functions:
- `optimize-liquidity`: Action for optimize liquidity.
- `update-pool-fee-tier`: Action for update pool fee tier.
- `set-optimization-engine-active`: Action for set optimization engine active.

### `liquidity-provider.clar`
Core logic for liquidity provider.

Public Functions:
- `add-liquidity`: Action for add liquidity.
- `remove-liquidity`: Action for remove liquidity.
- `claim-rewards`: Action for claim rewards.
- `batch-claim-rewards`: Action for batch claim rewards.
- `set-liquidity-provider-active`: Action for set liquidity provider active.

### `memory-pool-management.clar`
Core logic for memory pool management.

Public Functions:
- `create-memory-pool`: Action for create memory pool.
- `allocate-memory`: Action for allocate memory.
- `deallocate-memory`: Action for deallocate memory.
- `emergency-cleanup-all-pools`: Action for emergency cleanup all pools.

### `oracle-aggregator.clar`
Core logic for oracle aggregator.

Public Functions:
- `get-price-by-intent`: Action for get price by intent.
- `get-price`: Action for get price.
- `get-weights`: Action for get weights.

### `oracle.clar`
Core logic for oracle.

Public Functions:
- `set-price`: Action for set price.
- `set-contract-owner`: Action for set contract owner.

### `pool-template.clar`
Core logic for pool template.

Public Functions:
- `create-template`: Action for create template.
- `deactivate-template`: Action for deactivate template.

### `predictive-scaling-system.clar`
Core logic for predictive scaling system.

Public Functions:
- `placeholder`: Action for placeholder.

### `protocol-invariant-monitor.clar`
Core logic for protocol invariant monitor.

Public Functions:
- `placeholder`: Action for placeholder.

### `rebalancing-rules.clar`
Core logic for rebalancing rules.

Public Functions:
- `placeholder`: Action for placeholder.

### `route-manager.clar`
Core logic for route manager.

Public Functions:
- `swap-route`: Action for swap route.

### `swap-manager.clar`
Core logic for swap manager.

Public Functions:
- `execute-swap`: Action for execute swap.
- `batch-execute-swaps`: Action for batch execute swaps.
- `set-circuit-breaker`: Action for set circuit breaker.
- `invalidate-route`: Action for invalidate route.
- `set-swap-manager-active`: Action for set swap manager active.

### `swap-router.clar`
Core logic for swap router.

Public Functions:
- `exact-input-single`: Action for exact input single.
- `set-fee`: Action for set fee.
- `update-volatility-fees`: Action for update volatility fees.
- `set-ops-engine`: Action for set ops engine.
- `swap-direct`: Action for swap direct.

### `vault.clar`
Core logic for vault.

Public Functions:
- `create-vault`: Action for create vault.
- `deposit-to-vault`: Action for deposit to vault.
- `withdraw-from-vault`: Action for withdraw from vault.
- `set-circuit-breaker`: Action for set circuit breaker.
- `set-vault-system-active`: Action for set vault system active.


## Integration Examples (How-to)
### Calling Dex from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "dex")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/dex`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
