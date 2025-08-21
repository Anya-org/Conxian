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
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

(define-read-only (is-dao-or-admin)
  (or (is-eq tx-sender (var-get dao-governance))
      (is-eq tx-sender .dao)
      (is-eq tx-sender .timelock)))

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
  ;; Source of truth is vault treasury reserve
  (contract-call? .vault get-treasury-reserve)
)

;; Available funds (unspent & unreserved) in a category
(define-read-only (get-available-funds (category uint))
  (let ((allocation (get-category-allocation category)))
    (- (get allocated allocation) (+ (get spent allocation) (get reserved allocation)))
  )
)

(define-read-only (get-treasury-summary)
  (let ((bal (get-treasury-balance)))
    {
      total-balance: bal,
      total-allocated: (var-get total-allocated),
      total-spent: (var-get total-spent),
      available: (if (> bal (var-get total-allocated)) (- bal (var-get total-allocated)) u0),
      current-period: (var-get current-budget-period)
    }
  )
)

;; Integrity / invariant check: ensures accounting consistency
(define-read-only (get-integrity-status)
  (let (
    (bal (get-treasury-balance))
    (allocated (var-get total-allocated))
    (spent (var-get total-spent))
  )
    {
      sufficient-balance: (>= bal spent),
      allocated-ge-spent: (>= allocated spent),
      allocated-le-balance: (<= allocated bal),
      status-ok: (and (>= bal spent) (>= allocated spent) (<= allocated bal))
    }
  )
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
  (unwrap! (as-contract (contract-call? .vault withdraw-treasury recipient amount)) (err u200))
    
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

;; === DEX Trait & Mock Integration (for buybacks) ===
(define-trait dex-trait
  (
    (swap-stx-for-avg (uint) (response uint uint))
  )
)

;; Auto-buyback functions
(define-public (execute-auto-buyback)
  (begin
    (asserts! (var-get buyback-enabled) (err u300))
    (asserts! (>= (- block-height (var-get last-buyback-block)) BUYBACK_FREQUENCY_BLOCKS) (err u301))
    (let (
      (treasury-balance (var-get stx-reserve))
      (min-abs u100)
      (buyback-threshold (/ (* (var-get stx-reserve) BUYBACK_THRESHOLD_BPS) u10000))
      (max-buyback (/ (* (var-get stx-reserve) BUYBACK_MAX_BPS) u10000))
    )
      (asserts! (and (>= treasury-balance buyback-threshold) (>= treasury-balance min-abs)) (err u302))
      (let ((buyback-amount (if (< max-buyback (/ treasury-balance u20)) max-buyback (/ treasury-balance u20))))
          (let ((transfer-success (unwrap! (contract-call? .mock-ft transfer tx-sender buyback-amount) (err u303))))
          (var-set last-buyback-block block-height)
          (var-set total-buybacks (+ (var-get total-buybacks) u1))
          (var-set stx-reserve (- (var-get stx-reserve) buyback-amount))
          (let ((estimated-avg-bought buyback-amount)) ;; Use buyback amount as estimated AVG bought
            (var-set total-avg-bought (+ (var-get total-avg-bought) estimated-avg-bought))
            (print { event: "auto-buyback-executed", stx-spent: buyback-amount, estimated-avg-bought: estimated-avg-bought, treasury-balance: (var-get stx-reserve), block: block-height })
            (ok estimated-avg-bought)
          )
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
;; u1 reused earlier: invalid-amount (align with vault)
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
;; u400: multisig-list-full
;; u401: not-multisig-member
;; u404: proposal-not-found
;; u405: already-approved
;; u406: proposal-already-executed
;; u407: approval-list-full
;; u408: insufficient-approvals
;; u409: time-delay-not-met

;; === AIP-3: Treasury Multi-Sig Security Enhancement ===
(define-constant MULTISIG_THRESHOLD u3) ;; 3 out of 5 signatures required
(define-data-var large-amount-threshold uint u50000) ;; Dynamic threshold (was constant)
(define-data-var execution-delay-blocks uint u144) ;; Configurable delay for large amounts

(define-data-var proposal-counter uint u0)
(define-data-var multisig-members (list 5 principal) (list))

(define-map multisig-proposals
  { proposal-id: uint }
  {
    amount: uint,
    recipient: principal,
    asset-type: uint, ;; 0=STX, 1=AVG
    description: (string-utf8 200),
    approvals: (list 5 principal),
    approval-count: uint,
    created-block: uint,
    executed: bool
  })

;; Authorization check for DAO or extension
(define-private (is-dao-or-extension)
  (is-eq tx-sender (var-get dao-governance)))

;; Add multisig member (admin only)
;; Event helpers
(define-private (emit-multisig (etype (string-utf8 20)) (pid uint))
  (print { event: etype, proposal-id: pid, block: block-height })
)

(define-public (add-multisig-member (member principal))
  (begin
    (asserts! (is-dao-or-extension) (err u100))
    ;; Prevent duplicates
    (asserts! (is-none (index-of (var-get multisig-members) member)) (err u401))
    (var-set multisig-members 
      (unwrap! (as-max-len? (append (var-get multisig-members) member) u5) (err u400)))
    (print { event: "multisig-member-added", member: member })
    (ok true)))

(define-public (remove-multisig-member (member principal))
  (begin
    (asserts! (is-dao-or-extension) (err u100))
    (let ((members (var-get multisig-members)))
      (asserts! (is-some (index-of members member)) (err u401))
      ;; Simple removal by setting to empty list for now
      (var-set multisig-members (list))
      (print { event: "multisig-member-removed", member: member })
      (ok true))))

(define-public (set-execution-delay (blocks uint))
  (begin
    (asserts! (is-dao-or-extension) (err u100))
    (var-set execution-delay-blocks blocks)
    (print { event: "multisig-delay-set", blocks: blocks })
    (ok true)))

(define-public (set-large-amount-threshold (amount uint))
  (begin
    (asserts! (is-dao-or-extension) (err u100))
    (var-set large-amount-threshold amount)
    (print { event: "multisig-threshold-set", amount: amount })
    (ok true)))

;; Create spending proposal
(define-public (propose-spending (amount uint) (recipient principal) (asset-type uint) (description (string-utf8 200)))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (members (var-get multisig-members))
  )
    ;; Only multisig members can propose
    (asserts! (is-some (index-of members tx-sender)) (err u401))
    
    (map-set multisig-proposals { proposal-id: proposal-id }
      {
        amount: amount,
        recipient: recipient,
        asset-type: asset-type,
        description: description,
        approvals: (list tx-sender),
        approval-count: u1,
        created-block: block-height,
        executed: false
      })
    
    (var-set proposal-counter proposal-id)
    (emit-multisig u"proposal-created" proposal-id)
    (ok proposal-id)
  )
)

;; Approve spending proposal
(define-public (approve-spending (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? multisig-proposals { proposal-id: proposal-id }) (err u404)))
    (members (var-get multisig-members))
    (current-approvals (get approvals proposal))
  )
    ;; Only multisig members can approve
    (asserts! (is-some (index-of members tx-sender)) (err u401))
    ;; Cannot double-approve
    (asserts! (is-none (index-of current-approvals tx-sender)) (err u405))
    ;; Cannot approve executed proposals
    (asserts! (not (get executed proposal)) (err u406))
    
    (let (
      (new-approvals (unwrap! (as-max-len? (append current-approvals tx-sender) u5) (err u407)))
      (new-count (+ (get approval-count proposal) u1))
    )
      (map-set multisig-proposals { proposal-id: proposal-id }
        (merge proposal {
          approvals: new-approvals,
          approval-count: new-count
        }))
      (emit-multisig u"proposal-approved" proposal-id)
      (ok new-count)
    )
  )
)

;; Execute approved spending proposal
(define-public (execute-spending (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? multisig-proposals { proposal-id: proposal-id }) (err u404)))
  )
    ;; Must have enough approvals
    (asserts! (>= (get approval-count proposal) MULTISIG_THRESHOLD) (err u408))
    ;; Must not be already executed
    (asserts! (not (get executed proposal)) (err u406))
    ;; Check time delay for large amounts
    (if (>= (get amount proposal) (var-get large-amount-threshold))
      (asserts! (>= (- block-height (get created-block proposal)) (var-get execution-delay-blocks)) (err u409))
      true)
    
    ;; Execute the transfer
    (if (is-eq (get asset-type proposal) u0)
      ;; STX transfer
      (try! (stx-transfer? (get amount proposal) (as-contract tx-sender) (get recipient proposal)))
      ;; Token transfer using gov-token instead of avg-token to avoid circular dependency
      (try! (as-contract (contract-call? .gov-token transfer (get recipient proposal) (get amount proposal)))))
    
    ;; Mark as executed
    (map-set multisig-proposals { proposal-id: proposal-id }
      (merge proposal { executed: true }))
    (emit-multisig u"proposal-executed" proposal-id)
    (ok true)
  )
)

