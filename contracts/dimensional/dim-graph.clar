;; dim-graph.clar
;; Conxian SAB: Dimensional Graph Protocol
;; Manages relationships between dimensional assets

(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u3003))

;; Data Vars
(define-data-var admin principal tx-sender)

;; Graph storage
(define-map asset-nodes
  (string-ascii 32)
  { 
    asset: (string-ascii 32),
    weight: uint,
    connections: (list 10 (string-ascii 32))
  }
)

(define-map correlation-edges
  { 
    asset1: (string-ascii 32),
    asset2: (string-ascii 32)
  }
  { 
    correlation: uint,
    last-updated: uint
  }
)

;; Public functions
(define-public (add-asset-node (asset (string-ascii 32)) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set asset-nodes asset {
      asset: asset,
      weight: weight,
      connections: (list)
    })
    (ok true)
  )
)

(define-public (set-correlation (asset1 (string-ascii 32)) (asset2 (string-ascii 32)) (correlation uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set correlation-edges { asset1: asset1, asset2: asset2 } {
      correlation: correlation,
      last-updated: block-height
    })
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-asset-node (asset (string-ascii 32)))
  (match (map-get? asset-nodes asset)
    node (ok node)
    (err u0)
  )
)

(define-read-only (get-correlation (asset1 (string-ascii 32)) (asset2 (string-ascii 32)))
  (match (map-get? correlation-edges { asset1: asset1, asset2: asset2 })
    edge (ok edge)
    (err u0)
  )
)