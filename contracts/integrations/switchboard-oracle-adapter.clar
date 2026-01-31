;; switchboard-oracle-adapter.clar
;; Conxian Oracle Standard: System Sentinel (Intelligence Layer)
;; Handles Governance Alerts, Circuit Breakers, and System Health

;; Constants

;; Constants
(define-constant ERR_UNAUTHORIZED u6200)
(define-constant ERR_NO_PRICE u6201)
(define-constant ERR_CONFIDENCE_TOO_LOW u6202)

(define-data-var block-utils-contract principal .block-utils)
(define-data-var admin principal tx-sender)
(define-data-var min-confidence uint u100)

;; State

;; Price Storage
(define-map switchboard-feeds
    principal ;; Asset
    {
        price: uint,
        confidence: uint,
        timestamp: uint
    }
)

;; Read-only: Get Price
(define-public (get-price (asset principal))
    (let (
        (feed (unwrap! (map-get? switchboard-feeds asset) (err ERR_NO_PRICE)))
    )
        (asserts! (>= (get confidence feed) (var-get min-confidence)) (err ERR_CONFIDENCE_TOO_LOW))
        (ok (get price feed))
    )
)

;; Admin: Update Price with Confidence
(define-public (update-price (asset principal) (price uint) (confidence uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (map-set switchboard-feeds asset {
            price: price,
            confidence: confidence,
            timestamp: stacks-block-time
        })
        (print { event: "switchboard-price-update", asset: asset, price: price, confidence: confidence })
        (ok true)
    )
)

;; Read-only: Get Name
(define-read-only (get-name)
    (ok "Switchboard-Adapter")
)
