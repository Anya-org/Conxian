;; PRODUCTION: Mock DEX for testing and development
;; Simplified DEX implementation for integration testing
;; Simple mock DEX for buyback testing
(define-public (simulate-actr-purchase (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    ;; Mock purchase without calling avg-token to avoid circular dependency
    (print { event: "mock-actr-purchase", amount: amount, multiplier: u100 })
    (ok (* amount u100))
  )
)
