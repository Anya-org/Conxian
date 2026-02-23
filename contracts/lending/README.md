# Lending Module

## Overview (Explanation)
The Lending module is a critical component of the Conxian Protocol, handling specialized operations for lending. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the lending system:
### `interest-rate-model.clar`
Core logic for interest rate model.

### `lending-manager.clar`
Core logic for lending manager.

Public Functions:
- `deposit`: Action for deposit.
- `borrow`: Action for borrow.
- `repay`: Action for repay.
- `seize-collateral`: Action for seize collateral.
- `collect-reserves`: Action for collect reserves.
- `set-circuit-breaker`: Action for set circuit breaker.
- `withdraw`: Action for withdraw.


## Integration Examples (How-to)
### Calling Lending from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "lending")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/lending`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
