# Agents Module

## Overview (Explanation)
The Agents module is a critical component of the Conxian Protocol, handling specialized operations for agents. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the agents system:
### `agent-risk.clar`
Core logic for agent risk.

Public Functions:
- `set-predictive-params`: Action for set predictive params.
- `update-pid-rates`: Action for update pid rates.
- `check-work-needed`: Action for check work needed.
- `do-work`: Action for do work.
- `get-health-factor`: Action for get health factor.
- `initialize`: Action for initialize.
- `set-ops-engine`: Action for set ops engine.
- `set-mock-gcr`: Action for set mock gcr.
- `set-tvl`: Action for set tvl.

### `agent-treasury.clar`
Core logic for agent treasury.

Public Functions:
- `run-fiscal-strategy`: Action for run fiscal strategy.
- `apply-fiscal-dam`: Action for apply fiscal dam.
- `initialize`: Action for initialize.
- `set-contract-owner`: Action for set contract owner.


## Integration Examples (How-to)
### Calling Agents from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "agents")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/agents`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
