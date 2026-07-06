# Treasury Module

## Overview (Explanation)
The Treasury module manages the protocol's capital allocation and revenue distribution. It implements the "Fiscal Dam" (CXIP-013) and enforces mandatory protocol fees via the Revenue Automation engine.

## Architecture (Explanation)
- **Automation**: `revenue-automation.clar` enforces a non-negotiable 100 bps protocol fee.
- **Registry**: `cxd-treasury.clar` maintains the global allocation policy.
- **Distribution**: `revenue-distributor.clar` executes token buy-backs and burns.

## Core Contracts (Reference)

### `revenue-automation.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `collect-revenue` | `(token <sip-010-ft-trait>) (amount uint) (payer principal)` | Calculates and transfers 1% fee. |
| `initialize` | `(admin principal)` | Sets the initial administrator (Admin only). |
| `set-admin` | `(new-admin principal)` | Updates the admin principal (Admin only). |

### `cxd-treasury.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `rebalance` | `(treasury uint) (bounty uint) (lp uint) (grant uint) (buyback uint) (insurance uint)` | Updates 6-way split (Admin only). |
| `set-authorized-principals` | `(agent principal) (distributor principal)` | Sets authorized actors (Admin only). |
| `initialize` | `(new-admin principal)` | Initializes the treasury (Admin only). |
| `get-allocation-percentages` | `()` | Returns the current fiscal split. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `conxian-vaults.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `deposit` | `(token <sip-010-ft-trait>) (amount uint)` | Deposits FT into the vault. |
| `withdraw` | `(token <sip-010-ft-trait>) (amount uint)` | Withdraws FT from the vault. |
| `get-balance` | `(user principal) (token principal)` | Returns user balance for token. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

## Integration Examples (How-to)

### Rebalancing the Fiscal Dam
Authorized agents can rebalance the treasury split:
```clarity
(contract-call? .cxd-treasury rebalance u4000 u3000 u2000 u500 u500 u0)
```

### Depositing Assets to Vault
Users can secure their assets in Conxian Vaults:
```clarity
(contract-call? .conxian-vaults deposit .cxd-token u100000000)
```

## Jargon (Accessibility)
- **Fiscal Dam**: A mechanism that captures protocol revenue and redirects it into various strategic buckets (Treasury, Buy-backs, etc.).
- **POL (Protocol-Owned Liquidity)**: Liquidity held and controlled by the protocol treasury rather than individual users.
- **Fail-closed**: A security design pattern where a system defaults to its most secure state (e.g., stopping transfers) if an error or anomaly is detected.
- **BME (Burn-and-Mint Equilibrium)**: An economic model where tokens are burned to create deflationary pressure while new tokens are minted based on protocol activity.
- **100 bps**: One hundred basis points, equivalent to 1%.

## Testing (How-to)
`npx vitest run tests/treasury`

## Status (Reference)
- Implementation: Production-Ready (v1.2.1)
- Standard: Hexagonal, 6-Way Fiscal Dam Split
