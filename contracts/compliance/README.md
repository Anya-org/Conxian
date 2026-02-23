# Compliance Module

## Overview (Explanation)
The Compliance module is a critical component of the Conxian Protocol, handling specialized operations for compliance. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the compliance system:
### `compliance-hooks.clar`
Core logic for compliance hooks.

Public Functions:
- `set-contract-owner`: Action for set contract owner.
- `set-compliance-manager`: Action for set compliance manager.
- `add-kyc-provider`: Action for add kyc provider.
- `remove-kyc-provider`: Action for remove kyc provider.
- `verify-kyc`: Action for verify kyc.
- `log-audit-event`: Action for log audit event.

### `compliance-manager.clar`
Core logic for compliance manager.

Public Functions:
- `register-provider`: Action for register provider.
- `remove-provider`: Action for remove provider.
- `set-sanctions-provider`: Action for set sanctions provider.
- `check-user-compliance`: Action for check user compliance.
- `batch-check-compliance`: Action for batch check compliance.
- `check-kyc-compliance`: Action for check kyc compliance.
- `set-owner`: Action for set owner.

### `compliance-trait.clar`
Core logic for compliance trait.

### `regulatory-adapter.clar`
Core logic for regulatory adapter.

Public Functions:
- `transfer-ownership`: Action for transfer ownership.

### `travel-rule-service.clar`
Core logic for travel rule service.

Public Functions:
- `register-vasp`: Action for register vasp.
- `log-travel-rule-data`: Action for log travel rule data.


## Integration Examples (How-to)
### Calling Compliance from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "compliance")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/compliance`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
