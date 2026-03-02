# Errors Module

## Overview (Explanation)
The Errors module provides a centralized reference for protocol-wide error codes and error handling standards. It ensures that all Conxian Protocol modules use consistent error ranges to simplify debugging and integration.

## Architecture (Explanation)
Error codes are categorized by functional domain:
- **Core Protocol**: 1000 - 1999
- **DEX & Math**: 2000 - 2999
- **Governance**: 3000 - 3999
- **Agents & Monitoring**: 4000 - 4999
- **Performance & Yield**: 5000 - 5999
- **Security & Compliance**: 8000 - 8999

## Core Error Codes (Reference)

### Global Standards
| Code | Constant | Description |
|------|----------|-------------|
| `u1000` | `ERR_UNAUTHORIZED` | Caller lacks required permissions. |
| `u1001` | `ERR_PAUSED` | Protocol or module is currently paused. |
| `u9999` | `ERR_NOT_IMPLEMENTED` | Functionality is currently a stub. |

### Core & Dimensional (`1000-1999`)
| Code | Constant | Description |
|------|----------|-------------|
| `u1002` | `ERR_INSUFFICIENT_LIQUIDITY` | Requested amount exceeds available reserves. |
| `u1003` | `ERR_INVALID_AMOUNT` | Zero or negative amount provided. |
| `u1004` | `ERR_INSUFFICIENT_COLLATERAL` | Position health is below liquidation threshold. |

### DEX & Pathing (`2000-2999`)
| Code | Constant | Description |
|------|----------|-------------|
| `u2001` | `ERR_INVALID_TICK` | Tick price is out of allowed range. |
| `u2005` | `ERR_INVALID_PATH` | Swap path is disconnected or invalid. |
| `u3000` | `ERR_SLIPPAGE` | Swap output is below minimum threshold. |

### Governance (`3000-3999`)
| Code | Constant | Description |
|------|----------|-------------|
| `u3001` | `ERR_PROPOSAL_NOT_FOUND` | Specified proposal ID does not exist. |
| `u3002` | `ERR_ALREADY_VOTED` | User has already cast a vote for this proposal. |
| `u3005` | `ERR_VOTING_ENDED` | Attempted to vote after the deadline. |

## Core Contracts (Reference)
Individual contracts define their own domain-specific constants but must fall within the specified ranges to prevent collisions during aggregation.

## Integration Examples (How-to)

### Standard Error Handling in Clarity
Always use `unwrap!` or `asserts!` with standardized error codes:
```clarity
(define-public (safe-execute)
  (begin
    (asserts! (is-eq tx-sender .admin) (err u1000))
    (ok true)
  )
)
```

## Testing (How-to)
Error code consistency is verified across the entire suite of integration tests. Functional tests for each module ensure that the correct error code is returned for specific failure conditions (e.g., `tests/core/conxian-protocol.test.ts` for `ERR_UNAUTHORIZED`).

## Status (Reference)
- Implementation: Finalized (v1.2.0)
- Audit Status: Internally Verified
- Alignment: 100% Repository-wide Error Consistency
