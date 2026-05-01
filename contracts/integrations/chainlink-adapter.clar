;; chainlink-adapter.clar
;; Conxian Oracle Standard: Chainlink Adapter
;; Implements oracle-trait for Chainlink price feeds

(use-trait oracle-trait .defi-traits.oracle-trait)
(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_STALE_PRICE u6001)
(define-constant ERR_NO_PRICE u6002)

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var max-staleness uint u100) ;; 100 blocks (~5 minutes)

;; Price Storage
(define-map price-feeds
    principal ;; Asset
    {
        price: uint, timestamp: uint, confidence: uint
    }
)

;; Oracle Trait Implementation
(define-read-only (get-price (asset principal))
  (match (map-get? price-feeds asset)
    price-data (ok (get price price-data))
    (err ERR_NO_PRICE)
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-name)
  (ok "Chainlink Oracle Adapter")
)

;; Admin: Update Price

;; @desc Update the price feed for a specific asset (Authorized only)
(define-public (update-price (asset principal) (price uint) (round-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (map-set price-feeds asset {
            price: price, timestamp: burn-block-height, confidence: u5000 ;; Default confidence
        })
        (print { event: "chainlink-price-update", asset: asset, price: price, round: round-id })
        (ok true)
    )
)
