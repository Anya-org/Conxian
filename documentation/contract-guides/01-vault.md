# Contract Guide: `vault.clar`

> **Note:** This guide has been updated to reflect the current state of the `contracts/vault.clar` contract as of September 2025.

## 1. Introduction

The `vault.clar` contract is the heart of the Conxian ecosystem. It is a sophisticated smart contract that serves as the primary repository for user-deposited assets. Its main purpose is to manage these assets, apply automated yield-generating strategies, and provide a secure, efficient, and feature-rich experience for users and other protocol contracts.

This vault is a **multi-asset** contract, meaning it can hold and manage multiple different SIP-010 tokens simultaneously.

The vault uses a share-based accounting system, where depositors receive "shares" that represent their proportional ownership of a specific asset's pool within the vault. As the vault generates yield for a specific asset, the value of each share for that asset increases.

## 2. Key Concepts

### Share-Based Accounting (Per Asset)

-   **Shares:** When you deposit an asset (e.g., `STX`), you receive shares for that specific asset's pool. These shares represent your claim on that pool's assets.
-   **Share Price:** The value of each share is calculated on a per-asset basis: `(Total Asset Balance in Vault) / (Total Shares Issued for that Asset)`. As the vault earns yield, the value of each share goes up.
-   **Deposits & Withdrawals:** When you deposit, you mint new shares based on the current share price for that asset. When you withdraw, you burn your shares to redeem the underlying asset.

### Fees and Reserves

The vault charges fees on various operations to sustain the protocol. Fees are collected on a per-asset basis.

-   **Deposit Fee:** A small percentage taken from the deposited amount. Default: `u50` (0.5%).
-   **Withdrawal Fee:** A small percentage taken from the withdrawn amount. Default: `u100` (1.0%).
-   **Revenue Share:** A portion of fees are shared with the protocol. Default: `u2000` (20%).

### Risk Management

The vault has several built-in risk management features:
-   **Per-Asset Caps:** A maximum limit on the total assets that can be deposited for each supported token.
-   **Paused Mode:** The admin can pause all major functions (deposits, withdrawals) in case of an emergency.

## 3. State Variables

This table describes the key data variables that define the vault's state.

| Variable Name | Type | Description |
| --- | --- | --- |
| `admin` | `principal` | The address of the admin contract. |
| `paused` | `bool` | If `true`, deposits and withdrawals are disabled. |
| `deposit-fee-bps` | `uint` | The deposit fee in basis points. Default: `u50` (0.5%). |
| `withdrawal-fee-bps` | `uint` | The withdrawal fee in basis points. Default: `u100` (1.0%). |
| `revenue-share-bps` | `uint` | The percentage of fees sent to the protocol. Default: `u2000` (20%). |
| `monitor-enabled` | `bool` | A flag to enable or disable the protocol monitor. |
| `emission-enabled` | `bool` | A flag to enable or disable token emissions. |
| `vault-balances` | `(map principal uint)` | Maps an asset's contract principal to its total balance in the vault. |
| `vault-shares` | `(map principal uint)` | Maps an asset's contract principal to the total shares issued for it. |
| `vault-caps` | `(map principal uint)` | Maps an asset's contract principal to its deposit cap. |
| `user-shares` | `(map (tuple (user principal) (asset principal)) uint)` | Maps a user and an asset to the user's share balance for that asset. |
| `supported-assets` | `(map principal bool)` | A map to check if an asset is supported by the vault. |
| `asset-strategies` | `(map principal principal)` | Maps an asset to its designated yield strategy contract. |
| `collected-fees` | `(map principal uint)` | Maps an asset to the amount of accumulated protocol fees. |

## 4. User Functions

These are the primary functions that end-users will interact with.

### `deposit`

Deposits a specified amount of a supported asset and mints shares for the user.

-   **Parameters:**
    -   `asset principal`: The contract principal of the token to deposit.
    -   `amount uint`: The amount of the token to deposit.
-   **Returns:** `(ok (tuple (shares uint) (fee uint)))`

### `withdraw`

Burns a specified number of shares for a given asset to withdraw the corresponding amount of the underlying token.

-   **Parameters:**
    -   `asset principal`: The contract principal of the token to withdraw.
    -   `shares uint`: The number of shares to burn.
-   **Returns:** `(ok (tuple (amount uint) (fee uint)))`

### `flash-loan`

*Note: This function appears to be a placeholder and is not fully implemented.*

-   **Parameters:**
    -   `amount uint`: The amount of the token to borrow.
    -   `recipient principal`: The address to receive the loan.

## 5. Admin Functions

These functions can only be called by the contract's admin, ensuring changes go through governance.

| Function Name | Parameters | Description |
| --- | --- | --- |
| `transfer-admin` | `new-admin principal` | Sets a new admin address. |
| `set-paused` | `pause bool` | Pauses or unpauses the vault's core functions. |
| `set-deposit-fee` | `new-fee-bps uint` | Sets the deposit fee. |
| `set-withdrawal-fee`| `new-fee-bps uint` | Sets the withdrawal fee. |
| `set-vault-cap` | `asset principal`, `new-cap uint` | Sets the deposit cap for a specific asset. |
| `set-revenue-share` | `new-share-bps uint` | Sets the percentage of fees shared with the protocol. |
| `add-supported-asset`| `asset principal`, `strategy-contract principal`| Adds a new token to the list of supported assets and links it to a strategy. |
| `update-integration-settings`| `settings (tuple (monitor-enabled bool) (emission-enabled bool))`| Updates the flags for monitor and emission integrations. |
| `collect-protocol-fees`| `asset principal`| Collects the accumulated fees for a given asset. |
| `emergency-withdraw`| `asset principal`, `amount uint`, `recipient principal`| *Note: Placeholder function.* |
| `rebalance-vault`| `asset principal`| *Note: Placeholder function.* |

## 6. Read-Only Functions

These functions can be called by anyone to query the state of the vault.

| Function Name | Parameters | Returns | Description |
| --- | --- | --- | --- |
| `get-admin` | - | `(ok principal)` | The current admin address. |
| `is-paused` | - | `(ok bool)` | The current paused state of the vault. |
| `get-deposit-fee` | - | `(ok uint)` | The current deposit fee in BPS. |
| `get-withdrawal-fee`| - | `(ok uint)` | The current withdrawal fee in BPS. |
| `get-revenue-share`| - | `(ok uint)` | The current revenue share in BPS. |
| `get-total-balance`| `asset principal` | `(ok uint)` | The total balance of the specified asset. |
| `get-total-shares` | `asset principal` | `(ok uint)` | The total shares for the specified asset. |
| `get-user-shares`| `user principal`, `asset principal` | `(ok uint)` | A user's share balance for a specific asset. |
| `get-vault-cap`| `asset principal` | `(ok uint)` | The deposit cap for a specific asset. |
| `is-asset-supported`| `asset principal` | `bool` | Returns true if the asset is supported. |

## 7. Error Codes

| Code | Description |
| --- | --- |
| `(err u1001)` | Unauthorized (caller is not the admin). |
| `(err u1002)` | Action not allowed while vault is paused. |
| `(err u1003)` | Insufficient balance or shares. |
| `(err u1004)` | Invalid amount (e.g., zero). |
| `(err u1005)` | Global or user cap exceeded. |
| `(err u1006)` | Asset is not supported. |
| `(err u1007)` | The linked strategy has failed. |
