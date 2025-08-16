# AIP Implementation: Vault Precision Enhancements

## Implementation for AIP-5: Vault Precision and Withdrawal Security

### Add to vault.clar

```clarity
;; Precision enhancement constants
(define-constant PRECISION_MULTIPLIER u1000000) ;; 6 decimal places for precision
(define-constant MINIMUM_DEPOSIT u1000) ;; Prevent dust deposits
(define-constant MINIMUM_WITHDRAWAL u1000) ;; Prevent dust withdrawals
(define-constant MAX_WITHDRAWAL_QUEUE_SIZE u100)

;; High-precision share calculations
(define-data-var precision-enabled bool true)
(define-data-var dust-collection uint u0)

;; Withdrawal queue for large redemptions
(define-map withdrawal-queue
  { queue-id: uint }
  {
    user: principal,
    shares: uint,
    requested-block: uint,
    processed: bool,
    priority-score: uint
  }
)

(define-data-var queue-count uint u0)
(define-data-var queue-processing-enabled bool true)

;; Enhanced share calculation with precision
(define-read-only (calculate-shares-precise (amount uint))
  (if (var-get precision-enabled)
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      (* amount PRECISION_MULTIPLIER) ;; First deposit
      (/ (* amount total-sh PRECISION_MULTIPLIER) total-bal)))
    ;; Fallback to original calculation
    (calculate-shares amount)))

;; Enhanced balance calculation with precision
(define-read-only (calculate-balance-precise (shares uint))
  (if (var-get precision-enabled)
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      u0
      (/ (* shares total-bal) (total-sh PRECISION_MULTIPLIER))))
    ;; Fallback to original calculation
    (calculate-balance shares)))

;; Queue withdrawal for large amounts
(define-public (queue-withdrawal (shares uint))
  (let (
    (user-shares (get-user-shares tx-sender))
    (queue-id (+ (var-get queue-count) u1))
    (withdrawal-amount (calculate-balance-precise shares))
  )
    ;; Verify user has enough shares
    (asserts! (<= shares user-shares) (err u105))
    (asserts! (>= shares MINIMUM_WITHDRAWAL) (err u414))
    
    ;; Check if large withdrawal (>10% of total balance)
    (if (> withdrawal-amount (/ (var-get total-balance) u10))
      (begin
        ;; Add to queue for large withdrawals
        (map-set withdrawal-queue { queue-id: queue-id }
          {
            user: tx-sender,
            shares: shares,
            requested-block: block-height,
            processed: false,
            priority-score: (calculate-priority-score tx-sender shares)
          })
        
        (var-set queue-count queue-id)
        
        ;; Lock shares temporarily
        (map-set shares { user: tx-sender }
          { amount: (- user-shares shares) })
        
        (print { 
          event: "withdrawal-queued", 
          user: tx-sender, 
          queue-id: queue-id, 
          shares: shares 
        })
        (ok queue-id))
      ;; Process small withdrawals immediately
      (withdraw-precise shares))))

;; Enhanced withdrawal with precision
(define-public (withdraw-precise (shares uint))
  (let (
    (user-shares (get-user-shares tx-sender))
    (withdrawal-amount (calculate-balance-precise shares))
    (fee-amount (calculate-withdraw-fee withdrawal-amount))
    (net-withdrawal (- withdrawal-amount fee-amount))
  )
    ;; Verify contract not paused
    (asserts! (is-eq (var-get paused) false) (err u103))
    
    ;; Verify sufficient shares and minimum withdrawal
    (asserts! (<= shares user-shares) (err u105))
    (asserts! (>= shares MINIMUM_WITHDRAWAL) (err u414))
    
    ;; Verify sufficient balance for withdrawal
    (asserts! (<= net-withdrawal (var-get total-balance)) (err u106))
    
    ;; Handle precision dust
    (let ((dust-amount (- withdrawal-amount (* (/ withdrawal-amount u1000) u1000))))
      (if (> dust-amount u0)
        (var-set dust-collection (+ (var-get dust-collection) dust-amount))
        true))
    
    ;; Execute withdrawal
    (try! (as-contract (contract-call? (var-get token) transfer net-withdrawal tx-sender tx-sender none)))
    
    ;; Update state
    (map-set shares { user: tx-sender }
      { amount: (- user-shares shares) })
    
    (var-set total-shares (- (var-get total-shares) shares))
    (var-set total-balance (- (var-get total-balance) withdrawal-amount))
    
    ;; Process fee
    (process-withdraw-fee fee-amount)
    
    (print { 
      event: "withdrawal-precise", 
      user: tx-sender, 
      shares: shares, 
      amount: net-withdrawal,
      precision-dust: dust-amount
    })
    (ok net-withdrawal)))

;; Process queued withdrawals
(define-public (process-withdrawal-queue (queue-id uint))
  (let ((queue-item (unwrap! (map-get? withdrawal-queue { queue-id: queue-id }) (err u404))))
    
    ;; Verify queue processing is enabled
    (asserts! (var-get queue-processing-enabled) (err u415))
    (asserts! (not (get processed queue-item)) (err u416))
    
    ;; Verify sufficient time has passed (24 hours)
    (asserts! (>= block-height (+ (get requested-block queue-item) u144)) (err u417))
    
    ;; Process the withdrawal
    (try! (withdraw-precise (get shares queue-item)))
    
    ;; Mark as processed
    (map-set withdrawal-queue { queue-id: queue-id }
      (merge queue-item { processed: true }))
    
    (print { event: "queue-withdrawal-processed", queue-id: queue-id })
    (ok true)))

;; Calculate priority score for withdrawal queue
(define-read-only (calculate-priority-score (user principal) (shares uint))
  (let (
    (user-balance (get-user-balance user))
    (user-tenure (get-user-tenure user))
  )
  ;; Higher score = higher priority
  ;; Based on: user tenure + withdrawal size
  (+ user-tenure (/ shares u1000))))

;; Enhanced deposit with precision and dust protection
(define-public (deposit-precise (amount uint))
  (begin
    ;; Verify minimum deposit
    (asserts! (>= amount MINIMUM_DEPOSIT) (err u418))
    
    ;; Verify contract not paused
    (asserts! (is-eq (var-get paused) false) (err u103))
    
    ;; Calculate shares with precision
    (let (
      (shares-to-mint (calculate-shares-precise amount))
      (fee-amount (calculate-deposit-fee amount))
      (net-deposit (- amount fee-amount))
    )
      ;; Transfer tokens
      (try! (contract-call? (var-get token) transfer amount tx-sender (as-contract tx-sender) none))
      
      ;; Update user shares
      (map-set shares { user: tx-sender }
        { amount: (+ (get-user-shares tx-sender) shares-to-mint) })
      
      ;; Update totals
      (var-set total-shares (+ (var-get total-shares) shares-to-mint))
      (var-set total-balance (+ (var-get total-balance) net-deposit))
      
      ;; Process fee
      (process-deposit-fee fee-amount)
      
      (print { 
        event: "deposit-precise", 
        user: tx-sender, 
        amount: amount, 
        shares: shares-to-mint,
        net-deposit: net-deposit
      })
      (ok shares-to-mint))))

;; Collect accumulated dust
(define-public (collect-dust)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u102))
    
    (let ((dust-amount (var-get dust-collection)))
      (if (> dust-amount u0)
        (begin
          (var-set dust-collection u0)
          (var-set protocol-reserve (+ (var-get protocol-reserve) dust-amount))
          (print { event: "dust-collected", amount: dust-amount })
          (ok dust-amount))
        (ok u0)))))

;; Get user tenure (blocks since first deposit)
(define-read-only (get-user-tenure (user principal))
  ;; Simplified - in production would track first deposit block
  (- block-height u1000)) ;; Placeholder

;; Read-only functions for precision data
(define-read-only (get-precision-enabled)
  (var-get precision-enabled))

(define-read-only (get-dust-collection)
  (var-get dust-collection))

(define-read-only (get-queue-item (queue-id uint))
  (map-get? withdrawal-queue { queue-id: queue-id }))

(define-read-only (get-queue-count)
  (var-get queue-count))

;; Admin functions for precision control
(define-public (set-precision-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u102))
    (var-set precision-enabled enabled)
    (print { event: "precision-toggled", enabled: enabled })
    (ok true)))

(define-public (set-queue-processing (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u102))
    (var-set queue-processing-enabled enabled)
    (print { event: "queue-processing-toggled", enabled: enabled })
    (ok true)))

;; Error codes for precision features
;; u414: below-minimum-withdrawal
;; u415: queue-processing-disabled
;; u416: already-processed
;; u417: insufficient-queue-time
;; u418: below-minimum-deposit
```