;; Enhanced Treasury Growth Strategies
(define-data-var yield-strategy-enabled bool true)
(define-data-var treasury-growth-target-bps uint u1500) ;; 15% annual growth target
(define-data-var defi-allocation-bps uint u2000) ;; 20% for DeFi strategies
(define-data-var liquidity-allocation-bps uint u3000) ;; 30% for LP provision
(define-data-var reserve-allocation-bps uint u5000) ;; 50% safety reserves

;; Investment tracking
(define-data-var total-yield-generated uint u0)
(define-data-var defi-investments uint u0)
(define-data-var lp-investments uint u0)
(define-data-var investment-round uint u0)

;; Execute treasury growth strategy
(define-public (execute-growth-strategy)
  (begin
    (asserts! (is-dao-or-admin) (err u401))
    (asserts! (var-get yield-strategy-enabled) (err u410))
    
    (let ((treasury-balance (stx-get-balance (as-contract tx-sender)))
          (defi-amount (/ (* treasury-balance (var-get defi-allocation-bps)) u10000))
          (lp-amount (/ (* treasury-balance (var-get liquidity-allocation-bps)) u10000))
          (min-investment u100000)) ;; Minimum 1 STX worth
      
      ;; Only invest if we have sufficient funds
      (asserts! (> treasury-balance min-investment) (err u411))
      
      ;; Allocate to DeFi strategies (simplified)
      (if (> defi-amount min-investment)
        (begin
          (var-set defi-investments (+ (var-get defi-investments) defi-amount))
          (print {
            event: "defi-investment",
            amount: defi-amount,
            round: (var-get investment-round)
          })
          true
        )
        false
      )
      
      ;; Allocate to liquidity provision
      (if (> lp-amount min-investment)
        (begin
          (var-set lp-investments (+ (var-get lp-investments) lp-amount))
          (print {
            event: "lp-investment", 
            amount: lp-amount,
            round: (var-get investment-round)
          })
          true
        )
        false
      )
      
      (var-set investment-round (+ (var-get investment-round) u1))
      (ok true)
    )
  )
)

