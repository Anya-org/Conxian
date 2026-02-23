# Sbtc Module

## Overview (Explanation)
The Sbtc module is a critical component of the Conxian Protocol, handling specialized operations for sbtc. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the sbtc system:
### `dlc-manager.clar`
Core logic for dlc manager.

Public Functions:
- `create-dlc`: Action for create dlc.


## Integration Examples (How-to)
### Calling Sbtc from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "sbtc")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/sbtc`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
