# AIP Implementation: Bounty Security Hardening

## Implementation for AIP-4: Bounty System Security Hardening

### Add to bounty-system.clar

```clarity
;; Security hardening constants
(define-constant HIGH_VALUE_THRESHOLD u5000000000) ;; 5,000 tokens
(define-constant COMPLETION_PROOF_REQUIRED u1000000000) ;; 1,000 tokens
(define-constant DISPUTE_PERIOD_BLOCKS u1008) ;; 1 week for disputes

;; Enhanced bounty structure with security features
(define-map bounty-security
  { bounty-id: uint }
  {
    completion-hash: (optional (buff 32)),
    verification-required: bool,
    verifier: (optional principal),
    dispute-deadline: uint,
    payment-locks: uint,
    milestone-proofs: (list 10 (buff 32))
  }
)

;; Payment tracking to prevent double spending
(define-map payment-tracking
  { bounty-id: uint, recipient: principal }
  {
    total-paid: uint,
    payment-count: uint,
    last-payment-block: uint,
    completed-milestones: (list 10 uint)
  }
)

;; Dispute mechanism
(define-map bounty-disputes
  { dispute-id: uint }
  {
    bounty-id: uint,
    disputer: principal,
    reason: (string-utf8 200),
    created-block: uint,
    status: uint, ;; 0=open, 1=resolved-for-disputer, 2=resolved-against-disputer
    arbitrator: (optional principal)
  }
)

(define-data-var dispute-count uint u0)

;; Create bounty with security features
(define-public (create-secure-bounty
  (title (string-utf8 100))
  (description (string-utf8 500))
  (category uint)
  (reward-amount uint)
  (deadline-blocks uint)
  (requires-verification bool))
  (let ((bounty-id (+ (var-get bounty-count) u1)))
    
    ;; Create basic bounty
    (try! (create-bounty title description category reward-amount deadline-blocks))
    
    ;; Add security features
    (map-set bounty-security { bounty-id: bounty-id }
      {
        completion-hash: none,
        verification-required: (or requires-verification (>= reward-amount HIGH_VALUE_THRESHOLD)),
        verifier: none,
        dispute-deadline: (+ block-height deadline-blocks DISPUTE_PERIOD_BLOCKS),
        payment-locks: u0,
        milestone-proofs: (list)
      })
    
    ;; Initialize payment tracking
    (map-set payment-tracking { bounty-id: bounty-id, recipient: tx-sender }
      {
        total-paid: u0,
        payment-count: u0,
        last-payment-block: u0,
        completed-milestones: (list)
      })
    
    (print { event: "secure-bounty-created", bounty-id: bounty-id, verification-required: requires-verification })
    (ok bounty-id)))

;; Submit completion with cryptotextic proof
(define-public (submit-completion-with-proof
  (bounty-id uint)
  (completion-proof (buff 32))
  (deliverables-hash (buff 32)))
  (let (
    (bounty (unwrap! (map-get? bounties { id: bounty-id }) (err u404)))
    (security (unwrap! (map-get? bounty-security { bounty-id: bounty-id }) (err u404)))
  )
    ;; Verify bounty is assigned to submitter
    (asserts! (is-eq (get assignee bounty) (some tx-sender)) (err u401))
    (asserts! (is-eq (get status bounty) BOUNTY_STATUS_IN_PROGRESS) (err u402))
    
    ;; Store completion proof
    (map-set bounty-security { bounty-id: bounty-id }
      (merge security { completion-hash: (some completion-proof) }))
    
    ;; Update bounty status
    (map-set bounties { id: bounty-id }
      (merge bounty { status: BOUNTY_STATUS_SUBMITTED }))
    
    (print { 
      event: "completion-submitted", 
      bounty-id: bounty-id, 
      submitter: tx-sender,
      proof-hash: completion-proof 
    })
    (ok true)))

;; Milestone-based payment with validation
(define-public (pay-milestone
  (bounty-id uint)
  (milestone-id uint)
  (amount uint)
  (proof-hash (buff 32)))
  (let (
    (bounty (unwrap! (map-get? bounties { id: bounty-id }) (err u404)))
    (security (unwrap! (map-get? bounty-security { bounty-id: bounty-id }) (err u404)))
    (payment-record (unwrap! (map-get? payment-tracking { bounty-id: bounty-id, recipient: (unwrap! (get assignee bounty) (err u403)) }) (err u404)))
  )
    ;; Verify authorization
    (asserts! (is-dao-or-creator tx-sender) (err u401))
    
    ;; Prevent double payment for same milestone
    (asserts! (is-none (index-of (get completed-milestones payment-record) milestone-id)) (err u411))
    
    ;; Verify total payment doesn't exceed bounty amount
    (asserts! (<= (+ (get total-paid payment-record) amount) (get reward-amount bounty)) (err u412))
    
    ;; Execute payment
    (try! (contract-call? .creator-token mint amount (unwrap! (get assignee bounty) (err u403))))
    
    ;; Update payment tracking
    (map-set payment-tracking { bounty-id: bounty-id, recipient: (unwrap! (get assignee bounty) (err u403)) }
      (merge payment-record {
        total-paid: (+ (get total-paid payment-record) amount),
        payment-count: (+ (get payment-count payment-record) u1),
        last-payment-block: block-height,
        completed-milestones: (unwrap! (as-max-len? (append (get completed-milestones payment-record) milestone-id) u10) (err u413))
      }))
    
    ;; Update security proofs
    (map-set bounty-security { bounty-id: bounty-id }
      (merge security {
        milestone-proofs: (unwrap! (as-max-len? (append (get milestone-proofs security) proof-hash) u10) (err u413))
      }))
    
    (print { 
      event: "milestone-paid", 
      bounty-id: bounty-id, 
      milestone-id: milestone-id, 
      amount: amount,
      proof-hash: proof-hash 
    })
    (ok true)))

;; Create dispute
(define-public (create-dispute
  (bounty-id uint)
  (reason (string-utf8 200)))
  (let ((dispute-id (+ (var-get dispute-count) u1)))
    
    ;; Verify bounty exists and is in valid state for dispute
    (asserts! (is-some (map-get? bounties { id: bounty-id })) (err u404))
    
    (map-set bounty-disputes { dispute-id: dispute-id }
      {
        bounty-id: bounty-id,
        disputer: tx-sender,
        reason: reason,
        created-block: block-height,
        status: u0, ;; open
        arbitrator: none
      })
    
    (var-set dispute-count dispute-id)
    
    (print { event: "dispute-created", dispute-id: dispute-id, bounty-id: bounty-id })
    (ok dispute-id)))

;; Resolve dispute (DAO governance)
(define-public (resolve-dispute
  (dispute-id uint)
  (resolution uint)) ;; 1=for-disputer, 2=against-disputer
  (let ((dispute (unwrap! (map-get? bounty-disputes { dispute-id: dispute-id }) (err u404))))
    
    ;; Only DAO can resolve disputes
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u401))
    (asserts! (is-eq (get status dispute) u0) (err u402)) ;; must be open
    
    (map-set bounty-disputes { dispute-id: dispute-id }
      (merge dispute { 
        status: resolution,
        arbitrator: (some tx-sender)
      }))
    
    (print { event: "dispute-resolved", dispute-id: dispute-id, resolution: resolution })
    (ok true)))

;; Read-only functions for security verification
(define-read-only (get-bounty-security (bounty-id uint))
  (map-get? bounty-security { bounty-id: bounty-id }))

(define-read-only (get-payment-history (bounty-id uint) (recipient principal))
  (map-get? payment-tracking { bounty-id: bounty-id, recipient: recipient }))

(define-read-only (verify-completion-proof (bounty-id uint) (provided-proof (buff 32)))
  (match (map-get? bounty-security { bounty-id: bounty-id })
    security (match (get completion-hash security)
      stored-hash (is-eq stored-hash provided-proof)
      false)
    false))

;; Helper functions
(define-read-only (is-dao-or-creator (caller principal))
  (or (is-eq caller (var-get dao-governance))
      (is-eq caller (var-get treasury))))

;; Error codes for security features
;; u411: milestone-already-paid
;; u412: payment-exceeds-bounty-amount
;; u413: too-many-milestones
```
