;; oracle-aggregator-v2.clar
;; Conxian Oracle Standard: Hybrid Aggregator V2
;; Orchestrates Pyth (DEX), RedStone (Lending), and Switchboard (Sentinels)
;; Enhanced with TWAP and Manipulation Detection

;; Traits
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7300))
(define-constant ERR_STALE_PRICE (err u7301))
(define-constant ERR_PRICE_DEVIATION (err u7302))

;; Data vars for TWAP
(define-map price-cumulative-history
    { asset: principal, block: uint }
    uint
)

(define-map last-updated
    principal
    uint
)

;; Configuration
(define-data-var deviation-threshold uint u500) ;; 5% deviation allowed (basis points)

;; @desc Routes price request based on Intent (DEX vs Lending)
(define-public (get-price-by-intent
        (asset principal)
        (intent (string-ascii 20))
    )
    (let
        (
            (price-result (if (is-eq intent "DEX")
                ;; Use Pyth for Efficiency
                (contract-call? .pyth-oracle-adapter get-price asset)
                (if (is-eq intent "LENDING")
                    ;; Use RedStone for Consistency
                    (contract-call? .redstone-oracle-adapter get-price asset)
                    ;; Fallback to Pyth
                    (contract-call? .pyth-oracle-adapter get-price asset)
                )
            ))
        )
        ;; Perform manipulation check before returning
        (match price-result
            price (begin
                (try! (check-manipulation asset price))
                (ok price)
            )
            error (err error)
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

;; Internal Security Functions

(define-private (check-manipulation (asset principal) (current-price uint))
    (let
        (
            (last-block (default-to u0 (map-get? last-updated asset)))
            (history-price (if (> last-block u0)
                (get-twap asset last-block block-height)
                (ok current-price) ;; First observation, trust it
            ))
        )
        ;; Update history for next time
        (map-set price-cumulative-history { asset: asset, block: block-height } current-price) ;; Simplified storage
        (map-set last-updated asset block-height)
        
        (match history-price
            safe-price (if (is-deviation-safe current-price safe-price)
                (ok true)
                ERR_PRICE_DEVIATION
            )
            error (err (to-uint error))
        )
    )
)

(define-private (get-twap (asset principal) (start-block uint) (end-block uint))
    ;; Stub for TWAP calculation retrieval
    ;; In real implementation, this would fetch cumulative prices and divide
    (ok u0) 
)

(define-private (is-deviation-safe (price-a uint) (price-b uint))
    (let
        (
            (diff (if (> price-a price-b) (- price-a price-b) (- price-b price-a)))
            (threshold (var-get deviation-threshold))
        )
        ;; Check if diff / price-b * 10000 <= threshold
        ;; Simplified: diff * 10000 <= threshold * price-b
        (<= (* diff u10000) (* threshold price-b))
    )
)
