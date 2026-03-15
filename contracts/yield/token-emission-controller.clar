;; token-emission-controller.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-map emission-targets principal uint)

;; Principal Injection Pattern
(define-data-var coordinator-contract principal .token-system-coordinator)
(define-data-var cxvg-token-contract principal .cxvg-token)

(define-public (request-mint (amount uint) (recipient principal))
  (let (
    (weight (default-to u0 (map-get? emission-targets tx-sender)))
  )
    (asserts! (> weight u0) (err ERR_UNAUTHORIZED))
    ;; Use the injected principals
    (ok true)
  )
)

(define-public (initialize (coordinator principal) (cxvg principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set coordinator-contract coordinator)
    (var-set cxvg-token-contract cxvg)
    (ok true)
  )
)

(define-public (add-emission-target (target principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set emission-targets target weight)
    (ok true)
  )
)
