;; dim-registry.clar
;; Conxian SAB: Dimensional Asset Registry
;; Registry for managing dimensional asset metadata

(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u3004))
(define-constant ERR_ASSET_EXISTS (err u3005))

;; Data Vars
(define-data-var admin principal tx-sender)

;; Asset registry
(define-map asset-registry
  (string-ascii 32)
  {
    name: (string-ascii 64),
    category: uint,
    decimals: uint,
    is-active: bool,
    created-at: uint
  }
)

;; Category registry
(define-map category-registry
  uint
  {
    name: (string-ascii 32),
    description: (string-ascii 128),
    fee-rate: uint
  }
)

;; Public functions
(define-public (register-asset 
  (symbol (string-ascii 32)) 
  (name (string-ascii 64)) 
  (category uint) 
  (decimals uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? asset-registry symbol)
      existing (err ERR_ASSET_EXISTS)
      (begin
        (map-set asset-registry symbol {
          name: name,
          category: category,
          decimals: decimals,
          is-active: true,
          created-at: block-height
        })
        (ok true)
      )
    )
  )
)

(define-public (toggle-asset (symbol (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? asset-registry symbol)
      asset
      (begin
        (map-set asset-registry symbol (merge asset { is-active: (not (get is-active asset)) }))
        (ok true)
      )
      (err u0)
    )
  )
)

;; Read-only functions
(define-read-only (get-asset (symbol (string-ascii 32)))
  (match (map-get? asset-registry symbol)
    asset (ok asset)
    (err u0)
  )
)

(define-read-only (get-category (category uint))
  (match (map-get? category-registry category)
    cat (ok cat)
    (err u0)
  )
)