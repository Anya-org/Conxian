;; yield-aggregator.clar
;; Vault strategy aggregator
;; Manages deposits across multiple strategies

(use-trait vault-trait .vault-trait.vault-trait)

(define-map strategies principal bool)

(define-public (add-strategy (strategy <vault-trait>))
    (begin
        (map-set strategies (contract-of strategy) true)
        (ok true)
    )
)

(define-public (deposit (strategy <vault-trait>) (amount uint))
    (begin
        (asserts! (default-to false (map-get? strategies (contract-of strategy))) (err u404))
        (contract-call? strategy deposit amount tx-sender)
    )
)
