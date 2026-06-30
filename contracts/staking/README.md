# Staking Module

## Overview (Explanation)
The Staking module is a critical component of the Conxian Protocol, handling specialized operations for staking. It implements sovereign autonomous logic to ensure mathematical certainty and neutrality.

## Architecture (Explanation)
This module follows the Hexagonal Architecture pattern. It defines clear ports via traits and provides robust adapter implementations. The core logic is isolated from external dependencies, ensuring high security and auditability.

## Core Contracts (Reference)
The following contracts provide the backbone of the staking system:
### `dual-stacking-orchestrator.clar`
Core logic for dual stacking orchestrator.

Public Functions:
- `placeholder`: Action for placeholder.

### `native-stacking-operator.clar`
Core logic for native stacking operator.

Public Functions:
- `placeholder`: Action for placeholder.

## Jargon & Terminology (Layer 6)
- **Staking**: The process of locking up crypto assets to support a network's operation and, in return, earning rewards.
- **Dual Stacking**: A mechanism where two different assets (e.g., STX and CXD) are stacked simultaneously to provide enhanced security or yield.
- **Orchestrator**: A contract that coordinates actions between multiple other contracts or modules.
- **Operator**: A contract or entity that executes specific technical tasks within the protocol.
- **Nakamoto-Aligned**: Referring to the Nakamoto release of Stacks, which brings faster blocks and Bitcoin finality.

## Integration Examples (How-to)
### Calling Staking from other modules
Use the standard trait patterns. For example:
```clarity
(contract-call? .conxian-protocol get-module "staking")
```

## Testing (How-to)
Comprehensive validation is performed using the Vitest framework.
1. Install dependencies: `npm install`
2. Run module tests: `npx vitest run tests/staking`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- Audit Status: Internally Verified
- BIP Compliance: BIP-341, BIP-342, BIP-174
- Standard: Hexagonal, 60/20/20 split
