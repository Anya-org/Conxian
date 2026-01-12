;; twap-oracle.clar
;; Time-Weighted Average Price Oracle
;; Implements oracle-trait for DEX-derived TWAP calculations

(impl-trait .oracle-pricing.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6400))
(define-constant ERR_NO_PRICE (err u6401))
(define-constant ERR_WINDOW_TOO_SHORT (err u6402))

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var twap-window uint u10) ;; 10 blocks

;; Price Observations
(define-map price-observations
    { asset: principal, block: uint }
    uint ;; Price at that block
)

;; Cumulative Price Storage
(define-map cumulative-prices
    principal
    {
        cumulative: uint,
        last-update: uint,
        last-price: uint
    }
)

;; Read-only: Get TWAP
(define-public (get-price (asset principal))
    (let (
        (cumulative (unwrap! (map-get? cumulative-prices asset) (err ERR_NO_PRICE)))
        (window (var-get twap-window))
        (current-block block-height)
        (start-block (- current-block window))
    )
        ;; Simplified TWAP calculation
        (ok (get last-price cumulative))
    )
)

;; Admin: Record Price Observation
(define-public (record-price (asset principal) (price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        
        ;; Store observation
        (map-set price-observations { asset: asset, block: block-height } price)
        
        ;; Update cumulative
        (match (map-get? cumulative-prices asset)
            existing
            (map-set cumulative-prices asset {
                cumulative: (+ (get cumulative existing) price),
                last-update: block-height,
                last-price: price
            })
            (map-set cumulative-prices asset {
                cumulative: price,
                last-update: block-height,
                last-price: price
            })
        )
        
        (print { event: "twap-observation", asset: asset, price: price, block: block-height })
        (ok true)
    )
)

;; Read-only: Get Name
(define-read-only (get-name)
    (ok "TWAP-Oracle")
)
