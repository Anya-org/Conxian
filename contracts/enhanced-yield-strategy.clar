;; =============================================================================
;; ENHANCED YIELD STRATEGY (STANDARD VARIANT)
;; Implements basic yield strategy management with simplified accounting.
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
(use-trait strategy-trait .strategy-trait.auto-strategy-trait)

;; Error codes (u700+ reserved for strategy standard)
(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_STRATEGY_PAUSED (err u701))
(define-constant ERR_INSUFFICIENT_BALANCE (err u702))
(define-constant ERR_INVALID_STRATEGY (err u703))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u704))

;; Constants
(define-constant MAX_STRATEGIES u5)
(define-constant MAX_ALLOCATION_BPS u10000) ;; 100%
(define-constant PERFORMANCE_FEE_BPS u300) ;; 3%

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var strategy-paused bool false)
(define-data-var total-assets uint u0)
(define-data-var total-shares uint u0)

;; Strategy registry
(define-map strategies
  { strategy-id: uint }
  {
    contract: principal,
    allocation-bps: uint,
    active: bool,
    last-harvest: uint
  }
)

(define-data-var strategy-count uint u0)

;; User positions
(define-map user-shares
  { user: principal }
  { shares: uint }
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

;; Strategy management
(define-public (add-strategy (strategy-contract principal) (allocation-bps uint))
  (let ((strategy-id (var-get strategy-count)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get strategy-paused)) ERR_STRATEGY_PAUSED)
    (asserts! (<= allocation-bps MAX_ALLOCATION_BPS) ERR_INVALID_STRATEGY)
    
    (map-set strategies
      { strategy-id: strategy-id }
      {
        contract: strategy-contract,
        allocation-bps: allocation-bps,
        active: true,
        last-harvest: block-height
      }
    )
    (var-set strategy-count (+ strategy-id u1))
    (ok strategy-id)
  )
)

;; Deposit function
(define-public (deposit (amount uint) (token <ft-trait>))
  (let ((shares-to-mint (calculate-shares-to-mint amount)))
    (asserts! (not (var-get strategy-paused)) ERR_STRATEGY_PAUSED)
    (asserts! (> amount u0) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer tokens from user
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update user shares
    (map-set user-shares
      { user: tx-sender }
      { shares: (+ (get-user-shares tx-sender) shares-to-mint) }
    )
    
    ;; Update totals
    (var-set total-assets (+ (var-get total-assets) amount))
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    
    (ok shares-to-mint)
  )
)

;; Withdraw function
(define-public (withdraw (shares uint) (token <ft-trait>))
  (let ((amount-to-withdraw (calculate-amount-from-shares shares)))
    (asserts! (not (var-get strategy-paused)) ERR_STRATEGY_PAUSED)
    (asserts! (>= (get-user-shares tx-sender) shares) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update user shares
    (map-set user-shares
      { user: tx-sender }
      { shares: (- (get-user-shares tx-sender) shares) }
    )
    
    ;; Update totals
    (var-set total-assets (- (var-get total-assets) amount-to-withdraw))
    (var-set total-shares (- (var-get total-shares) shares))
    
    ;; Transfer tokens to user
    (as-contract (contract-call? token transfer amount-to-withdraw tx-sender tx-sender none))
  )
)

;; Helper functions
(define-private (calculate-shares-to-mint (amount uint))
  (if (is-eq (var-get total-shares) u0)
    amount
    (/ (* amount (var-get total-shares)) (var-get total-assets))
  )
)

(define-private (calculate-amount-from-shares (shares uint))
  (if (is-eq (var-get total-shares) u0)
    u0
    (/ (* shares (var-get total-assets)) (var-get total-shares))
  )
)

;; Read-only functions
(define-read-only (get-user-shares (user principal))
  (default-to u0 (get shares (map-get? user-shares { user: user })))
)

(define-read-only (get-total-assets)
  (var-get total-assets)
)

(define-read-only (get-total-shares)
  (var-get total-shares)
)

(define-read-only (get-strategy (strategy-id uint))
  (map-get? strategies { strategy-id: strategy-id })
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-paused)
  (var-get strategy-paused)
)
