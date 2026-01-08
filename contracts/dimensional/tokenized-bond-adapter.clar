;; tokenized-bond-adapter.clar
;; Conxian SAB: Tokenized Bond Adapter
;; Adapter for integrating external bond systems

(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u30017))
(define-constant ERR_ADAPTER_NOT_FOUND (err u30018))

;; Data Vars
(define-data-var admin principal tx-sender)

;; Adapter registry
(define-map bond-adapters
  (string-ascii 32)
  {
    adapter-contract: principal,
    is-active: bool,
    last-sync: uint
  }
)

;; Bond mapping
(define-map external-bond-mapping
  (string-ascii 64)
  {
    external-id: (string-ascii 64),
    internal-bond-id: uint,
    adapter: (string-ascii 32)
  }
)

;; Public functions
(define-public (register-adapter 
  (name (string-ascii 32)) 
  (adapter-contract principal)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set bond-adapters name {
      adapter-contract: adapter-contract,
      is-active: true,
      last-sync: block-height
    })
    (ok true)
  )
)

(define-public (sync-external-bond 
  (adapter-name (string-ascii 32)) 
  (external-id (string-ascii 64)) 
  (internal-bond-id uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set external-bond-mapping external-id {
      external-id: external-id,
      internal-bond-id: internal-bond-id,
      adapter: adapter-name
    })
    (ok true)
  )
)

(define-public (toggle-adapter (adapter-name (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? bond-adapters adapter-name)
      adapter
      (begin
        (map-set bond-adapters adapter-name (merge adapter { 
          is-active: (not (get is-active adapter)),
          last-sync: block-height
        }))
        (ok true)
      )
      (err ERR_ADAPTER_NOT_FOUND)
    )
  )
)

;; Read-only functions
(define-read-only (get-adapter (name (string-ascii 32)))
  (match (map-get? bond-adapters name)
    adapter (ok adapter)
    (err ERR_ADAPTER_NOT_FOUND)
  )
)

(define-read-only (get-external-mapping (external-id (string-ascii 64)))
  (match (map-get? external-bond-mapping external-id)
    mapping (ok mapping)
    (err u0)
  )
)

(define-read-only (get-internal-bond-id (external-id (string-ascii 64)))
  (match (map-get? external-bond-mapping external-id)
    mapping (ok (get internal-bond-id mapping))
    (err u0)
  )
)