# Traits Module

## Overview (Explanation)
The Traits module defines the protocol's interface standards, ensuring modularity and interoperability across all Conxian modules. By using standardized traits, the protocol can swap implementations of core engines without breaking dependent logic. In 2026, the **Conxian CSF** and **Intent Layer** established new standards for inter-protocol liquidity and cross-chain execution.

## Architecture (Explanation)
This module serves as the "Interface Layer" of the protocol's Hexagonal Architecture.
- **CSF Traits**: Defined in `conxian-csf-trait.clar`. Establishes the universal standard for liquidity and yield routing.
- **Intent Traits**: Defined in `conxian-intent-trait.clar`. Provides the standard for Bitcoin-anchored intents and solver execution.
- **Core Traits**: Defined in `core-traits.clar` (RBAC, Pausable).
- **DeFi Traits**: Defined in `defi-traits.clar` (Oracles, Swap, LPT).
- **Standards**: SIP compliance is enforced via `sip-standards.clar` (SIP-009, SIP-010).

## Core Traits (Reference)

### `conxian-csf-trait.clar` (CSF v1.1.0)
| Function | Signature | Description |
|----------|-----------|-------------|
| `execute-csf-swap` | `(<sip-010-trait> <sip-010-trait> uint principal)` | Executes a standardized swap for the Universal Router. |
| `request-flash-liquidity` | `(<sip-010-trait> uint (buff 32))` | Requests low-latency flash liquidity. |
| `settle-arbitrage` | `(<sip-010-trait> <sip-010-trait> uint (list 10 principal))` | Atomic settlement of cross-protocol arbitrage. |
| `claim-conxian-yield` | `(<sip-010-trait> uint principal)` | Forwards rewards to external vault owners without breaking custody. |
| `get-csf-health` | `()` | Returns real-time health telemetry for risk monitoring. |

### `conxian-intent-trait.clar`
| Trait | Description |
|-------|-------------|
| `conxian-intent-solver-trait` | Standard for intent verification and execution. |
| `conxian-liquidity-v1-trait` | Standard for providing liquidity and settling swaps via intents. |

### `core-traits.clar`
| Trait | Description |
|-------|-------------|
| `pausable-trait` | Interface for contracts with pause/unpause functionality. |
| `ownable-trait` | Interface for contracts with administrative ownership. |

### `defi-traits.clar`
| Trait | Description |
|-------|-------------|
| `oracle-trait` | Interface for price feed providers. |
| `ft-trait` | SIP-010 Fungible Token standard. |
| `nft-trait` | SIP-009 Non-Fungible Token standard. |

### `integration-fee-trait.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `record-usage` | `(principal (buff 32) uint)` | Records reporter-authorized usage and returns the accrued fee. |
| `settle-period` | `(principal uint uint (buff 32))` | Settles the exact outstanding amount for one integration and period. |
| `settle-fees` | `(principal uint uint (buff 32))` | Alias with the same payer authorization and accounting as `settle-period`. |
| `get-usage-record` | `((buff 32))` | Reads a replay-protected usage/audit record. |
| `get-period-ledger` | `(principal uint)` | Reads immutable billing snapshots plus usage, accrual, and settlement totals for a period. |
| `get-current-period` | `()` | Returns the burn-block-based billing period. |

This trait is intentionally collector-focused. Integration registration,
reporter configuration, payer authorization, and key rotation remain in the
separate `integration-registry.clar` lifecycle API.

## Integration Examples (How-to)

### Implementing CSF Liquidity (External Protocol)
To allow Conxian's router to trade through your protocol:
```clarity
(impl-trait .conxian-csf-trait.trait-csf-liquidity-v1)

(define-public (execute-csf-swap (token-in <sip-010>) (token-out <sip-010>) (amount uint) (recipient principal))
  ;; Your internal swap logic here
  (ok { amount-out: amount, fee-collected: u30 })
)
```

### Executing an Intent (Solver)
```clarity
(contract-call? .intent-solver-gateway execute-intent intent-id payload solver)
```

## Testing (How-to)
Trait compliance is verified via `tests/csf-full-system.test.ts` and `tests/cxip-012.test.ts`.

## Status (Reference)
- Implementation: Active (Apex v1.1.0)
- Audit Status: Internally Verified (March 2026)
- Alignment: 100% Ecosystem Standard Compatibility
