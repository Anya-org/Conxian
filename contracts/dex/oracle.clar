;; oracle.clar
;; Conxian Protocol: Oracle Stub
;; Standard interface for price data.

(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; State
(define-data-var contract-owner principal tx-sender)
(define-map prices principal uint)

;; Public Functions

;; @desc Set the price for a specific token
(define-public (set-price (token principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set prices token price)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Get the price for a specific token
(define-read-only (get-price (token principal))
  (ok (default-to u0 (map-get? prices token)))
)

;; @desc Fetch the latest price for a token
(define-public (fetch-price (token principal))
  (ok (default-to u0 (map-get? prices token)))
)

;; @desc Transfer contract ownership to a new principal
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)
