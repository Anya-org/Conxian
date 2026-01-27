;; performance-optimizer.clar
;; Monitors and optimizes gas usage and transaction throughput

(define-constant ERR_UNAUTHORIZED (err u5000))

(define-map function-gas-costs
    (string-ascii 40) ;; function name
    {
        total-cost: uint,
        call-count: uint
    }
)

(define-map transaction-throughput
    uint ;; block height
    uint ;; transaction count
)

(define-public (record-gas-cost (func-name (string-ascii 40)) (cost uint))
    (let
        (
            (data (default-to { total-cost: u0, call-count: u0 } (map-get? function-gas-costs func-name)))
            (total-cost (get total-cost data))
            (call-count (get call-count data))
        )
        (map-set function-gas-costs func-name {
            total-cost: (+ total-cost cost),
            call-count: (+ call-count u1)
        })
        (ok true)
    )
)

(define-public (increment-transaction-count)
    (let
        (
            (count (default-to u0 (map-get? transaction-throughput block-height)))
        )
        (map-set transaction-throughput block-height (+ count u1))
        (ok true)
    )
)

(define-read-only (get-average-gas-cost (func-name (string-ascii 40)))
    (let
        (
            (data (unwrap! (map-get? function-gas-costs func-name) (err u0)))
            (total-cost (get total-cost data))
            (call-count (get call-count data))
        )
        (ok (/ total-cost call-count))
    )
)
