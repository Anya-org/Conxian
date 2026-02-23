;; oracle.clar
;; Conxian Protocol Standard Contract

;; oracle.clar
;; Manual Price Oracle for Conxian Protocol
;; Allows admin to set prices for assets

(impl-trait .defi-traits.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PRICE_NOT_FOUND u1001)

;; Data Vars
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Price Map
(define-map prices principal uint)

;; Authorization
(define-read-only (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Public Functions


;; @desc Set price
;; @returns (response bool uint)
(define-public (set-price (asset principal) (price uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set prices asset price)
    (print { event: "price-set", asset: asset, price: price })
    (ok true)
  )
)


;; @desc Set contract owner
;; @returns (response bool uint)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Trait Implementation

(define-read-only (get-price (asset principal))
  (match (map-get? prices asset)
    price (ok price)
    (err ERR_PRICE_NOT_FOUND)
  )
)

(define-read-only (fetch-price (asset principal))
  (get-price asset)
)

(define-read-only (get-name)
  (ok "Conxian-Manual-Oracle")
)
