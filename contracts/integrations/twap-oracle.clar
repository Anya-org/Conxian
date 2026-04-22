;; twap-oracle.clar
;; Gas-Efficient Time-Weighted Average Price (TWAP) Oracle
;; Implements oracle-trait for DEX-derived TWAP calculations
(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_NO_PRICE u6001)
(define-constant ERR_WINDOW_TOO_SHORT u6002)

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var twap-window uint u144) ;; 24 hours in blocks

;; Price History Storage: { asset, block } -> price
(define-map price-observations
  { asset: principal, block: uint }
  uint
)

;; Oracle Trait Implementation
(define-read-only (get-price (asset principal))
  (let (
          (current-block burn-block-height)
          (window (var-get twap-window)))
      (if (>= current-block window)
          ;; Get price at start of window
          (match (map-get? price-observations { asset: asset, block: (- current-block window) })
            start-price
              (match (map-get? price-observations { asset: asset, block: current-block })
                end-price
                  (ok (/ (+ start-price end-price) u2)) ;; Simple average
                (err ERR_NO_PRICE)
              )
            (err ERR_NO_PRICE)
          )
          (err ERR_WINDOW_TOO_SHORT)
      )
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-name)
  (ok "TWAP Oracle")
)

;; Admin Functions

(define-public (update-price-observation (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set price-observations { asset: asset, block: burn-block-height } price)
    (ok true)
  )
)

(define-public (set-twap-window (new-window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set twap-window new-window)
    (ok true)
  )
)
