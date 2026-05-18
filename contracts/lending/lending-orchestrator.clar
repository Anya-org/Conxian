;; lending-orchestrator.clar
;; Unified lending and borrowing engine
;; Conxian Protocol Standard Contract - Upgraded for BME

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INSUFFICIENT_COLLATERAL u1003)
(define-constant ERR_INVALID_AMOUNT u1004)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_INTERNAL u500)

(define-constant COLLATERAL_FACTOR u7500)
(define-constant RESERVE_FACTOR u1000)

;; --- Storage ---
(define-map reserve-data principal { total-deposits: uint, total-borrows: uint, total-reserves: uint, decimals: uint, last-updated: uint })
(define-map deposits { asset: principal, user: principal } uint)
(define-map borrows { asset: principal, user: principal } uint)

(define-data-var admin principal tx-sender)
(define-data-var initialized bool false)
(define-data-var assets-list (list 20 principal) (list))

;; --- Internal Helpers ---

;; @desc Check if the contract is paused
(define-read-only (is-paused)
  (let (
    (cb-res (contract-call? .enhanced-circuit-breaker is-contract-paused .lending-manager))
  )
    (if (is-ok cb-res)
      (unwrap-panic cb-res)
      true
    )
  )
)

;; --- Public Functions ---

;; @desc Deposits an asset into the lending pool.
;; @param asset-trait: The token being deposited.
;; @param amount: The quantity to deposit.
;; @returns (response bool uint)
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (match (map-get? reserve-data asset)
               res-val res-val
               { total-deposits: u0, total-borrows: u0, total-reserves: u0, decimals: (unwrap! (contract-call? asset-trait get-decimals) (err ERR_INTERNAL)), last-updated: burn-block-height }))
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      (if (is-none (index-of (var-get assets-list) asset))
        (var-set assets-list (unwrap! (as-max-len? (append (var-get assets-list) asset) u20) (err ERR_INTERNAL)))
        true
      )
      (map-set deposits { asset: asset, user: tx-sender } (+ (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })) amount))
      (map-set reserve-data asset (merge reserve { total-deposits: (+ (get total-deposits reserve) amount) }))
      (ok true)
    )
  )
)

;; @desc Borrows an asset against collateral.
;; @param asset-trait: The token to borrow.
;; @param amount: The quantity to borrow.
;; @returns (response bool uint)
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (caller tx-sender)
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (<= amount (get total-deposits reserve)) (err ERR_INSUFFICIENT_LIQUIDITY))
      (map-set borrows { asset: asset, user: caller } (+ (default-to u0 (map-get? borrows { asset: asset, user: caller })) amount))
      (map-set reserve-data asset (merge reserve { total-borrows: (+ (get total-borrows reserve) amount) }))
      (let ((hf (unwrap! (calculate-account-health caller) (err ERR_INTERNAL))))
        (asserts! (>= hf u10000) (err ERR_INSUFFICIENT_COLLATERAL))
      )
      (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) caller none)))
      (ok true)
    )
  )
)

;; @desc Repays a borrowed asset.
;; @param asset-trait: The token to repay.
;; @param amount: The quantity to repay.
;; @returns (response bool uint)
(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
    (interest-portion (/ (* amount RESERVE_FACTOR) u10000))
    (principal-portion (if (>= amount interest-portion) (- amount interest-portion) u0))
    (current-borrows (get total-borrows reserve))
    (user-borrows (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
  )
    (begin
      (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
      (let ((fee-res (contract-call? .revenue-automation collect-revenue asset-trait amount tx-sender)))
        (print { event: "lending-fee-processed", success: (is-ok fee-res) })
      )
      (let ((bme-res (contract-call? .bme-engine register-fee-activity (as-contract tx-sender) interest-portion)))
        (print { event: "bme-report-processed", success: (is-ok bme-res) })
      )
      (map-set borrows { asset: asset, user: tx-sender } (if (>= user-borrows principal-portion) (- user-borrows principal-portion) u0))
      (map-set reserve-data asset (merge reserve {
        total-borrows: (if (>= current-borrows principal-portion) (- current-borrows principal-portion) u0),
        total-reserves: (+ (get total-reserves reserve) interest-portion)
      }))
      (ok true)
    )
  )
)

;; @desc Withdraws a previously deposited asset.
;; @param asset-trait: The token to withdraw.
;; @param amount: The quantity to withdraw.
;; @returns (response bool uint)
(define-public (withdraw (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (user-deposit (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
    (reserve (unwrap! (map-get? reserve-data asset) (err ERR_NOT_FOUND)))
    (recipient tx-sender)
  )
    (begin
      (asserts! (not (is-paused)) (err ERR_PAUSED))
      (asserts! (>= user-deposit amount) (err ERR_INVALID_AMOUNT))
      (map-set deposits { asset: asset, user: tx-sender } (- user-deposit amount))
      (let ((hf (unwrap! (calculate-account-health tx-sender) (err ERR_INTERNAL))))
        (begin
          (asserts! (>= hf u10000) (err ERR_INSUFFICIENT_COLLATERAL))
          (map-set reserve-data asset (merge reserve { total-deposits: (if (>= (get total-deposits reserve) amount) (- (get total-deposits reserve) amount) u0) }))
          (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) recipient none)))
          (ok true)
        )
      )
    )
  )
)

