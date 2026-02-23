# Treasury Module

## Overview (Explanation)
The Treasury module is a critical component of the Conxian Protocol, handling specialized operations for treasury. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the treasury system:
### `allocation-policy.clar`
Core logic for allocation policy.

### `conxian-vaults.clar`
Core logic for conxian vaults.

Public Functions:
- `deposit`: Action for deposit.
- `withdraw`: Action for withdraw.

### `cxd-treasury.clar`
Core logic for cxd treasury.

Public Functions:
- `rebalance`: Action for rebalance.
- `record-diverted-claim`: Action for record diverted claim.
- `initialize`: Action for initialize.
- `set-authorized-principals`: Action for set authorized principals.
- `set-admin`: Action for set admin.

### `founder-vault.clar`
Core logic for founder vault.

Public Functions:
- `create-allocation`: Action for create allocation.
- `claim`: Action for claim.

### `opex-vault.clar`
Core logic for opex vault.

Public Functions:
- `withdraw-opex`: Action for withdraw opex.

### `revenue-distributor.clar`
Core logic for revenue distributor.

Public Functions:
- `distribute-token`: Action for distribute token.
- `distribute-stx`: Action for distribute stx.
- `set-destinations`: Action for set destinations.


## Integration Examples (How-to)
### Calling Treasury from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "treasury")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/treasury`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
