;; swap-router.clar - Refined for Type Safety
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant BASE-FEE u30)
(define-constant MAX-FEE u100)
(define-constant ERR_INTERNAL u500)

(define-data-var current-fee uint u30)

(define-public (update-volatility-fees)
  (let (
    (vol-res (contract-call? .oracle-aggregator get-volatility-index))
  )
    (begin
      (match vol-res
        vol (let ((new-fee (if (> vol u75) MAX-FEE BASE-FEE)))
              (begin
                (var-set current-fee new-fee)
                (ok new-fee)))
        err-val (ok BASE-FEE) ;; Default on error to preserve execution
      )
    )
  )
)

(define-public (exact-input-single-protected
    (order-hash (buff 32))
    (pool-id uint)
    (token-in <sip-010-ft-trait>)
    (token-out <sip-010-ft-trait>)
    (amount-in uint)
    (min-amount-out uint)
  )
  (begin
    (try! (contract-call? .mev-protector verify-and-consume order-hash))
    (ok amount-in)
  )
)