;; --- Read-only Functions ---

;; @desc Calculates the health factor for a given user.
;; @param user: The principal to check.
;; @returns (response uint uint)
(define-read-only (calculate-account-health (user principal))
  (let (
    (summary (fold sum-user-asset-values (var-get assets-list) { user: user, collateral-value: u0, debt-value: u0 }))
  )
    (ok (if (is-eq (get debt-value summary) u0)
      u100000
      (/ (* (get collateral-value summary) u10000) (get debt-value summary))
    ))
  )
)

;; @desc Private helper for health factor calculation.
(define-private (sum-user-asset-values (asset principal) (acc { user: principal, collateral-value: uint, debt-value: uint }))
  (let (
    (user (get user acc))
    (deposit-amt (default-to u0 (map-get? deposits { asset: asset, user: user })))
    (borrow-amt (default-to u0 (map-get? borrows { asset: asset, user: user })))
    (price-res (contract-call? .oracle-aggregator get-price asset))
    (price (if (is-ok price-res) (unwrap-panic price-res) u100000000))
    (reserve-opt (map-get? reserve-data asset))
  )
    (if (is-some reserve-opt)
      (let (
        (reserve-val (unwrap-panic reserve-opt))
        (decimals (get decimals reserve-val))
        (asset-collateral-value (/ (* deposit-amt price COLLATERAL_FACTOR) (* (pow u10 decimals) u10000)))
        (asset-debt-value (/ (* borrow-amt price) (pow u10 decimals)))
      )
        { user: user, collateral-value: (+ (get collateral-value acc) asset-collateral-value), debt-value: (+ (get debt-value acc) asset-debt-value) }
      )
      acc
    )
  )
)

;; @desc Returns supply balance for a user and asset.
;; @param user: The user principal.
;; @param asset: The asset principal.
;; @returns (optional uint)
(define-read-only (get-user-supply-balance (user principal) (asset principal))
  (some (default-to u0 (map-get? deposits { asset: asset, user: user })))
)

;; @desc Returns total deposits for a specific asset.
;; @param asset: The asset principal.
;; @returns (response uint uint)
(define-read-only (get-total-deposits (asset principal))
  (match (map-get? reserve-data asset) reserve-val (ok (get total-deposits reserve-val)) (ok u0))
)

;; @desc Returns total borrows for a specific asset.
;; @param asset: The asset principal.
;; @returns (response uint uint)
(define-read-only (get-total-borrows (asset principal))
  (match (map-get? reserve-data asset) reserve-val (ok (get total-borrows reserve-val)) (ok u0))
)

;; @desc Returns raw reserve data for a specific asset.
;; @param asset: The asset principal.
;; @returns (optional { total-deposits: uint, total-borrows: uint, total-reserves: uint, decimals: uint, last-updated: uint })
(define-read-only (get-reserve-data (asset principal)) (map-get? reserve-data asset))

;; --- Admin ---

;; @desc Initialize the contract with an admin.
;; @param new-admin: The admin principal.
;; @returns (response bool uint)
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (not (var-get initialized)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

;; @desc Updates the administrator principal.
;; @param new-admin: The new admin principal.
;; @returns (response bool uint)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
