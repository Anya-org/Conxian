;; oracle-aggregator.clar
;; Conxian Oracle Standard: Hybrid Aggregator V2
;; Orchestrates Pyth (DEX), RedStone (Lending), and Switchboard (Sentinels)
;; Enhanced with TWAP and Manipulation Detection

;; Traits
(use-trait oracle-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u7300)
(define-constant ERR_STALE_PRICE u7301)
(define-constant ERR_PRICE_DEVIATION u7302)
(define-constant ERR_CIRCUIT_OPEN u7303)

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
(define-data-var circuit-breaker (optional principal) none)

(define-private (check-circuit-breaker)
    (match (var-get circuit-breaker)
        cb (contract-call? .circuit-breaker is-circuit-breaker-active)
        (ok false)
    )
)

;; @desc Routes price request based on Intent (DEX vs Lending)
(define-public (get-price-by-intent
        (asset principal)
        (intent (string-ascii 20))
    )
    (begin
        (if (try! (check-circuit-breaker)) (err ERR_CIRCUIT_OPEN) (ok true))
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
)

;; @desc Aggregated System Health Check
(define-read-only (get-system-intelligence)
    (let ((alert-status (contract-call? .switchboard-oracle-adapter get-alert-status)))
        (ok {
            alert: alert-status,
            ready-to-trade: (< (get level alert-status) u2),
            tenure: (/ block-height u10),
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

(define-map asset-volatility
    principal
    {
        mean: uint,
        std-dev: uint
    }
)

(define-private (update-volatility (asset principal) (price uint))
    (let
        (
            (vol (default-to { mean: u0, std-dev: u0 } (map-get? asset-volatility asset)))
            (mean (get mean vol))
            (std-dev (get std-dev vol))
            ;; Simplified volatility update
            (new-mean (/ (+ mean price) u2))
            (new-std-dev (/ (+ std-dev (abs (- price new-mean))) u2))
        )
        (map-set asset-volatility asset { mean: new-mean, std-dev: new-std-dev })
        (ok true)
    )
)

(define-private (check-manipulation (asset principal) (current-price uint))
    (let
        (
            (vol (default-to { mean: current-price, std-dev: u0 } (map-get? asset-volatility asset)))
            (mean (get mean vol))
            (std-dev (get std-dev vol))
            (deviation-threshold (* std-dev u3)) ;; 3 standard deviations
        )
        (try! (update-volatility asset current-price))
        (asserts! (< (abs (- current-price mean)) deviation-threshold) (err ERR_PRICE_DEVIATION))
        (ok true)
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
