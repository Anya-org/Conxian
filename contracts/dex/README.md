# Conxian CSF (Common Settlement Framework)

## Overview
Universal liquidity routing and CSF-compliant pool implementations.

## Architecture
- **swap-router.clar**: Apex Dynamic Dispatch Router.
- **concentrated-liquidity-pool.clar**: Reference CSF v1.1.0 implementation.

## Integration Examples (How-to)
### Executing a Swap
```clarity
(contract-call? .swap-router csf-swap .concentrated-liquidity-pool .cxd-token .mock-token u1000 u990)
```

## Status
- **Compliance**: Clarity 4 types-only trait signatures verified.
