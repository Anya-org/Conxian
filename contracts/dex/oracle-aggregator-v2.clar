;; oracle-aggregator-v2.clar
;; Conxian Oracle Standard: Hybrid Aggregator V2
;; Orchestrates Pyth (DEX), RedStone (Lending), and Switchboard (Sentinels)

;; Traits
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7300))
(define-constant ERR_STALE_PRICE (err u7301))

;; @desc Routes price request based on Intent (DEX vs Lending)
(define-public (get-price-by-intent
        (asset principal)
        (intent (string-ascii 20))
    )
    (begin
        (if (is-eq intent "DEX")
            ;; Use Pyth for Efficiency
            (contract-call? .pyth-oracle-adapter get-price asset)
            (if (is-eq intent "LENDING")
                ;; Use RedStone for Consistency
                (contract-call? .redstone-oracle-adapter get-price asset)
                ;; Fallback to Pyth
                (contract-call? .pyth-oracle-adapter get-price asset)
            )
        )
    )
)

;; @desc Aggregated System Health Check
(define-read-only (get-system-intelligence)
    (let ((alert-status (unwrap-panic (contract-call? .switchboard-oracle-adapter get-alert-status))))
        (ok {
            alert: alert-status,
            ready-to-trade: (< (get level alert-status) u2),
            tenure: (contract-call? .block-utils get-current-tenure-id),
        })
    )
)

;; @desc Generic get-price for backward compatibility (Uses Pyth)
(define-public (get-price (asset principal))
    (contract-call? .pyth-oracle-adapter get-price asset)
)

;; @desc Admin functions to configure weights (Optional/Extended)
(define-public (get-weights (asset principal))
    (ok (list u100))
)
