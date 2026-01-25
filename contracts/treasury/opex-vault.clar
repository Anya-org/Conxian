;; opex-vault.clar
;; Operational Expenses Vault
;; Managed by multi-sig or governance for ongoing costs

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var allowance-limit uint u1000000) ;; Daily spending limit
(define-data-var last-spend-block uint u0)
(define-data-var daily-spend uint u0)

(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var conxian-access-contract principal .conxian-access)
(define-data-var nakamoto-constants-contract principal .nakamoto-constants)

(define-constant ROLE_OPERATOR u4)


(define-public (withdraw-opex
    (token <sip-010-trait>)
    (amount uint)
    (recipient principal)
  )
  (begin
      ;; ROLE_OPERATOR ERR_UN
    (asserts!
      (is-ok
        (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)
      )
      ERR_UNAUTHORIZED
    )
    (asserts!
      (contract-call? .conxian-access has-role tx-sender
        ROLE_OPERATOR
      )
      ;; ROLE_OPERATOR ERR_UNAUTHORIZED
    )
    ;; Check limits
    (if (> (- block-height (var-get last-spend-block))
        (contract-call? .nakamoto-constants get-blocks-per-day)
      )
      (begin
        (var-set daily-spend amount)
        (var-set last-spend-block block-height)
      )
      (begin
        (asserts! (<= (+ (var-get daily-spend) amount) (var-get allowance-limit))
          (err u1001)
        )
        (var-set daily-spend (+ (var-get daily-spend) amount))
      )
    )
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)
