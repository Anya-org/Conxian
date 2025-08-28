;; =============================================================================
;; ENHANCED YIELD STRATEGY (SIMPLE VARIANT)
;; Implements minimal yield strategy with basic functionality.
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Error codes (u600+ reserved for strategy simple)
(define-constant ERR_UNAUTHORIZED (err u600))
(define-constant ERR_STRATEGY_PAUSED (err u601))
(define-constant ERR_INSUFFICIENT_BALANCE (err u602))
(define-constant ERR_INVALID_AMOUNT (err u603))

;; Constants
(define-constant PERFORMANCE_FEE_BPS u200) ;; 2%

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var strategy-paused bool false)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)

;; User balances
(define-map user-balances
  { user: principal }
  { amount: uint }
)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (pause-strategy)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set strategy-paused true)
    (ok true)
  )
)

(define-public (unpause-strategy)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set strategy-paused false)
    (ok true)
  )
)

;; Core functions
(define-public (deposit (amount uint) (token <ft-trait>))
  (begin
    (asserts! (not (var-get strategy-paused)) ERR_STRATEGY_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer tokens from user
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update user balance
    (map-set user-balances
      { user: tx-sender }
      { amount: (+ (get-user-balance tx-sender) amount) }
    )
    
    ;; Update total deposits
    (var-set total-deposits (+ (var-get total-deposits) amount))
    
    (ok amount)
  )
)

(define-public (withdraw (amount uint) (token <ft-trait>))
  (begin
    (asserts! (not (var-get strategy-paused)) ERR_STRATEGY_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (get-user-balance tx-sender) amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update user balance
    (map-set user-balances
      { user: tx-sender }
      { amount: (- (get-user-balance tx-sender) amount) }
    )
    
    ;; Update total withdrawals
    (var-set total-withdrawals (+ (var-get total-withdrawals) amount))
    
    ;; Transfer tokens to user
    (as-contract (contract-call? token transfer amount tx-sender tx-sender none))
  )
)

;; Read-only functions
(define-read-only (get-user-balance (user principal))
  (default-to u0 (get amount (map-get? user-balances { user: user })))
)

(define-read-only (get-total-deposits)
  (var-get total-deposits)
)

(define-read-only (get-total-withdrawals)
  (var-get total-withdrawals)
)

(define-read-only (get-net-deposits)
  (- (var-get total-deposits) (var-get total-withdrawals))
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-paused)
  (var-get strategy-paused)
)

;; Simple yield calculation (placeholder)
(define-read-only (calculate-yield (principal-amount uint) (time-period uint))
  ;; Simplified 5% APY calculation
  (/ (* principal-amount u5 time-period) (* u100 u365))
)
