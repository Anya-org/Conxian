# DEX Module

## Overview (Explanation)
The DEX module provides high-efficiency trading and liquidity provision for the Conxian ecosystem. In 2026, it evolved into a **Universal Routing Layer** powered by the Apex Router and the Common Settlement Framework (CSF).

## Architecture (Explanation)
The DEX follows a dynamic routing architecture:
- **Universal Router**: `swap-router.clar` handles dynamic dispatch to any CSF-compliant liquidity source.
- **Protocol Registry**: `dex-factory.clar` maintains the list of permitted external protocol integrations.
- **Native Engine**: `concentrated-liquidity-pool.clar` provides high-efficiency native Stacks liquidity.

## Core Contracts (Reference)

### `swap-router.clar`
The Apex Universal Router.

| Function | Signature | Description |
|----------|-----------|-------------|
| `csf-swap` | `(liquidity-source <csf-trait> token-in token-out amount-in min-out)` | Executes a swap through any registered CSF source. |
| `claim-external-yield` | `(liquidity-source <csf-trait> reward-token amount)` | Bridges rewards from third-party protocols to the user. |

### `dex-factory.clar`
CSF Discovery and Registry.

| Function | Signature | Description |
|----------|-----------|-------------|
| `register-csf-protocol` | `(protocol principal name)` | Registers a CSF-compliant external contract for discovery. |
| `get-csf-protocol` | `(protocol principal)` | Returns metadata for a registered external protocol. |

## Integration Examples (How-to)

### Routing through an External Protocol (e.g. Bitflow)
```clarity
(contract-call? .swap-router csf-swap
  .bitflow-csf-adapter
  .stx-token
  .usda-token
  u1000000
  u990000
)
```

## Testing (How-to)
Comprehensive validation is performed via `tests/csf-full-system.test.ts`.

## Status (Reference)
- Implementation: Apex v1.1.0 Ready
- Audit Status: Internally Verified (March 2026)
- Standard: CSF Dynamic Dispatch, 100% Fee Buy-back
