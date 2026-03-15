# Conxian Core Modules

## Overview
The Core modules provide the foundational access control, protocol registry, and economic engines for the Conxian ecosystem.

## Architecture
- **conxian-access.clar**: Role-based access control with passkey support.
- **conxian-protocol.clar**: Central registry for all protocol modules.
- **bme-engine.clar**: Burn-Mint Equilibrium engine for tokenomics.
- **ops-engine.clar**: Coordination layer for protocol heartbeats.

## Core Contracts
- `conxian-access`: Standardized RBAC.
- `conxian-protocol`: Module management.

## Integration Examples (How-to)
### Registering a Module
```clarity
(contract-call? .conxian-protocol register-module "DEX" .swap-router)
```

## Testing (How-to)
Run simulation tests:
```bash
npm test tests/admin.test.ts
```

## Status
- **Version**: 0.7.0 (Sovereign Refactor)
- **Compliance**: Directive 2 fully remediated (March 2026).
