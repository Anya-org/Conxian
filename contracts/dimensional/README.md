# Dimensional Module

## Overview (Explanation)
The Dimensional module is a critical component of the Conxian Protocol, handling specialized operations for dimensional. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the dimensional system:
### `dimensional-core.clar`
Core logic for dimensional core.

Public Functions:
- `get-health-factor`: Action for get health factor.
- `open-position`: Action for open position.
- `close-position`: Action for close position.
- `liquidate-position`: Action for liquidate position.
- `set-risk-manager`: Action for set risk manager.

### `position-nft.clar`
Core logic for position nft.

Public Functions:
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.
- `set-minter`: Action for set minter.


## Integration Examples (How-to)
### Calling Dimensional from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "dimensional")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/dimensional`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
