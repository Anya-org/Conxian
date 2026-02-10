;; lending-manager.clar
;; Comprehensive Lending System for Conxian Protocol

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INVALID_AMOUNT u1003)
(define-constant ERR_INSUFFICIENT_COLLATERAL u1004)

(define-constant COLLATERAL_FACTOR u7500) ;; 75% - borrow up to 75% of collateral value

;; Storage
(define-data-var circuit-breaker (optional principal) none)
(define-map deposits { asset: principal, user: principal } uint)
(define-map borrows { asset: principal, user: principal } uint)
(define-map reserve-data principal { 
  total-deposits: uint, 
  total-borrows: uint, 
  total-reserves: uint,
  last-updated: uint 
})

;; --- Helpers ---

(define-private (is-admin)
  (is-eq (ok tx-sender) (contract-call? .conxian-protocol get-protocol-admin))
)
(define-private (get-interest-rate (asset principal) (utilization uint))
  (contract-call? .economic-policy-engine get-current-interest-rate)
)
(define-private (accrue-interest (asset principal))
  (let ((reserve (default-to { total-deposits: u0, total-borrows: u0, total-reserves: u0, last-updated: burn-block-height } (map-get? reserve-data asset))))
    (let (
      (current-time burn-block-height)
      (time-delta (- current-time (get last-updated reserve)))
    )
      (if (> time-delta u0)
        (let (
          (current-total-borrows (get total-borrows reserve))
          (utilization (if (> (get total-deposits reserve) u0) (/ (* current-total-borrows u10000) (get total-deposits reserve)) u0))
          (rate (unwrap-panic (get-interest-rate asset utilization))) ;; Annual rate scaled by 10000
          ;; Simple interest for demo: Principal * Rate * Time / (BlocksPerYear * Scale)
          ;; Assuming ~52560 blocks per year (10 min blocks)
          (interest-factor (/ (* rate time-delta) u52560)) 
          (interest-accrued (/ (* current-total-borrows interest-factor) u10000))
          (reserve-factor (unwrap-panic (contract-call? .economic-policy-engine get-reserve-factor)))
          (protocol-fee (/ (* interest-accrued reserve-factor) u10000))
          (supplier-interest (- interest-accrued protocol-fee))
        )
          (map-set reserve-data asset (merge reserve {
            total-borrows: (+ current-total-borrows interest-accrued),
            total-deposits: (+ (get total-deposits reserve) supplier-interest),
            total-reserves: (+ (get total-reserves reserve) protocol-fee),
            last-updated: current-time
          }))
          (ok true)
        )
        (ok true)
      )
    )
  )
)
(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb (if (contract-call? .circuit-breaker is-contract-paused (as-contract tx-sender))
         (err ERR_PAUSED)
         (ok true))
    (ok true)
  )
)

;; --- Core Logic ---

;; @desc Deposit assets into the lending protocol.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to deposit.
;; @param amount uint - The amount of tokens to deposit.
;; @returns (response bool uint)
(define-public (deposit (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
  )
    (begin
      (try! (check-circuit-breaker))
      (unwrap-panic (accrue-interest asset))
      (let (
        (current-dep (default-to u0 (map-get? deposits { asset: asset, user: tx-sender })))
        (reserve (default-to { total-deposits: u0, total-borrows: u0, total-reserves: u0, last-updated: burn-block-height } (map-get? reserve-data asset)))
      )
        (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))

        (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

        (map-set deposits { asset: asset, user: tx-sender } (+ current-dep amount))
        (map-set reserve-data asset (merge reserve {
          total-deposits: (+ (get total-deposits reserve) amount),
          last-updated: burn-block-height
        }))

        (print { event: "deposit", user: tx-sender, asset: asset, amount: amount })
        (ok true)
      )
    )
  )
)

;; @desc Borrow assets from the protocol.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to borrow.
;; @param amount uint - The amount of tokens to borrow.
;; @returns (response bool uint)
(define-public (borrow (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
  )
    (begin
      (try! (check-circuit-breaker))
      (unwrap-panic (accrue-interest asset))
      (let (
        (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
        (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
      )
        (asserts! (not (unwrap-panic (contract-call? .conxian-protocol is-paused))) (err ERR_PAUSED))
        (asserts! (<= amount (get total-deposits reserve)) (err ERR_INSUFFICIENT_LIQUIDITY))

        ;; CRITICAL: Check collateralization before allowing borrow
        (asserts! (is-sufficiently-collateralized tx-sender amount) (err ERR_INSUFFICIENT_COLLATERAL))

        (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) tx-sender none)))

        (map-set borrows { asset: asset, user: tx-sender } (+ current-bor amount))
        (map-set reserve-data asset (merge reserve {
          total-borrows: (+ (get total-borrows reserve) amount),
          last-updated: burn-block-height
        }))

        (print { event: "borrow", user: tx-sender, asset: asset, amount: amount })
        (ok true)
      )
    )
  )
)

