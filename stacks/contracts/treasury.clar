;; Treasury Management - DAO Controlled Fund Management
;; Handles protocol funds, bounty payments, and treasury operations

(use-trait sip010 .sip-010-trait.sip-010-trait)

;; Constants
(define-constant TREASURY_CATEGORIES_DEVELOPMENT u0)
(define-constant TREASURY_CATEGORIES_MARKETING u1)
(define-constant TREASURY_CATEGORIES_OPERATIONS u2)
(define-constant TREASURY_CATEGORIES_RESERVES u3)
(define-constant TREASURY_CATEGORIES_BOUNTIES u4)
(define-constant TREASURY_CATEGORIES_BUYBACKS u5)

;; Auto-buyback settings
(define-constant BUYBACK_THRESHOLD_BPS u500) ;; 5% of treasury triggers buyback
(define-constant BUYBACK_MAX_BPS u1000) ;; Max 10% of treasury per buyback
(define-constant BUYBACK_FREQUENCY_BLOCKS u1008) ;; Weekly buybacks

;; Data Variables
(define-data-var dao-governance principal .timelock)
(define-data-var bounty-system principal .bounty-system)
(define-data-var vault principal .vault)
(define-data-var total-allocated uint u0)
(define-data-var total-spent uint u0)

;; Auto-buyback tracking
(define-data-var last-buyback-block uint u0)
(define-data-var total-buybacks uint u0)
(define-data-var total-avg-bought uint u0)
(define-data-var stx-reserve uint u0)
(define-data-var buyback-enabled bool true)

;; Treasury allocations by category
(define-map category-allocations
  { category: uint }
  { 
    allocated: uint,
    spent: uint,
    reserved: uint
  }
)

;; Spending proposals and tracking
(define-map spending-records
  { id: uint }
  {
    recipient: principal,
    amount: uint,
    category: uint,
    purpose: (string-utf8 200),
    approved-by: principal,
    spent-block: uint
  }
)

(define-data-var spending-record-count uint u0)

;; Budget periods for planning
(define-map budget-periods
  { period: uint }
  {
    start-block: uint,
    end-block: uint,
    total-budget: uint,
    spent: uint,
    active: bool
  }
)

(define-data-var current-budget-period uint u0)

;; Events
(define-private (emit-funds-allocated (category uint) (amount uint))
  (print {
    event: "funds-allocated",
    category: category,
    amount: amount,
    block: block-height
  })
)

(define-private (emit-payment-made (recipient principal) (amount uint) (category uint))
  (print {
    event: "payment-made",
    recipient: recipient,
    amount: amount,
    category: category,
    block: block-height
  })
)

;; Read-only functions
(define-read-only (get-category-allocation (category uint))
  (default-to 
    { allocated: u0, spent: u0, reserved: u0 }
    (map-get? category-allocations { category: category })
  )
)

(define-read-only (get-spending-record (id uint))
  (map-get? spending-records { id: id })
)

(define-read-only (get-budget-period (period uint))
  (map-get? budget-periods { period: period })
)

(define-read-only (get-treasury-balance)
  ;; Get balance from vault's treasury reserve - will be enabled after vault deployment
  ;; (contract-call? .vault get-treasury-reserve)
  u0 ;; Temporary until vault integration
)

(define-read-only (get-available-funds (category uint))
  (let ((allocation (get-category-allocation category)))
    (- (+ (get allocated allocation) (get reserved allocation)) (get spent allocation))
  )
)

(define-read-only (get-treasury-summary)
  {
    total-balance: (get-treasury-balance),
    total-allocated: (var-get total-allocated),
    total-spent: (var-get total-spent),
    available: (- (get-treasury-balance) (var-get total-allocated)),
    current-period: (var-get current-budget-period)
  }
)

