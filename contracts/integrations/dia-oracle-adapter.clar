;; dia-oracle-adapter.clar
;; Conxian Oracle Standard: DIA Data Adapter
;; Implements oracle-trait for DIA decentralized price feeds
(impl-trait .oracle-trait.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6100)
(define-constant ERR_INVALID_SIGNATURE u6101)
(define-constant ERR_NO_PRICE u6102)

;; Data Vars
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Price Storage
(define-map dia-prices
    principal ;; Asset
    {
        price: uint,
        timestamp: uint,
        signature: (buff 65)
    }
)

;; Oracle Trait Implementation
(define-read-only (get-price (asset principal))
  (match (map-get? dia-prices asset)
    price-data (ok (get price price-data))
    none (err ERR_NO_PRICE)
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-name ())
  (ok "DIA Oracle Adapter")
)

;; Admin: Update Price

;; @desc Update the DIA price feed for a specific asset (Authorized only)
(define-public (update-price (asset principal) (price uint) (signature (buff 65)))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
        (map-set dia-prices asset {
            price: price,
            timestamp: burn-block-height,
            signature: signature
        })
        (print { event: "dia-price-update", asset: asset, price: price })
        (ok true)
    )
)
