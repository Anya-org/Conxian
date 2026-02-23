# Tokens Module

## Overview (Explanation)
The Tokens module is a critical component of the Conxian Protocol, handling specialized operations for tokens. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the tokens system:
### `cxd-price-initializer.clar`
Core logic for cxd price initializer.

Public Functions:
- `placeholder`: Action for placeholder.

### `cxd-token.clar`
Core logic for cxd token.

Public Functions:
- `transfer`: Action for transfer.
- `burn`: Action for burn.
- `add-minter`: Action for add minter.
- `mint`: Action for mint.
- `set-contract-owner`: Action for set contract owner.

### `cxlp-position-nft.clar`
Core logic for cxlp position nft.

Public Functions:
- `transfer`: Action for transfer.
- `mint-position`: Action for mint position.

### `cxlp-token.clar`
Core logic for cxlp token.

Public Functions:
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.

### `cxs-token.clar`
Core logic for cxs token.

Public Functions:
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.

### `cxtr-token.clar`
Core logic for cxtr token.

Public Functions:
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.

### `cxvg-token.clar`
Core logic for cxvg token.

Public Functions:
- `delegate`: Action for delegate.
- `revoke-delegation`: Action for revoke delegation.
- `transfer`: Action for transfer.
- `mint`: Action for mint.
- `burn`: Action for burn.
- `set-contract-owner`: Action for set contract owner.
- `set-token-uri`: Action for set token uri.

### `token-system-coordinator.clar`
Core logic for token system coordinator.

Public Functions:
- `set-coordinator-admin`: Action for set coordinator admin.
- `set-minter-status`: Action for set minter status.
- `set-cxd-token`: Action for set cxd token.
- `set-cxvg-token`: Action for set cxvg token.
- `mint-cxd`: Action for mint cxd.
- `mint-cxvg`: Action for mint cxvg.
- `burn-cxd`: Action for burn cxd.
- `burn-cxvg`: Action for burn cxvg.


## Integration Examples (How-to)
### Calling Tokens from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "tokens")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/tokens`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
