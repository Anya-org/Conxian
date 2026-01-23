;; core-facade.clar
;; Conxian Enterprise Standard: Core Protocol Facade
;; Thin routing layer for core protocol operations
;; Delegates all business logic to backend contracts

;; Trait imports
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait ownable-trait .core-traits.ownable-trait)

;; Backend contract references (will be resolved from registry)
(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_BACKEND_NOT_FOUND (err u9001))
(define-constant ERR_INVALID_OPERATION (err u9002))

;; Data Vars
(define-data-var facade-admin principal tx-sender)
(define-data-var core-backend principal tx-sender)
(define-data-var is-paused bool false)

;; Access control
(define-map authorized-callers principal bool)

;; Public functions - thin delegation to backend
(define-public (get-protocol-config)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    (match (var-get core-backend)
      backend 
      (contract-call? backend get-protocol-config)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (set-protocol-parameter (param-name (string-ascii 32)) (value uint))
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    (match (var-get core-backend)
      backend 
      (contract-call? backend set-protocol-parameter param-name value)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (get-system-status)
  (begin
    (asserts! (not (var-get is-paused)) ERR_INVALID_OPERATION)
    
    (match (var-get core-backend)
      backend 
      (contract-call? backend get-system-status)
      (err ERR_BACKEND_NOT_FOUND)
    )
  )
)

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set is-paused true)
    (ok true)
  )
)

(define-public (emergency-unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set is-paused false)
    (ok true)
  )
)

;; Admin functions
(define-public (set-facade-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set facade-admin new-admin)
    (ok true)
  )
)

(define-public (set-core-backend (new-backend principal))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (var-set core-backend new-backend)
    (ok true)
  )
)

(define-public (authorize-caller (caller principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get facade-admin)) ERR_UNAUTHORIZED)
    (map-set authorized-callers caller authorized)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-authorized (caller principal))
  (ok (or 
    (is-eq caller (var-get facade-admin))
    (default-to false (map-get? authorized-callers caller))
  ))
)

(define-read-only (get-facade-info)
  (ok {
    admin: (var-get facade-admin),
    backend: (var-get core-backend),
    is-paused: (var-get is-paused)
  })
)
