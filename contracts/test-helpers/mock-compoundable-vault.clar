;; mock-compoundable-vault.clar
;; Simnet-only compoundable vault used by auto-compounder tests.

(impl-trait .compoundable-vault-trait.compoundable-vault-trait)

(define-constant ERR_COMPOUND_FAILED (err u7000))

(define-data-var pending-rewards uint u0)
(define-data-var compound-output uint u0)
(define-data-var compound-fails bool false)
(define-data-var last-destination principal tx-sender)
(define-data-var last-min-output uint u0)
(define-data-var compound-count uint u0)

(define-public (set-pending-rewards (amount uint))
  (begin
    (var-set pending-rewards amount)
    (ok true)
  )
)

(define-public (set-compound-output (amount uint))
  (begin
    (var-set compound-output amount)
    (ok true)
  )
)

(define-public (set-compound-failure (should-fail bool))
  (begin
    (var-set compound-fails should-fail)
    (ok true)
  )
)

(define-read-only (get-pending-rewards)
  (ok (var-get pending-rewards))
)

(define-public (compound (min-output uint) (destination principal))
  (if (var-get compound-fails)
    ERR_COMPOUND_FAILED
    (begin
      (var-set pending-rewards u0)
      (var-set last-destination destination)
      (var-set last-min-output min-output)
      (var-set compound-count (+ (var-get compound-count) u1))
      (ok (var-get compound-output))
    )
  )
)

(define-read-only (get-last-destination)
  (var-get last-destination)
)

(define-read-only (get-last-min-output)
  (var-get last-min-output)
)

(define-read-only (get-compound-count)
  (var-get compound-count)
)