;; Public functions (DAO controlled)
(define-public (allocate-funds (category uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (asserts! (<= category TREASURY_CATEGORIES_BOUNTIES) (err u101))
    (asserts! (> amount u0) (err u102))
    
    ;; Check if funds are available
    (let ((treasury-balance (get-treasury-balance)))
      (asserts! (>= (- treasury-balance (var-get total-allocated)) amount) (err u103))
    )
    
    ;; Update category allocation
    (let ((current-allocation (get-category-allocation category)))
      (map-set category-allocations { category: category }
        (merge current-allocation {
          allocated: (+ (get allocated current-allocation) amount)
        })
      )
    )
    
    (var-set total-allocated (+ (var-get total-allocated) amount))
    (emit-funds-allocated category amount)
    (ok true)
  )
)

(define-public (spend (recipient principal) (amount uint))
  (begin
    ;; Only DAO governance can authorize spending
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (try! (spend-from-category recipient amount TREASURY_CATEGORIES_OPERATIONS u"DAO authorized spending"))
    (ok true)
  )
)

(define-public (pay-milestone (recipient principal) (amount uint))
  (begin
    ;; Only bounty system can pay milestones
    (asserts! (is-eq tx-sender (var-get bounty-system)) (err u100))
    (try! (spend-from-category recipient amount TREASURY_CATEGORIES_BOUNTIES u"Milestone payment"))
    (ok true)
  )
)

(define-public (spend-from-category 
  (recipient principal) 
  (amount uint) 
  (category uint)
  (purpose (string-utf8 200))
)
  (begin
    (asserts! (or 
      (is-eq tx-sender (var-get dao-governance))
      (is-eq tx-sender (var-get bounty-system))
    ) (err u100))
    (asserts! (> amount u0) (err u102))
    
    ;; Check category has sufficient funds
    (asserts! (>= (get-available-funds category) amount) (err u104))
    
    ;; Transfer funds from vault treasury
    ;; (unwrap! (as-contract (contract-call? .vault withdraw-treasury recipient amount)) (err u200))
    
    ;; Update spending records
    (let ((record-id (+ (var-get spending-record-count) u1)))
      (map-set spending-records { id: record-id }
        {
          recipient: recipient,
          amount: amount,
          category: category,
          purpose: purpose,
          approved-by: tx-sender,
          spent-block: block-height
        }
      )
      (var-set spending-record-count record-id)
    )
    
    ;; Update category spending
    (let ((allocation (get-category-allocation category)))
      (map-set category-allocations { category: category }
        (merge allocation {
          spent: (+ (get spent allocation) amount)
        })
      )
    )
    
    (var-set total-spent (+ (var-get total-spent) amount))
    (emit-payment-made recipient amount category)
    (ok true)
  )
)

(define-public (reserve-funds (category uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (asserts! (<= category TREASURY_CATEGORIES_BOUNTIES) (err u101))
    
    ;; Check available funds in category
    (let ((allocation (get-category-allocation category)))
      (asserts! (>= (- (get allocated allocation) (get spent allocation)) amount) (err u104))
      
      (map-set category-allocations { category: category }
        (merge allocation {
          reserved: (+ (get reserved allocation) amount)
        })
      )
    )
    
    (print {
      event: "funds-reserved",
      category: category,
      amount: amount,
      block: block-height
    })
    (ok true)
  )
)

(define-public (release-reserved-funds (category uint) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    
    (let ((allocation (get-category-allocation category)))
      (asserts! (>= (get reserved allocation) amount) (err u105))
      
      (map-set category-allocations { category: category }
        (merge allocation {
          reserved: (- (get reserved allocation) amount)
        })
      )
    )
    
    (print {
      event: "reserved-funds-released",
      category: category,
      amount: amount,
      block: block-height
    })
    (ok true)
  )
)

(define-public (create-budget-period (duration-blocks uint) (total-budget uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (asserts! (> duration-blocks u0) (err u106))
    (asserts! (> total-budget u0) (err u102))
    
    ;; End current period if active
    (let ((current-period (var-get current-budget-period)))
      (if (> current-period u0)
        (match (get-budget-period current-period)
          period (if (get active period)
            (map-set budget-periods { period: current-period }
              (merge period { active: false })
            )
            true
          )
          true
        )
        true
      )
    )
    
    ;; Create new budget period
    (let ((new-period (+ (var-get current-budget-period) u1)))
      (map-set budget-periods { period: new-period }
        {
          start-block: block-height,
          end-block: (+ block-height duration-blocks),
          total-budget: total-budget,
          spent: u0,
          active: true
        }
      )
      
      (var-set current-budget-period new-period)
      
      (print {
        event: "budget-period-created",
        period: new-period,
        duration-blocks: duration-blocks,
        total-budget: total-budget
      })
      (ok new-period)
    )
  )
)

;; Emergency functions
(define-public (emergency-withdraw (recipient principal) (amount uint))
  (begin
    ;; Only DAO can authorize emergency withdrawals
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    
    ;; Transfer directly from vault treasury
    (unwrap! (as-contract (contract-call? .vault withdraw-treasury recipient amount)) (err u200))
    
    (print {
      event: "emergency-withdrawal",
      recipient: recipient,
      amount: amount,
      authorized-by: tx-sender,
      block: block-height
    })
    (ok true)
  )
)

;; Configuration functions
(define-public (set-dao-governance (new-dao principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set dao-governance new-dao)
    (ok true)
  )
)

(define-public (set-bounty-system (new-bounty-system principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set bounty-system new-bounty-system)
    (ok true)
  )
)

;; Auto-buyback functions
(define-public (execute-auto-buyback)
  (begin
    (asserts! (var-get buyback-enabled) (err u300))
    (asserts! (>= (- block-height (var-get last-buyback-block)) BUYBACK_FREQUENCY_BLOCKS) (err u301))
    
    (let (
      (treasury-balance (var-get stx-reserve))
      (buyback-threshold (/ (* treasury-balance BUYBACK_THRESHOLD_BPS) u10000))
      (max-buyback (/ (* treasury-balance BUYBACK_MAX_BPS) u10000))
    )
      (asserts! (>= treasury-balance buyback-threshold) (err u302))
      
      ;; Calculate buyback amount based on treasury health
      (let ((buyback-amount (if (< max-buyback (/ treasury-balance u20)) max-buyback (/ treasury-balance u20)))) ;; Use smaller amount
        
        ;; Execute buyback through DEX (placeholder for DEX integration)
        ;; (unwrap! (contract-call? .dex swap-stx-for-avg buyback-amount) (err u303))
        
        ;; Update tracking
        (var-set last-buyback-block block-height)
        (var-set total-buybacks (+ (var-get total-buybacks) u1))
        (var-set stx-reserve (- (var-get stx-reserve) buyback-amount))
        
        ;; Estimate AVG bought (1 STX = ~100 AVG estimated)
        (let ((estimated-avg-bought (* buyback-amount u100)))
          (var-set total-avg-bought (+ (var-get total-avg-bought) estimated-avg-bought))
          
          (print {
            event: "auto-buyback-executed",
            stx-spent: buyback-amount,
            estimated-avg-bought: estimated-avg-bought,
            treasury-balance: (var-get stx-reserve),
            block: block-height
          })
          (ok estimated-avg-bought)
        )
      )
    )
  )
)

(define-public (deposit-stx-reserve (amount uint))
  (begin
    (asserts! (> amount u0) (err u102))
    
    ;; Transfer STX from vault to treasury reserve
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) (err u304))
    (var-set stx-reserve (+ (var-get stx-reserve) amount))
    
    (print {
      event: "stx-reserve-deposit",
      amount: amount,
      new-balance: (var-get stx-reserve),
      depositor: tx-sender
    })
    (ok true)
  )
)

(define-public (configure-buyback (enabled bool) (threshold-bps uint) (max-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (asserts! (<= threshold-bps u2000) (err u305)) ;; Max 20% threshold
    (asserts! (<= max-bps u2000) (err u306)) ;; Max 20% per buyback
    
    (var-set buyback-enabled enabled)
    
    (print {
      event: "buyback-configured",
      enabled: enabled,
      threshold-bps: threshold-bps,
      max-bps: max-bps
    })
    (ok true)
  )
)

(define-read-only (get-buyback-status)
  {
    enabled: (var-get buyback-enabled),
    stx-reserve: (var-get stx-reserve),
    last-buyback-block: (var-get last-buyback-block),
    blocks-until-next: (let ((blocks-passed (- block-height (var-get last-buyback-block))))
      (if (>= blocks-passed BUYBACK_FREQUENCY_BLOCKS) u0 (- BUYBACK_FREQUENCY_BLOCKS blocks-passed))
    ),
    total-buybacks: (var-get total-buybacks),
    total-avg-bought: (var-get total-avg-bought),
    buyback-ready: (and 
      (var-get buyback-enabled)
      (>= (- block-height (var-get last-buyback-block)) BUYBACK_FREQUENCY_BLOCKS)
      (>= (var-get stx-reserve) (/ (* (var-get stx-reserve) BUYBACK_THRESHOLD_BPS) u10000))
    )
  }
)

(define-read-only (get-next-buyback-amount)
  (let (
    (treasury-balance (var-get stx-reserve))
    (max-buyback (/ (* treasury-balance BUYBACK_MAX_BPS) u10000))
    (default-buyback (/ treasury-balance u20)) ;; 5%
  )
    (if (var-get buyback-enabled)
      (if (< max-buyback default-buyback) max-buyback default-buyback)
      u0
    )
  )
)

;; Analytics functions
(define-read-only (get-spending-by-category (category uint))
  (get spent (get-category-allocation category))
)

(define-read-only (get-category-utilization (category uint))
  (let ((allocation (get-category-allocation category)))
    (if (is-eq (get allocated allocation) u0)
      u0
      (/ (* (get spent allocation) u10000) (get allocated allocation)) ;; Return in basis points
    )
  )
)

(define-read-only (get-budget-period-status (period uint))
  (match (get-budget-period period)
    budget-period (let (
      (current-block block-height)
      (end-block (get end-block budget-period))
      (spent (get spent budget-period))
      (total-budget (get total-budget budget-period))
    )
    (some {
      active: (get active budget-period),
      expired: (> current-block end-block),
      utilization: (if (is-eq total-budget u0) u0 (/ (* spent u10000) total-budget)),
      remaining-budget: (- total-budget spent),
      blocks-remaining: (if (> end-block current-block) (- end-block current-block) u0)
    }))
    none
  )
)

;; Errors
;; u100: unauthorized
;; u101: invalid-category
;; u102: invalid-amount
;; u103: insufficient-treasury-funds
;; u104: insufficient-category-funds
;; u105: insufficient-reserved-funds
;; u106: invalid-duration
;; u200: vault-error
;; u300-399: buyback errors
;; u300: buyback-disabled
;; u301: buyback-too-frequent
;; u302: insufficient-reserves-for-buyback
;; u303: dex-swap-failed
;; u304: stx-transfer-failed
;; u305: invalid-threshold
;; u306: invalid-max-buyback
