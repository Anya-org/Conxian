# Bonding Module

## Overview (Explanation)
The Bonding module is a critical component of the Conxian Protocol, handling specialized operations for bonding. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the bonding system:
### `bond-factory.clar`
Core logic for bond factory.

Public Functions:
- `transfer`: Action for transfer.
- `create-bond`: Action for create bond.

### `bond-token.clar`
Core logic for bond token.

Public Functions:
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.
- `set-contract-owner`: Action for set contract owner.

### `cxd-bonding-curve-amm.clar`
Core logic for cxd bonding curve amm.

Public Functions:
- `get-buy-quote`: Action for get buy quote.
- `get-sell-quote`: Action for get sell quote.
- `buy`: Action for buy.
- `sell`: Action for sell.


## Integration Examples (How-to)
### Calling Bonding from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "bonding")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/bonding`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
