# Interoperability Module

## Overview (Explanation)
The Interoperability module is a critical component of the Conxian Protocol, handling specialized operations for interoperability. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the interoperability system:
### `wormhole-handlers.clar`
Core logic for wormhole handlers.

### `wormhole-inbox.clar`
Core logic for wormhole inbox.

### `wormhole-outbox.clar`
Core logic for wormhole outbox.

Public Functions:
- `send-message`: Action for send message.


## Integration Examples (How-to)
### Calling Interoperability from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "interoperability")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/interoperability`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
