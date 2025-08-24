;; PRODUCTION: Mock DEX for testing and development
;; Simplified DEX implementation for integration testing
;; Simple mock DEX for buyback testing
(define-public (swap-stx-for-avg (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    ;; 1 STX -> 100 AVG fixed rate mint (using public path via governance for simplicity)
    (unwrap! (contract-call? .avg-token migrate-actr (* amount u100)) (err u300))
    (ok (* amount u100))
  )
)
