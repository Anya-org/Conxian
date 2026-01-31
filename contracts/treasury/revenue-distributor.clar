;; revenue-distributor.clar
;; Distributes protocol revenue (60/20/20 split)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; State
(define-data-var staking-vault principal .cxd-staking)
(define-data-var operational-treasury principal .operational-treasury)
(define-data-var insurance-fund principal .conxian-insurance-fund)

;; Public Functions

(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (let (
    (policy (unwrap-panic (contract-call? .allocation-policy get-allocation-percentages)))
    (staking-amt (/ (* amount (get staking policy)) u10000))
    (dev-amt (/ (* amount (get dev policy)) u10000))
    (ins-amt (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (try! (as-contract (contract-call? token transfer staking-amt tx-sender (var-get staking-vault) none)))
      (try! (as-contract (contract-call? token transfer dev-amt tx-sender (var-get operational-treasury) none)))
      (try! (as-contract (contract-call? token transfer ins-amt tx-sender (var-get insurance-fund) none)))
      (ok true)
    )
  )
)

(define-public (distribute-stx (amount uint))
  (let (
    (policy (unwrap-panic (contract-call? .allocation-policy get-allocation-percentages)))
    (staking-amt (/ (* amount (get staking policy)) u10000))
    (dev-amt (/ (* amount (get dev policy)) u10000))
    (ins-amt (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (try! (as-contract (stx-transfer? staking-amt tx-sender (var-get staking-vault))))
      (try! (as-contract (stx-transfer? dev-amt tx-sender (var-get operational-treasury))))
      (try! (as-contract (stx-transfer? ins-amt tx-sender (var-get insurance-fund))))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-operational-treasury)
  (var-get operational-treasury)
)
