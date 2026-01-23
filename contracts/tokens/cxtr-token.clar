;; CXTR Token - Conxian Treasury Token
;; SIP-010 Fungible Token for treasury operations

;; Import SIP-010 trait
(impl-trait .sip-standards.sip-010-ft-trait)

;; Token metadata
(define-constant TOKEN_NAME "Conxian Treasury Token")
(define-constant TOKEN_SYMBOL "CXTR")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_URI "https://conxian.io/metadata/cxtr.json")

;; Token state
(define-data-var total-supply uint u0)
(define-map balances { account: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })
(define-map treasury-allocations { category: (string-ascii 32) } { amount: uint, percentage: uint })

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var admin principal CONTRACT_OWNER)
(define-data-var treasury-manager principal CONTRACT_OWNER)

;; Treasury parameters
(define-constant TOTAL_ALLOCATION_PERCENTAGE u10000) ;; 100%
(define-constant MIN_ALLOCATION_PERCENTAGE u100) ;; 1%
(define-constant MAX_ALLOCATION_PERCENTAGE u5000) ;; 50%

;; Events
(define-event (transfer-mint (sender principal) (recipient principal) (amount uint)))
(define-event (transfer-burn (sender principal) (amount uint)))
(define-event (transfer (sender principal) (recipient principal) (amount uint)))
(define-event (approve (owner principal) (spender principal) (amount uint)))
(define-event (treasury-allocated (category (string-ascii 32)) (amount uint) (percentage uint)))
(define-event (treasury-distributed (category (string-ascii 32)) (recipient principal) (amount uint)))
(define-event (treasury-rebalanced (category (string-ascii 32)) (old-percentage uint) (new-percentage uint)))

;; Read-only functions

(define-read-only (get-name)
  TOKEN_NAME)

(define-read-only (get-symbol)
  TOKEN_SYMBOL)

(define-read-only (get-decimals)
  TOKEN_DECIMALS)

(define-read-only (get-token-uri)
  TOKEN_URI)

(define-read-only (get-total-supply)
  (var-get total-supply))

(define-read-only (get-balance (account principal))
  (default-to u0 (map-get? balances { account: account })))

(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances { owner: owner, spender: spender })))

(define-read-only (get-token-id)
  (as-contract tx-sender))

;; Treasury-specific read-only functions

(define-read-only (get-allocation (category (string-ascii 32)))
  (map-get? treasury-allocations { category: category }))

(define-read-only (get-allocation-amount (category (string-ascii 32)))
  (match (get-allocation category)
    allocation (ok (get allocation amount))
    none (ok u0)
  )
)

(define-read-only (get-allocation-percentage (category (string-ascii 32)))
  (match (get-allocation category)
    allocation (ok (get allocation percentage))
    none (ok u0)
  )
)

(define-read-only (get-total-allocated-percentage)
  (fold (map-keys treasury-allocations) u0
    (lambda ((total uint) (category (string-ascii 32)))
      (+ total (unwrap-panic (get-allocation-percentage category))))
  )
)

(define-read-only (get-available-percentage)
  (- TOTAL_ALLOCATION_PERCENTAGE (get-total-allocated-percentage))
)

(define-read-only (get-distribution-amount (category (string-ascii 32)))
  (let ((percentage (unwrap-panic (get-allocation-percentage category)))
        (total-supply (var-get total-supply)))
    (/ (* total-supply percentage) TOTAL_ALLOCATION_PERCENTAGE)
  )
)

(define-read-only (is-treasury-manager (account principal))
  (is-eq account (var-get treasury-manager))
)

;; Public functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 5001))
    (asserts! (>= (get-balance from) amount) (err 5002))
    
    ;; Update balances
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    (map-set balances { account: to } { amount: (+ (get-balance to) amount) })
    
    ;; Emit event
    (emit-event (transfer from to amount))
    
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Only contract owner can mint
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 5003))
    (asserts! (> amount u0) (err 5004))
    
    ;; Update total supply and recipient balance
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set balances { account: recipient } { amount: (+ (get-balance recipient) amount) })
    
    ;; Emit event
    (emit-event (transfer-mint tx-sender recipient amount))
    
    (ok true)
  )
)

(define-public (burn (amount uint) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 5005))
    (asserts! (>= (get-balance tx-sender) amount) (err 5006))
    
    ;; Update total supply and sender balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: tx-sender } { amount: (- (get-balance tx-sender) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn tx-sender amount))
    
    (ok true)
  )
)

(define-public (approve (amount uint) (spender principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) (err 5007))
    
    ;; Set allowance
    (map-set allowances { owner: tx-sender, spender: spender } { amount: amount })
    
    ;; Emit event
  )
)

;; Treasury management functions

