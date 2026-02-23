# Oracle Module

## Overview (Explanation)
The Oracle module is a critical component of the Conxian Protocol, handling specialized operations for oracle. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the oracle system:
### `dimensional-oracle.clar`
Core logic for dimensional oracle.

Public Functions:
- `get-price`: Action for get price.
- `fetch-price`: Action for fetch price.

### `external-oracle-adapter.clar`
Core logic for external oracle adapter.

### `federated-oracle-adapter.clar`
Core logic for federated oracle adapter.

Public Functions:
- `submit-price`: Action for submit price.
- `add-oracle-source`: Action for add oracle source.
- `remove-oracle-source`: Action for remove oracle source.

### `oracle-adapter-stub.clar`
Core logic for oracle adapter stub.

### `oracle-aggregator.clar`
Core logic for oracle aggregator.

Public Functions:
- `set-admin`: Action for set admin.
- `set-circuit-breaker`: Action for set circuit breaker.
- `set-params`: Action for set params.
- `set-stale-threshold`: Action for set stale threshold.
- `reset-volatility`: Action for reset volatility.
- `set-source`: Action for set source.

### `points-oracle.clar`
Core logic for points oracle.

Public Functions:
- `award-points`: Action for award points.
- `burn-points`: Action for burn points.
- `transfer-points`: Action for transfer points.
- `claim-reward`: Action for claim reward.
- `apply-points-decay`: Action for apply points decay.
- `create-reward`: Action for create reward.
- `set-decay-enabled`: Action for set decay enabled.
- `emergency-reset-user-points`: Action for emergency reset user points.
- `deactivate-reward`: Action for deactivate reward.


## Integration Examples (How-to)
### Calling Oracle from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "oracle")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/oracle`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
