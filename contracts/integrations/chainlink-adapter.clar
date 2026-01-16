;; chainlink-adapter.clar
;; Conxian Oracle Standard: Chainlink Adapter
;; Implements oracle-trait for Chainlink price feeds

(impl-trait .oracle-pricing.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_STALE_PRICE (err u6001))
(define-constant ERR_NO_PRICE (err u6002))

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var max-staleness uint u100) ;; 100 blocks (~5 minutes)

;; Price Storage
(define-map price-feeds
    principal ;; Asset
    {
        price: uint,
        timestamp: uint,
        round-id: uint
    }
)

;; Read-only: Get Price
(define-read-only (get-price (asset principal))
    (let (
        (feed (unwrap! (map-get? price-feeds asset) (err ERR_NO_PRICE)))
        (blocks-old (- block-height (get timestamp feed)))
    )
        (asserts! (< blocks-old (var-get max-staleness)) (err ERR_STALE_PRICE))
        (ok (get price feed))
    )
)

;; Admin: Update Price
(define-public (update-price (asset principal) (price uint) (round-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (map-set price-feeds asset {
            price: price,
            timestamp: block-height,
            round-id: round-id
        })
        (print { event: "chainlink-price-update", asset: asset, price: price, round: round-id })
        (ok true)
    )
)

;; Read-only: Get Name
(define-read-only (get-name)
    (ok "Chainlink-Adapter")
)
