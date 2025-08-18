;; =============================================================================
;; ENHANCED YIELD STRATEGY - PHASE 2 IMPLEMENTATION
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
;; Remove problematic strategy-trait import for now
;; (use-trait strategy-trait .strategy-trait.strategy-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_STRATEGY (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_STRATEGY_PAUSED (err u403))
(define-constant ERR_INVALID_AMOUNT (err u404))

;; State variables
(define-data-var strategy-manager principal tx-sender)
(define-data-var next-strategy-id uint u1)
(define-data-var auto-compound-enabled bool true)
(define-data-var risk-tolerance uint u3) ;; Scale 1-5

;; Strategy registry
(define-map strategies
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    target-token: principal,
    apy-estimate: uint,
    risk-level: uint,
    min-deposit: uint,
    active: bool,
    total-deposited: uint
  })

;; User positions
(define-map user-positions
  {user: principal, strategy-id: uint}
  {
    deposited: uint,
    shares: uint,
    last-harvest: uint,
    auto-compound: bool
  })

;; Strategy performance tracking
(define-map strategy-performance
  uint
  {
    total-yield: uint,
    last-harvest: uint,
    harvest-count: uint,
    performance-fee: uint
  })

;; Authorization
(define-private (is-strategy-manager)
  (is-eq tx-sender (var-get strategy-manager)))

;; =============================================================================
;; CORE STRATEGY FUNCTIONS
;; =============================================================================

;; Deposit to strategy
(define-public (deposit-to-strategy
  (strategy-id uint)
  (amount uint)
  (enable-auto-compound bool))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    (asserts! (get active strategy) ERR_STRATEGY_PAUSED)
    (asserts! (>= amount (get min-deposit strategy)) ERR_INVALID_AMOUNT)
    
    ;; Calculate shares based on current pool size
    (let ((shares (calculate-shares strategy-id amount))
          (current-position (default-to 
                           {deposited: u0, shares: u0, last-harvest: block-height, auto-compound: false}
                           (map-get? user-positions {user: tx-sender, strategy-id: strategy-id}))))
      
      ;; Update user position
      (map-set user-positions {user: tx-sender, strategy-id: strategy-id}
        {
          deposited: (+ (get deposited current-position) amount),
          shares: (+ (get shares current-position) shares),
          last-harvest: block-height,
          auto-compound: enable-auto-compound
        })
      
      ;; Update strategy totals
      (map-set strategies strategy-id
        (merge strategy {total-deposited: (+ (get total-deposited strategy) amount)}))
      
      (print {
        event: "strategy-deposit",
        user: tx-sender,
        strategy-id: strategy-id,
        amount: amount,
        shares: shares
      })
      
      (ok shares))))

;; Withdraw from strategy
(define-public (withdraw-from-strategy
  (strategy-id uint)
  (shares uint))
  (let ((position (unwrap! (map-get? user-positions {user: tx-sender, strategy-id: strategy-id}) ERR_INVALID_STRATEGY))
        (strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    
    (asserts! (>= (get shares position) shares) ERR_INSUFFICIENT_BALANCE)
    
    ;; Calculate withdrawal amount
    (let ((withdrawal-amount (calculate-withdrawal-amount strategy-id shares)))
      
      ;; Update user position
      (if (is-eq (get shares position) shares)
        ;; Full withdrawal - remove position
        (map-delete user-positions {user: tx-sender, strategy-id: strategy-id})
        ;; Partial withdrawal - update position
        (map-set user-positions {user: tx-sender, strategy-id: strategy-id}
          (merge position {
            deposited: (- (get deposited position) withdrawal-amount),
            shares: (- (get shares position) shares)
          })))
      
      ;; Update strategy totals
      (map-set strategies strategy-id
        (merge strategy {total-deposited: (- (get total-deposited strategy) withdrawal-amount)}))
      
      (print {
        event: "strategy-withdrawal",
        user: tx-sender,
        strategy-id: strategy-id,
        shares: shares,
        amount: withdrawal-amount
      })
      
      (ok withdrawal-amount))))

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

;; Calculate shares for deposit
(define-private (calculate-shares (strategy-id uint) (amount uint))
  ;; Simple 1:1 ratio for now - could be enhanced with complex calculations
  amount)

;; Calculate withdrawal amount
(define-private (calculate-withdrawal-amount (strategy-id uint) (shares uint))
  ;; Simple 1:1 ratio for now
  shares)

;; =============================================================================
;; STRATEGY MANAGEMENT
;; =============================================================================

;; Register new strategy
(define-public (register-strategy
  (name (string-ascii 50))
  (description (string-ascii 200))
  (target-token principal)
  (apy-estimate uint)
  (risk-level uint)
  (min-deposit uint))
  (begin
    (asserts! (is-strategy-manager) ERR_UNAUTHORIZED)
    (asserts! (<= risk-level u5) ERR_INVALID_STRATEGY)
    
    (let ((strategy-id (var-get next-strategy-id)))
      (map-set strategies strategy-id {
        name: name,
        description: description,
        target-token: target-token,
        apy-estimate: apy-estimate,
        risk-level: risk-level,
        min-deposit: min-deposit,
        active: true,
        total-deposited: u0
      })
      
      (var-set next-strategy-id (+ strategy-id u1))
      
      (print {
        event: "strategy-registered",
        strategy-id: strategy-id,
        name: name
      })
      
      (ok strategy-id))))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-strategy (strategy-id uint))
  (map-get? strategies strategy-id))

(define-read-only (get-user-position (user principal) (strategy-id uint))
  (map-get? user-positions {user: user, strategy-id: strategy-id}))

(define-read-only (get-strategy-performance (strategy-id uint))
  (map-get? strategy-performance strategy-id))

(define-read-only (get-total-strategies)
  (- (var-get next-strategy-id) u1))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (transfer-management (new-manager principal))
  (begin
    (asserts! (is-strategy-manager) ERR_UNAUTHORIZED)
    (var-set strategy-manager new-manager)
    (ok true)))

(define-public (pause-strategy (strategy-id uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_INVALID_STRATEGY)))
    (asserts! (is-strategy-manager) ERR_UNAUTHORIZED)
    (map-set strategies strategy-id (merge strategy {active: false}))
    (ok true)))

(define-public (set-auto-compound (enabled bool))
  (begin
    (asserts! (is-strategy-manager) ERR_UNAUTHORIZED)
    (var-set auto-compound-enabled enabled)
    (ok true)))
