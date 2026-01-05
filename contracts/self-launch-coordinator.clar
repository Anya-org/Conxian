;; self-launch-coordinator.clar
;; Conxian SAB: Self-Launch Coordinator
;; Manages community-funded protocol launch

(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_INSUFFICIENT_FUNDS (err u4002))
(define-constant ERR_INVALID_AMOUNT (err u4003))
(define-constant FOUNDER_SHARE u5000) ;; 50% for founder
(define-constant COMMUNITY_SHARE u5000) ;; 50% for community

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var total-contributions uint u0)
(define-data-var founder-claimable uint u0)
(define-data-var community-fund uint u0)

;; Contribution tracking
(define-map contributions
  principal
  {
    amount: uint,
    contribution-block: uint,
    rewards-earned: uint
  }
)

;; Public functions
(define-public (contribute-funding)
  (begin
    (let ((amount (stx-get-balance tx-sender)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
      (match (stx-transfer? amount tx-sender (as-contract tx-sender))
        transfer-success
        (begin
          (map-set contributions tx-sender {
            amount: amount,
            contribution-block: block-height,
            rewards-earned: u0
          })
          (let ((founder-portion (/ (* amount FOUNDER_SHARE) 10000))
                (community-portion (/ (* amount COMMUNITY_SHARE) 10000)))
            (var-set total-contributions (+ (var-get total-contributions) amount))
            (var-set founder-claimable (+ (var-get founder-claimable) founder-portion))
            (var-set community-fund (+ (var-get community-fund) community-portion))
          )
          (ok amount)
        )
        (err ERR_INSUFFICIENT_FUNDS)
      )
    )
  )
)

(define-public (claim-launch-funds)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((claimable (var-get founder-claimable)))
      (asserts! (> claimable u0) ERR_INVALID_AMOUNT)
      (var-set founder-claimable u0)
      (as-contract 
        (stx-transfer? claimable tx-sender tx-sender)
      )
      (ok claimable)
    )
  )
)

(define-public (distribute-community-rewards (user principal) (reward-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (<= reward-amount (var-get community-fund)) ERR_INVALID_AMOUNT)
    (var-set community-fund (- (var-get community-fund) reward-amount))
    (as-contract 
      (stx-transfer? reward-amount tx-sender user)
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-contribution (user principal))
  (match (map-get? contributions user)
    contribution (ok contribution)
    (err u0)
  )
)

(define-read-only (get-total-contributions)
  (ok (var-get total-contributions))
)

(define-read-only (get-founder-claimable)
  (ok (var-get founder-claimable))
)

(define-read-only (get-community-fund)
  (ok (var-get community-fund))
)

(define-read-only (get-launch-status)
  (ok {
    total-contributions: (var-get total-contributions),
    founder-claimable: (var-get founder-claimable),
    community-fund: (var-get community-fund),
    is-complete: (> (var-get total-contributions) u1000000000000) ;; 1000 STX threshold
  })
)
