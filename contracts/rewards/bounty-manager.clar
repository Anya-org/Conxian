;; bounty-manager.clar
;; Automated Bounty Fulfillment & Proof-of-Work Payout System
;; Authorized by Governor or Autonomous Nexus Agents

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_BOUNTY_NOT_FOUND u1001)
(define-constant ERR_ALREADY_CLAIMED u1002)
(define-constant ERR_NOT_ELIGIBLE u1003)

;; Bounties Map
(define-map bounties
  { bounty-id: uint }
  {
    beneficiary: (optional principal),
    amount: uint,
    token: principal,
    completed: bool,
    claimed: bool,
    description: (string-ascii 256)
  }
)

(define-data-var bounty-nonce uint u0)

;; --- Authorization ---

(define-read-only (is-authorized-agent (agent principal))
  (or 
    (is-eq agent (unwrap-panic (contract-call? .conxian-protocol get-admin)))
    (is-eq agent (unwrap-panic (contract-call? .conxian-protocol get-contract-address "conxian-nexus")))
  )
)

;; --- Public Functions ---

(define-public (create-bounty (amount uint) (token principal) (description (string-ascii 256)))
  (let ((id (+ (var-get bounty-nonce) u1)))
    (begin
      (asserts! (is-authorized-agent tx-sender) (err ERR_UNAUTHORIZED))
      (map-set bounties { bounty-id: id } {
        beneficiary: none,
        amount: amount,
        token: token,
        completed: false,
        claimed: false,
        description: description
      })
      (var-set bounty-nonce id)
      (ok id)
    )
  )
)

(define-public (attest-completion (bounty-id uint) (beneficiary principal))
  (let ((bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) (err ERR_BOUNTY_NOT_FOUND))))
    (begin
      (asserts! (is-authorized-agent tx-sender) (err ERR_UNAUTHORIZED))
      (asserts! (not (get completed bounty)) (err ERR_ALREADY_CLAIMED))
      (map-set bounties { bounty-id: bounty-id } 
        (merge bounty { completed: true, beneficiary: (some beneficiary) })
      )
      (ok true)
    )
  )
)

(define-public (claim-bounty (bounty-id uint) (token-trait <sip-010-ft-trait>))
  (let (
      (bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) (err ERR_BOUNTY_NOT_FOUND)))
      (beneficiary (unwrap! (get beneficiary bounty) (err ERR_NOT_ELIGIBLE)))
    )
    (begin
      (asserts! (is-eq (get token bounty) (contract-of token-trait)) (err ERR_NOT_ELIGIBLE))
      (asserts! (get completed bounty) (err ERR_NOT_ELIGIBLE))
      (asserts! (not (get claimed bounty)) (err ERR_ALREADY_CLAIMED))
      (asserts! (is-eq tx-sender beneficiary) (err ERR_UNAUTHORIZED))
      
      ;; Execute payout from bounty-vault
      (try! (contract-call? .revenue-distributor distribute-token token-trait (get amount bounty)))
      
      (map-set bounties { bounty-id: bounty-id } 
        (merge bounty { claimed: true })
      )
      (print { event: "bounty-claimed", id: bounty-id, beneficiary: beneficiary })
      (ok true)
    )
  )
)

;; --- Read Only ---

(define-read-only (get-bounty (id uint))
  (map-get? bounties { bounty-id: id })
)
