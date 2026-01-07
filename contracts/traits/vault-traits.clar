;; vault-traits.clar
;; Vault, custody, fee-manager, btc-bridge, and yield-aggregator traits

;; @desc Standard trait for Conxian Vaults
(define-trait vault-trait
  (
    ;; @desc Deposits sBTC into the vault and mints shares representing the user's portion of the vault's assets.
    ;; @param amount uint The amount of sBTC to deposit, denominated in the smallest unit of sBTC.
    ;; @param recipient principal The recipient receiving vault shares.
    ;; @returns (response uint uint) A response containing the number of shares minted for the user, or an error code if the deposit fails.
    (deposit (uint principal) (response uint uint))

    ;; @desc Requests the withdrawal of sBTC from the vault by burning a specified number of shares. This initiates a timelock period.
    ;; @param shares uint The number of shares to burn in exchange for sBTC.
    ;; @param recipient principal The recipient receiving sBTC.
    ;; @returns (response uint uint) A response containing the amount of sBTC that will be available for withdrawal after the timelock, or an error.
    (withdraw (uint principal) (response uint uint))

    ;; @desc Completes the withdrawal process after the timelock period has passed, transferring the sBTC to the user.
    ;; @param recipient principal The recipient receiving sBTC.
    ;; @returns (response uint uint) A response containing the amount of sBTC transferred to the user, or an error if the withdrawal is not yet unlocked or fails.
    (complete-withdrawal (principal) (response uint uint))

    ;; @desc Initiates the process of wrapping BTC into sBTC. This function is typically called after a BTC transaction has been confirmed.
    ;; @param btc-amount uint The amount of BTC to wrap, denominated in satoshis.
    ;; @param btc-txid (buff 32) The transaction ID of the BTC deposit on the Bitcoin blockchain.
    ;; @returns (response uint uint) A response containing the amount of sBTC minted as a result of the wrap, or an error.
    (wrap-btc (uint (buff 32)) (response uint uint))

    ;; @desc Initiates the process of unwrapping sBTC back into BTC.
    ;; @param sbtc-amount uint The amount of sBTC to unwrap.
    ;; @param btc-address (buff 64) The destination Bitcoin address where the BTC will be sent.
    ;; @returns (response uint uint) A response containing the amount of BTC that will be sent, or an error.
    (unwrap-to-btc (uint (buff 64)) (response uint uint))

    ;; @desc Allocates a specified amount of sBTC from the vault to a yield-generating strategy contract.
    ;; @param strategy principal The principal of the strategy contract to which the funds will be allocated.
    ;; @param amount uint The amount of sBTC to allocate to the strategy.
    ;; @returns (response bool uint) A response indicating `(ok true)` on successful allocation, or an error.
    (allocate-to-strategy (principal uint) (response bool uint))

    ;; @desc Harvests yield earned from a specific strategy, bringing the profits back into the main vault.
    ;; @param strategy principal The principal of the strategy contract from which to harvest yield.
    ;; @returns (response uint uint) A response containing the net yield harvested from the strategy, or an error.
    (harvest-yield (principal) (response uint uint))

    ;; @desc Retrieves a summary of the vault's key statistics.
    ;; @returns (response { total-sbtc: uint, total-shares: uint, total-yield: uint, share-price: uint, paused: bool } uint) A response containing a tuple with the total sBTC deposited, total shares minted, total yield generated, the current price per share, and the vault's paused status.
    (get-vault-stats () (response {
      total-sbtc: uint,
      total-shares: uint,
      total-yield: uint,
      share-price: uint,
      paused: bool
    } uint))
  )
)

;; @desc Trait for custody contracts that hold assets on behalf of users
(define-trait custody-trait
  (
    ;; @desc Deposit assets into custody
    ;; @param amount uint Amount to deposit
    ;; @param recipient principal Recipient of custody shares
    ;; @returns (response bool uint) Success or error
    (deposit-to-custody (uint principal) (response bool uint))

    ;; @desc Withdraw assets from custody
    ;; @param amount uint Amount to withdraw
    ;; @param recipient principal Recipient of assets
    ;; @returns (response bool uint) Success or error
    (withdraw-from-custody (uint principal) (response bool uint))

    ;; @desc Get custody balance for an address
    ;; @param owner principal Address to check balance for
    ;; @returns (response uint uint) Balance or error
    (get-custody-balance (principal) (response uint uint))
  )
)

;; @desc Trait for fee management contracts
(define-trait fee-manager-trait
  (
    ;; @desc Set fee rate for a specific operation
    ;; @param operation (string-ascii 32) Operation type
    ;; @param rate uint Fee rate in basis points
    ;; @returns (response bool uint) Success or error
    (set-fee-rate ((string-ascii 32) uint) (response bool uint))

    ;; @desc Calculate fee for an operation
    ;; @param operation (string-ascii 32) Operation type
    ;; @param amount uint Amount to calculate fee on
    ;; @returns (response uint uint) Fee amount or error
    (calculate-fee ((string-ascii 32) uint) (response uint uint))

    ;; @desc Collect accumulated fees
    ;; @param recipient principal Address to send fees to
    ;; @returns (response bool uint) Success or error
    (collect-fees (principal) (response bool uint))
  )
)

;; @desc Trait for BTC bridge contracts
(define-trait btc-bridge-trait
  (
    ;; @desc Lock BTC for pegging
    ;; @param amount uint Amount in satoshis
    ;; @param btc-address (buff 64) Bitcoin address
    ;; @returns (response bool uint) Success or error
    (lock-btc (uint (buff 64)) (response bool uint))

    ;; @desc Unlock BTC from peg
    ;; @param amount uint Amount in satoshis
    ;; @param btc-address (buff 64) Bitcoin address
    ;; @returns (response bool uint) Success or error
    (unlock-btc (uint (buff 64)) (response bool uint))

    ;; @desc Get bridge status
    ;; @returns (response { locked: uint, unlocked: uint, pending: uint } uint) Bridge statistics
    (get-bridge-status () (response {
      locked: uint,
      unlocked: uint,
      pending: uint
    } uint))
  )
)

;; @desc Trait for yield aggregator contracts
(define-trait yield-aggregator-trait
  (
    ;; @desc Add strategy to aggregator
    ;; @param strategy principal Strategy contract address
    ;; @param weight uint Strategy weight allocation
    ;; @returns (response bool uint) Success or error
    (add-strategy (principal uint) (response bool uint))

    ;; @desc Remove strategy from aggregator
    ;; @param strategy principal Strategy contract address
    ;; @returns (response bool uint) Success or error
    (remove-strategy (principal) (response bool uint))

    ;; @desc Rebalance allocations across strategies
    ;; @returns (response bool uint) Success or error
    (rebalance-strategies () (response bool uint))

    ;; @desc Get total yield across all strategies
    ;; @returns (response uint uint) Total yield or error
    (get-total-yield () (response uint uint))
  )
)