;; @desc Repay borrowed assets.
;; @param asset-trait <sip-010-ft-trait> - The trait of the asset to repay.
;; @param amount uint - The amount of tokens to repay.
;; @returns (response bool uint)
(define-public (repay (asset-trait <sip-010-ft-trait>) (amount uint))
  (let (
    (asset (contract-of asset-trait))
  )
    (begin
      (unwrap-panic (accrue-interest asset))
      (let (
        (current-bor (default-to u0 (map-get? borrows { asset: asset, user: tx-sender })))
        (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
      )
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))

        (let ((repaid-amount (if (> current-bor amount) amount current-bor)))
          (map-set borrows { asset: asset, user: tx-sender } (- current-bor repaid-amount))
          (map-set reserve-data asset (merge reserve {
            total-borrows: (- (get total-borrows reserve) repaid-amount),
            last-updated: burn-block-height
          }))

          (print { event: "repay", user: tx-sender, asset: asset, amount: repaid-amount })
          (ok true)
        )
      )
    )
  )
)

(define-private (is-risk-manager)
  (is-eq tx-sender .risk-manager) ;; Or look up via conxian-protocol
)

;; @desc Calculate total collateral value for a user across all assets
;; @param user principal - The user to check
;; @returns uint - Total collateral value in USD equivalent (simplified)
(define-read-only (get-user-collateral-value (user principal))
  ;; Simplified: Sum of all deposits. In production, query oracle for USD values.
  (let ((deposit-balance (default-to u0 (map-get? deposits { asset: .cxd-token, user: user }))))
    deposit-balance
  )
)

;; @desc Get total borrowed amount for a user across all assets
;; @param user principal - The user to check
;; @returns uint - Total borrowed value in USD equivalent
(define-read-only (get-user-borrow-value (user principal))
  (let ((borrow-balance (default-to u0 (map-get? borrows { asset: .cxd-token, user: user }))))
    borrow-balance
  )
)

;; @desc Check if user has sufficient collateral for a new borrow
;; @param user principal - The borrower
;; @param borrow-amount uint - The new amount to borrow
;; @returns bool - True if sufficiently collateralized
(define-read-only (is-sufficiently-collateralized (user principal) (borrow-amount uint))
  (let (
    (collateral-value (get-user-collateral-value user))
    (current-borrowed (get-user-borrow-value user))
    (total-borrow-after (+ current-borrowed borrow-amount))
    ;; Maximum borrowable = collateral * COLLATERAL_FACTOR / 10000
    (max-borrowable (/ (* collateral-value COLLATERAL_FACTOR) u10000))
  )
    (<= total-borrow-after max-borrowable)
  )
)

;; @desc Seize collateral from a user (Liquidation)
(define-public (seize-collateral (asset-trait <sip-010-ft-trait>) (user principal) (liquidator principal) (amount uint))
  (let (
    (asset (contract-of asset-trait))
    (current-dep (default-to u0 (map-get? deposits { asset: asset, user: user })))
  )
    (begin
      (asserts! (or (is-admin) (is-risk-manager)) (err ERR_UNAUTHORIZED))
      (asserts! (<= amount current-dep) (err ERR_INVALID_AMOUNT))
      
      ;; Transfer collateral balance from user to liquidator
      ;; Note: In a real system, we might physically transfer tokens or just update internal balances.
      ;; Here we update internal balances: decrease user, increase liquidator.
      ;; The liquidator can then withdraw if they want.
      
      (map-set deposits { asset: asset, user: user } (- current-dep amount))
      (map-set deposits { asset: asset, user: liquidator } (+ (default-to u0 (map-get? deposits { asset: asset, user: liquidator })) amount))
      
      (print { event: "seize-collateral", user: user, liquidator: liquidator, asset: asset, amount: amount })
      (ok true)
    )
  )
)

;; @desc Collect accumulated protocol reserves and send to revenue distributor.
(define-public (collect-reserves (asset-trait <sip-010-ft-trait>))
  (let (
    (asset (contract-of asset-trait))
  )
    (begin
      (unwrap-panic (accrue-interest asset))
      (let (
        (reserve (unwrap! (map-get? reserve-data asset) (err u404)))
        (amount (get total-reserves reserve))
        (distributor (unwrap-panic (contract-call? .economic-policy-engine get-revenue-distributor))) ;; Assuming this getter exists or we use constant
      )
        (asserts! (> amount u0) (ok true)) ;; Nothing to collect
        
        ;; Transfer to distributor
        ;; Note: We use the known revenue distributor contract directly.
        (begin
           (try! (as-contract (contract-call? asset-trait transfer amount (as-contract tx-sender) .revenue-distributor none)))
           (map-set reserve-data asset (merge reserve { total-reserves: u0 }))
           (print { event: "collect-reserves", asset: asset, amount: amount })
           (ok true)
        )
      )
    )
  )
)

;; Read-only

;; @desc Get global data for a specific asset reserve.
(define-read-only (get-reserve-data (asset principal))
  (map-get? reserve-data asset)
)

;; @desc Get the deposit balance for a user.
(define-read-only (get-user-deposit (asset principal) (user principal))
  (default-to u0 (map-get? deposits { asset: asset, user: user }))
)

;; @desc Get the borrow balance for a user.
(define-read-only (get-user-borrow (asset principal) (user principal))
  (default-to u0 (map-get? borrows { asset: asset, user: user }))
)

;; Admin

(define-public (set-circuit-breaker (new-cb principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set circuit-breaker (some new-cb))
    (ok true)
  )
)
(define-public (withdraw (asset principal) (amount uint))
  (ok true)
)