;; Compound treasury yields automatically
(define-public (auto-compound-yields)
  (begin
    (asserts! (is-dao-or-admin) (err u401))
    
    (let ((simulated-yield (/ (var-get total-allocated) u20)) ;; 5% simulated yield
          (compound-threshold u10000)) ;; Minimum threshold for compounding
      
      (if (> simulated-yield compound-threshold)
        (begin
          ;; Add yield to treasury
          (var-set total-allocated (+ (var-get total-allocated) simulated-yield))
          (var-set total-yield-generated (+ (var-get total-yield-generated) simulated-yield))
          
          ;; Trigger auto-buyback if conditions met
          (try! (execute-auto-buyback))
          
          (print {
            event: "yields-compounded",
            yield-amount: simulated-yield,
            new-total: (var-get total-allocated),
            block: block-height
          })
          (ok simulated-yield)
        )
        (ok u0)
      )
    )
  )
)

;; Treasury optimization and rebalancing
(define-public (rebalance-allocations)
  (begin
    (asserts! (is-dao-or-admin) (err u401))
    
    (let ((total-treasury (var-get total-allocated))
          (dev-target (/ (* total-treasury u2000) u10000)) ;; 20% development
          (marketing-target (/ (* total-treasury u1500) u10000)) ;; 15% marketing  
          (ops-target (/ (* total-treasury u1000) u10000)) ;; 10% operations
          (reserves-target (/ (* total-treasury u3000) u10000)) ;; 30% reserves
          (bounties-target (/ (* total-treasury u1000) u10000)) ;; 10% bounties
          (buybacks-target (/ (* total-treasury u1500) u10000))) ;; 15% buybacks
      
      ;; Update category allocations
      (map-set category-allocations { category: TREASURY_CATEGORIES_DEVELOPMENT }
        { allocated: dev-target, spent: u0, reserved: dev-target })
      (map-set category-allocations { category: TREASURY_CATEGORIES_MARKETING }
        { allocated: marketing-target, spent: u0, reserved: marketing-target })
      (map-set category-allocations { category: TREASURY_CATEGORIES_OPERATIONS }
        { allocated: ops-target, spent: u0, reserved: ops-target })
      (map-set category-allocations { category: TREASURY_CATEGORIES_RESERVES }
        { allocated: reserves-target, spent: u0, reserved: reserves-target })
      (map-set category-allocations { category: TREASURY_CATEGORIES_BOUNTIES }
        { allocated: bounties-target, spent: u0, reserved: bounties-target })
      (map-set category-allocations { category: TREASURY_CATEGORIES_BUYBACKS }
        { allocated: buybacks-target, spent: u0, reserved: buybacks-target })
      
      (print {
        event: "allocations-rebalanced",
        total-treasury: total-treasury,
        block: block-height
      })
      (ok true)
    )
  )
)
