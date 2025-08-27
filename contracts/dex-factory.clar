;; Minimal DEX Factory proxy for AutoVault
;; Provides a two-arg get-pool interface expected by other contracts (e.g., dex-router)
;; Internally adapts to dex-factory-v2 which indexes pools by pair/type/fee


(define-constant DEFAULT_FEE_TIER u300)

(define-read-only (get-pool (token-x principal) (token-y principal))
  (match (contract-call? .dex-factory-v2 get-pool token-x token-y DEFAULT_POOL_TYPE DEFAULT_FEE_TIER)
    pool (some { pool: pool })
    none))
