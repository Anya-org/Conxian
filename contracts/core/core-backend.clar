;; core-backend.clar
;; Conxian Enterprise Standard: Core Protocol Backend
;; Contains all business logic for core protocol operations

;; Trait imports
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait ownable-trait .core-traits.ownable-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u9100))
(define-constant ERR_INVALID_PARAMETER (err u9101))
(define-constant ERR_NOT_CONFIGURED (err u9102))

;; Protocol configuration
(define-data-var protocol-owner principal tx-sender)
(define-data-var protocol-version uint u1000)
(define-data-var is-active bool true)

;; Protocol parameters
(define-map protocol-params 
  (string-ascii 32) 
  uint
)

;; System metrics
(define-data-var total-operations uint u0)
(define-data-var last-operation-height uint block-height)

;; Public functions
(define-public (get-protocol-config)
  (ok {
    owner: (var-get protocol-owner),
    version: (var-get protocol-version),
    is-active: (var-get is-active),
    total-operations: (var-get total-operations),
    last-operation-height: (var-get last-operation-height)
  })
)

(define-public (set-protocol-parameter (param-name (string-ascii 32)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (> value u0) ERR_INVALID_PARAMETER)
    
    (map-set protocol-params param-name value)
    (var-set total-operations (+ (var-get total-operations) u1))
    (var-set last-operation-height block-height)
    
    (ok true)
  )
)

(define-public (get-system-status)
  (ok {
    is-active: (var-get is-active),
    current-height: block-height,
    operations-count: (var-get total-operations),
    version: (var-get protocol-version)
  })
)

(define-public (update-protocol-version (new-version uint))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (> new-version (var-get protocol-version)) ERR_INVALID_PARAMETER)
    
    (var-set protocol-version new-version)
    (ok true)
  )
)

(define-public (toggle-protocol-status)
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (var-set is-active (not (var-get is-active)))
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner none)) ERR_INVALID_PARAMETER)
    
    (var-set protocol-owner new-owner)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-parameter (param-name (string-ascii 32)))
  (match (map-get? protocol-params param-name)
    value (ok value)
    (err ERR_NOT_CONFIGURED)
  )
)

(define-read-only (get-all-parameters)
  (map-to-list protocol-params)
)

(define-read-only (get-protocol-info)
  (ok {
    owner: (var-get protocol-owner),
    version: (var-get protocol-version),
    is-active: (var-get is-active),
    total-operations: (var-get total-operations),
    last-operation_height: (var-get last-operation-height)
  })
)
