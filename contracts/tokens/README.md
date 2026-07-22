# Tokens Module

## Overview (Explanation)
The Tokens module manages all native protocol assets including CXD (Sovereign Debt), CXVG (Governance), and CXLP (Liquidity). It enforces strict regulatory compliance via the Sovereign Guard and ensures compatibility with the SIP-010 and SIP-009 standards.

## Architecture (Explanation)
- **Core Assets**: `cxd-token.clar` and `cxvg-token.clar` implement the protocol's primary financial and governance instruments.
- `cxlp-token.clar`: The Liquible Provider token issued for DEX liquidity.
- `cxtr-token.clar`: The Treasury Reward token used for meritocratic distributions.
- **Coordination**: `token-system-coordinator.clar` manages system-wide minting and burning policies.
- **Compliance**: Integrates with the `regulatory-adapter.clar` to enforce jurisdictional sharding and travel rule requirements.

## Core Contracts (Reference)

### `cxd-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(amount uint) (recipient principal)` | Mints new CXD. Authorized minters/admin only. |
| `burn` | `(amount uint) (sender principal)` | Burns CXD. Authorized burners/admin only. |
| `add-minter` | `(minter principal)` | Adds an authorized minter (Admin only). |
| `add-burner` | `(burner principal)` | Adds an authorized burner (Admin only). |
| `transfer` | `(amount uint) (from principal) (to principal) (memo (optional (buff 34)))` | Standard SIP-010 transfer. |
| `initialize` | `(new-admin principal)` | Initializes the contract with a new administrator. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `cxvg-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(amount uint) (recipient principal)` | Mints CXVG tokens. Admin only. |
| `burn` | `(amount uint) (owner principal)` | Burns CXVG tokens. Owner only. |
| `initialize` | `(new-admin principal)` | Sets the initial administrator (Admin only). |
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | Standard SIP-010 transfer. |

### `cxlp-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint` | `(amount uint) (recipient principal)` | Mints CXLP for the admin or an authorized immediate caller; zero amounts are rejected. |
| `burn` | `(amount uint) (owner principal)` | Burns CXLP for an authorized immediate caller; non-admin callers must initiate a burn for `owner`. The admin retains an explicit emergency path that may burn any owner's balance. |
| `add-minter` / `remove-minter` | `(principal)` | Adds or removes a minter (current admin's immediate caller only). |
| `add-burner` / `remove-burner` | `(principal)` | Adds or removes a burner (current admin's immediate caller only). |
| `is-minter` / `is-burner` | `(principal)` | Reads the independent minter and burner authorization maps. |
| `is-admin` | `(caller principal)` | Reports whether a principal is the current administrator. |
| `get-admin` | `()` | Returns the current administrator. |
| `initialize` | `(new-admin principal)` | Rotates the administrator; authorization uses the immediate `contract-caller`, so direct standard-principal admin calls remain supported. |
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | SIP-010 compliant transfer. |
| `get-balance` | `(who principal)` | Returns the token balance for a user. |
| `get-name` | `()` | Returns the SIP-010 token name. |
| `get-symbol` | `()` | Returns the SIP-010 token symbol. |
| `get-decimals` | `()` | Returns the SIP-010 decimal precision (`u8`). |
| `get-total-supply` | `()` | Returns the current CXLP total supply. |
| `get-token-uri` | `()` | Returns the optional SIP-010 metadata URI. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

Privileged failures use `u1000` (unauthorized), `u1001` (invalid amount), `u1002` (owner mismatch), and `u1003` (insufficient balance). The focused suite rotates the admin through a standard principal because the existing coordinator exposes token mint/burn wrappers but no admin-role wrapper; the same immediate-`contract-caller` predicate is exercised by the nested coordinator calls, so contract-principal rotation does not require a production-only test helper.

Pool creation records concentrated-pool metadata only; it does not mint CXLP. This is the #536 integration boundary: custody, position accounting, and settlement remain separate work.

### `cxtr-token.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `transfer` | `(amount uint) (sender principal) (recipient principal) (memo (optional (buff 34)))` | SIP-010 compliant transfer. |
| `get-balance` | `(who principal)` | Returns the token balance for a user. |
| `get-protocol-status` | `()` | Returns compliance and version status. |

### `token-system-coordinator.clar`
| Function | Signature | Description |
|----------|-----------|-------------|
| `mint-cxd` | `(token <ft-mintable-trait>) (amount uint) (recipient principal)` | Mints CXD after regulatory check. |
| `mint-cxvg` | `(token <ft-mintable-trait>) (amount uint) (recipient principal)` | Mints CXVG after regulatory check. |
| `burn-cxd` | `(token <ft-mintable-trait>) (amount uint) (owner principal)` | Burns CXD from owner. |

## Integration Examples (How-to)

### Minting CXD via Coordinator
To mint Conxian Dollars while ensuring regulatory compliance:
```clarity
(contract-call? .token-system-coordinator mint-cxd .cxd-token u100000000 tx-sender)
```

### Transferring CXVG
Standard SIP-010 transfer:
```clarity
(contract-call? .cxvg-token transfer u50000000 tx-sender 'SP3FG98A4799M07E1S7K6D61H42S79W5W8XN1X6R none)
```

## Jargon (Accessibility)
- **SIP-010**: The standard for fungible tokens on the Stacks blockchain.
- **Sovereign Debt (CXD)**: The primary currency of the Conxian ecosystem, backed by protocol collateral.
- **Vanguard Token (CXVG)**: A governance token that grants voting rights within the Conxian Vanguard DAO.
- **Liquidity Provider Token (CXLP)**: A token representing a user's share in a concentrated liquidity pool.
- **Treasury Reward Token (CXTR)**: A token distributed as an incentive for protocol-aligned activities.
- **Jurisdictional Sharding**: A technique used to partition token functionality or eligibility based on the user's legal jurisdiction.
- **Sovereign Guard**: The protocol's automated compliance and risk management layer.
- **Meritocratic Emission**: A token distribution model where rewards are earned through verified protocol contributions.

## Testing (How-to)
`bash scripts/run-tests.sh tests/tokens/cxlp-token.test.ts tests/tokens-utility.test.ts`

## Status (Reference)
- Implementation: Production-Ready (v1.2.0)
- SIP Compliance: SIP-010, SIP-009
