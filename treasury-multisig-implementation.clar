# AIP Implementation: Multi-Sig Treasury Controls

## Implementation for AIP-3: Treasury Multi-Sig Security Enhancement

### Add to treasury.clar

```clarity
;; Multi-sig configuration
(define-constant MULTISIG_THRESHOLD u3) ;; 3 of 5 required
(define-data-var multisig-members (list 5 principal) (list tx-sender tx-sender tx-sender tx-sender tx-sender))

;; Spending proposal structure
(define-map spending-proposals
  { proposal-id: uint }
  {
    recipient: principal,
    amount: uint,
    category: uint,
    purpose: (string-utf8 200),
    creator: principal,
    created-block: uint,
    deadline-block: uint,
    approvals: (list 5 principal),
    executed: bool
  }
)

(define-data-var proposal-count uint u0)

;; Multi-sig spending thresholds
(define-constant LARGE_SPENDING_THRESHOLD u50000000000) ;; 50,000 STX (in microSTX)
(define-constant MEDIUM_SPENDING_THRESHOLD u10000000000) ;; 10,000 STX (in microSTX)
(define-constant SMALL_SPENDING_THRESHOLD u1000000000) ;; 1,000 STX (in microSTX)

;; Create spending proposal
(define-public (propose-spending 
  (recipient principal) 
  (amount uint) 
  (category uint) 
  (purpose (string-utf8 200)))
  (let ((proposal-id (+ (var-get proposal-count) u1)))
    (asserts! (is-member tx-sender) (err u401))
    (asserts! (> amount u0) (err u400))
    
    (map-set spending-proposals { proposal-id: proposal-id }
      {
        recipient: recipient,
        amount: amount,
        category: category,
        purpose: purpose,
        creator: tx-sender,
        created-block: block-height,
        deadline-block: (+ block-height u1008), ;; 1 week deadline
        approvals: (list tx-sender),
        executed: false
      })
    
    (var-set proposal-count proposal-id)
    (print { event: "proposal-created", proposal-id: proposal-id, amount: amount })
    (ok proposal-id)))

;; Approve spending proposal
(define-public (approve-spending (proposal-id uint))
  (let ((proposal (unwrap! (map-get? spending-proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (is-member tx-sender) (err u401))
    (asserts! (not (get executed proposal)) (err u403))
    (asserts! (<= block-height (get deadline-block proposal)) (err u402))
    (asserts! (not (is-some (index-of (get approvals proposal) tx-sender))) (err u405))
    
    (let ((new-approvals (unwrap! (as-max-len? (append (get approvals proposal) tx-sender) u5) (err u406))))
      (map-set spending-proposals { proposal-id: proposal-id }
        (merge proposal { approvals: new-approvals }))
      
      (print { event: "proposal-approved", proposal-id: proposal-id, approver: tx-sender })
      (ok true))))

;; Execute approved spending
(define-public (execute-spending (proposal-id uint))
  (let ((proposal (unwrap! (map-get? spending-proposals { proposal-id: proposal-id }) (err u404))))
    (asserts! (not (get executed proposal)) (err u403))
    (asserts! (>= (len (get approvals proposal)) MULTISIG_THRESHOLD) (err u407))
    
    ;; Check time delay for large amounts
    (if (>= (get amount proposal) LARGE_SPENDING_THRESHOLD)
      (asserts! (>= block-height (+ (get created-block proposal) u288)) (err u408)) ;; 48 hour delay
      true)
    
    ;; Execute the spending
    (try! (stx-transfer? (get amount proposal) tx-sender (get recipient proposal)))
    
    (map-set spending-proposals { proposal-id: proposal-id }
      (merge proposal { executed: true }))
    
    (print { event: "proposal-executed", proposal-id: proposal-id, amount: (get amount proposal) })
    (ok true)))

;; Helper functions
(define-read-only (is-member (member principal))
  (is-some (index-of (var-get multisig-members) member)))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? spending-proposals { proposal-id: proposal-id }))

;; Error codes
;; u400: invalid-amount
;; u401: not-authorized
;; u402: proposal-expired
;; u403: already-executed
;; u404: proposal-not-found
;; u405: already-approved
;; u406: too-many-approvals
;; u407: insufficient-approvals
;; u408: time-delay-not-met
```