(define-public (allocate-to-category (category (string-ascii 32)) (percentage uint))
  (begin
    ;; Only treasury manager can allocate
    (asserts! (is-eq tx-sender (var-get treasury-manager)) (err 5011))
    (asserts! (>= percentage MIN_ALLOCATION_PERCENTAGE) (err 5012))
    (asserts! (<= percentage MAX_ALLOCATION_PERCENTAGE) (err 5013))
    
    ;; Check if allocation would exceed total
    (let ((current-percentage (unwrap-panic (get-allocation-percentage category)))
          (total-allocated (get-total-allocated-percentage)))
      (asserts! (<= (+ (- total-allocated current-percentage) percentage) TOTAL_ALLOCATION_PERCENTAGE) (err 5014))
      
      ;; Update allocation
      (map-set treasury-allocations { category: category } {
        amount: (/ (* (var-get total-supply) percentage) TOTAL_ALLOCATION_PERCENTAGE),
        percentage: percentage
      })
      
      ;; Emit event
      (emit-event (treasury-allocated category 
        (/ (* (var-get total-supply) percentage) TOTAL_ALLOCATION_PERCENTAGE) 
        percentage)
      
      (ok true)
    )
  )
)

(define-public (distribute-from-category (category (string-ascii 32)) (recipient principal) (amount uint))
  (begin
    ;; Only treasury manager can distribute
    (asserts! (is-eq tx-sender (var-get treasury-manager)) (err 5015))
    (asserts! (> amount u0) (err 5016))
    
    ;; Check allocation exists
    (match (get-allocation category)
      allocation
        (begin
          (asserts! (>= (get allocation amount) amount) (err 5017))
          
          ;; Update allocation amount
          (map-set treasury-allocations { category: category } {
            amount: (- (get allocation amount) amount),
            percentage: (get allocation percentage)
          })
          
          ;; Transfer to recipient
          (map-set balances { account: recipient } { amount: (+ (get-balance recipient) amount) })
          
          ;; Emit event
          (emit-event (treasury-distributed category recipient amount))
          
          (ok true)
        )
      none (err 5018) ;; No allocation exists
    )
  )
)

(define-public (rebalance-category (category (string-ascii 32)) (new-percentage uint))
  (begin
    ;; Only treasury manager can rebalance
    (asserts! (is-eq tx-sender (var-get treasury-manager)) (err 5019))
    (asserts! (>= new-percentage MIN_ALLOCATION_PERCENTAGE) (err 5020))
    (asserts! (<= new-percentage MAX_ALLOCATION_PERCENTAGE) (err 5021))
    
    ;; Check allocation exists
    (match (get-allocation category)
      allocation
        (begin
          (let ((old-percentage (get allocation percentage))
                (total-allocated (get-total-allocated-percentage)))
            
            ;; Check if rebalancing would exceed total
            (asserts! (<= (+ (- total-allocated old-percentage) new-percentage) TOTAL_ALLOCATION_PERCENTAGE) (err 5022))
            
            ;; Update allocation
            (map-set treasury-allocations { category: category } {
              amount: (/ (* (var-get total-supply) new-percentage) TOTAL_ALLOCATION_PERCENTAGE),
              percentage: new-percentage
            })
            
            ;; Emit event
            (emit-event (treasury-rebalanced category old-percentage new-percentage))
            
            (ok true)
          )
        )
      none (err 5023) ;; No allocation exists
    )
  )
)

(define-public (auto-distribute-category (category (string-ascii 32)))
  (begin
    ;; Only treasury manager can auto-distribute
    (asserts! (is-eq tx-sender (var-get treasury-manager)) (err 5024))
    
    ;; Get allocation
    (match (get-allocation category)
      allocation
        (begin
          (let ((amount-to-distribute (get allocation amount)))
            
            ;; This would distribute to predefined recipients based on category
            ;; For now, just emit event
            (emit-event (treasury-distributed category tx-sender amount-to-distribute))
            
            (ok amount-to-distribute)
          )
        )
      none (err 5025) ;; No allocation exists
    )
  )
)

;; Admin functions

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 5026))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-treasury-manager (new-manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 5027))
    (var-set treasury-manager new-manager)
    (ok true)
  )
)

(define-public (emergency-burn (amount uint) (from principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 5028))
    (asserts! (> amount u0) (err 5029))
    (asserts! (>= (get-balance from) amount) (err 5030))
    
    ;; Update total supply and balance
    (var-set total-supply (- (var-get total-supply) amount))
    (map-set balances { account: from } { amount: (- (get-balance from) amount) })
    
    ;; Emit event
    (emit-event (transfer-burn from amount))
    
    (ok true)
  )
)

(define-public (emergency-reallocate (from-category (string-ascii 32)) (to-category (string-ascii 32)) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err 5031))
    (asserts! (> amount u0) (err 5032))
    
    ;; Check from allocation exists and has sufficient amount
    (match (get-allocation from-category)
      from-allocation
        (begin
          (asserts! (>= (get from-allocation amount) amount) (err 5033))
          
          ;; Update from allocation
          (map-set treasury-allocations { category: from-category } {
            amount: (- (get from-allocation amount) amount),
            percentage: (get from-allocation percentage)
          })
          
          ;; Update or create to allocation
          (map-set treasury-allocations { category: to-category } {
            amount: (+ (unwrap-panic (get-allocation-amount to-category)) amount),
            percentage: (get from-allocation percentage) ;; Keep same percentage for simplicity
          })
          
          (ok true)
        )
      none (err 5034) ;; No from allocation exists
    )
  )
)
