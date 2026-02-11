;; agent-treasury.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; COMPATIBILITY MODE

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)

;; State
(define-data-var last-fiscal-height uint u0)
(define-data-var contract-owner principal tx-sender)

;; @desc Run the fiscal strategy based on system risk.
(define-public (run-fiscal-strategy)
  (let ((btc-height burn-block-height))
    (if (<= btc-height (var-get last-fiscal-height))
      (ok false)
      (let (
        (gcr (unwrap-panic (contract-call? .agent-risk get-gcr)))
      )
        (begin
          (if (< gcr u110)
            (try! (contract-call? .cxd-treasury rebalance u0 u0 u10000))
            (if (< gcr u150)
              (try! (contract-call? .cxd-treasury rebalance u6000 u2000 u2000))
              (try! (contract-call? .cxd-treasury rebalance u8000 u1000 u1000))
            )
          )
          (var-set last-fiscal-height btc-height)
          (ok true)
        )
      )
    )
  )
)

(define-public (apply-fiscal-dam)
  (run-fiscal-strategy)
)

(define-public (set-regulatory-adapter-contract (new-adapter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

;; @desc Distribute protocol revenue. (Enhanced for Production Vision)
(define-public (distribute (token-trait <sip-010-ft-trait>) (amount uint) (recipient principal))
  (let (
    (policy (unwrap-panic (contract-call? .cxd-treasury get-allocation-percentages)))
    (staking-share (get staking policy))
    (staking-amt (/ (* amount staking-share) u10000))
    (dev-amt (/ (* amount (get dev policy)) u10000))
    (ins-amt (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
      (try! (contract-call? .revenue-distributor distribute-token token-trait amount))
      (print {
        event: "revenue-distributed",
        token: (contract-of token-trait),
        total-amount: amount,
        staking-amount: staking-amt,
        dev-fund-amount: dev-amt,
        insurance-fund-amount: ins-amt
      })
      (ok true)
    )
  )
)
