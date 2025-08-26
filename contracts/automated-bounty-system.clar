;; Automated Bounty System - Bitcoin Principles Aligned
;; Simplified implementation for DAO governance integration

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; === ERROR CONSTANTS ===
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_BOUNTY_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_POLICY (err u403))
(define-constant ERR_BOUNTY_NOT_OPEN (err u405))

;; === DAO-ADJUSTABLE POLICY VARIABLES ===
(define-data-var min-bounty-amount uint u10000)
(define-data-var max-bounty-amount uint u1000000)
(define-data-var creator-token-multiplier uint u10)
(define-data-var contract-balance uint u0)

;; === COUNTERS ===
(define-data-var next-bounty-id uint u1)

;; === AUTOMATED BOUNTY POLICIES ===
(define-map bounty-policies 
  { policy-type: (string-ascii 32) }
  {
    enabled: bool,
    min-reputation: uint,
    category-premium: uint
  })

;; === AUTOMATED BOUNTY STORAGE ===
(define-map automated-bounties
  { bounty-id: uint }
  {
    category: (string-ascii 32),
    description: (string-utf8 256),
    reward-amount: uint,
    difficulty: uint,
    status: (string-ascii 16),
    created-at: uint
  })

;; === INITIALIZATION ===
(map-set bounty-policies { policy-type: "security" } {
  enabled: true,
  min-reputation: u1000,
  category-premium: u3
})

(map-set bounty-policies { policy-type: "feature" } {
  enabled: true,
  min-reputation: u250,
  category-premium: u15
})

;; === SIMPLIFIED BOUNTY CREATION ===
(define-public (create-automated-bounty 
  (category (string-ascii 32))
  (difficulty uint)
  (description (string-utf8 256)))
  
  (let ((bounty-amount (calculate-fair-bounty-amount category difficulty))
        (bounty-id (+ (var-get next-bounty-id) u1)))
    
    (asserts! (>= (var-get contract-balance) bounty-amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (is-valid-bounty-request description difficulty) ERR_INVALID_POLICY)
    (asserts! (is-policy-enabled category) ERR_INVALID_POLICY)
    
    (var-set contract-balance (- (var-get contract-balance) bounty-amount))
    (map-set automated-bounties { bounty-id: bounty-id } {
      category: category,
      description: description,
      reward-amount: bounty-amount,
      difficulty: difficulty,
      status: "open",
      created-at: block-height
    })
    
    (var-set next-bounty-id bounty-id)
    (print {
      event: "automated-bounty-created",
      bounty-id: bounty-id,
      amount: bounty-amount,
      category: category
    })
    (ok bounty-id)))

;; === HELPER FUNCTIONS ===
(define-private (calculate-fair-bounty-amount (category (string-ascii 32)) (difficulty uint))
  (let ((base-amount (var-get min-bounty-amount))
        (difficulty-multiplier (pow u2 difficulty))
        (category-premium (get-category-premium category))
        (calculated-amount (/ (* base-amount difficulty-multiplier category-premium) u10)))
    
    (if (> calculated-amount (var-get max-bounty-amount))
      (var-get max-bounty-amount)
      calculated-amount)))

(define-read-only (is-valid-bounty-request (description (string-utf8 256)) (difficulty uint))
  (and 
    (>= difficulty u1)
    (<= difficulty u10)
    (> (len description) u20)))

(define-read-only (is-policy-enabled (category (string-ascii 32)))
  (default-to false 
    (get enabled (map-get? bounty-policies { policy-type: category }))))

(define-read-only (get-category-premium (category (string-ascii 32)))
  (default-to u1
    (get category-premium (map-get? bounty-policies { policy-type: category }))))

;; === PUBLIC READ-ONLY FUNCTIONS ===
(define-read-only (get-bounty (bounty-id uint))
  (map-get? automated-bounties { bounty-id: bounty-id }))

(define-read-only (get-policy (policy-type (string-ascii 32)))
  (map-get? bounty-policies { policy-type: policy-type }))

(define-read-only (get-system-stats)
  {
    total-bounties: (- (var-get next-bounty-id) u1),
    min-bounty: (var-get min-bounty-amount),
    max-bounty: (var-get max-bounty-amount)
  })

;; === DAO GOVERNANCE FUNCTIONS ===
(define-public (update-policy (policy-type (string-ascii 32)) (enabled bool) (min-reputation uint) (category-premium uint))
  (begin
    ;; Only DAO governance can update policies
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_NOT_AUTHORIZED)
    
    (map-set bounty-policies { policy-type: policy-type } {
      enabled: enabled,
      min-reputation: min-reputation,
      category-premium: category-premium
    })
    
    (print { event: "policy-updated", policy-type: policy-type })
    (ok true)))

(define-public (adjust-bounty-limits (new-min uint) (new-max uint))
  (begin
    ;; Only DAO governance can adjust limits
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (< new-min new-max) ERR_INVALID_POLICY)
    
    (var-set min-bounty-amount new-min)
    (var-set max-bounty-amount new-max)
    
    (print { event: "bounty-limits-adjusted", min: new-min, max: new-max })
    (ok true)))

(define-public (deposit-funds (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender .dao-governance) ERR_NOT_AUTHORIZED)
    (try! (as-contract (contract-call? .avg-token transfer-from sender (as-contract tx-sender) amount)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (print { event: "funds-deposited", amount: amount })
    (ok true)
  )
)

(define-public (award-bounty (bounty-id uint) (winner principal))
  (begin
    (asserts! (is-eq tx-sender .dao-governance) ERR_NOT_AUTHORIZED)
    (let ((bounty (unwrap! (map-get? automated-bounties { bounty-id: bounty-id }) ERR_BOUNTY_NOT_FOUND)))
      (asserts! (is-eq (get status bounty) "open") ERR_BOUNTY_NOT_OPEN)

      ;; Transfer bounty reward to winner
      (try! (as-contract (contract-call? .avg-token transfer winner (get reward-amount bounty))))

      ;; Mint reputation tokens for winner
      (try! (as-contract (contract-call? .reputation-token mint winner u1)))

      ;; Update bounty status
      (map-set automated-bounties { bounty-id: bounty-id } (merge bounty { status: "closed" }))

      (print {
        event: "bounty-awarded",
        bounty-id: bounty-id,
        winner: winner,
        reward-amount: (get reward-amount bounty),
        reputation-awarded: u1
      })
      (ok true)
    )
  )
)
