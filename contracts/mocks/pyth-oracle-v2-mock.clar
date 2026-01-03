;; pyth-oracle-v2-mock.clar
;; Mock Pyth contract for Local Testing

(define-map prices principal { price: uint, expo: int, publish-time: uint })

(define-public (verify-and-update-price-feeds (vaa (buff 2048)))
    (begin
        ;; Mock: Always succeed
        (print { event: "pyth-mock-update", vaa: vaa })
        (ok true)
    )
)

(define-read-only (get-price (asset principal))
    (ok (default-to { price: u100000000, expo: -8, publish-time: u1699000000 } 
        (map-get? prices asset)))
)

;; Test helper
(define-public (set-price (asset principal) (price uint))
    (begin
        (map-set prices asset { price: price, expo: -8, publish-time: u1699000001 })
        (ok true)
    )
)
