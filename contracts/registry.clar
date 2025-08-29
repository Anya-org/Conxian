;; Multi-vault registry with strategy references and service discovery

(define-data-var admin principal tx-sender)
(define-data-var next-index uint u0)
(define-data-var next-service-id uint u0)

(define-map vaults { vault: principal } { strategy: (optional principal), active: bool })
(define-map indices { index: uint } { vault: principal })

;; Service registry for contract discovery
(define-map services { service-id: uint } { 
  contract: principal,
  service-type: (string-ascii 50),
  name: (string-ascii 100),
  active: bool 
})
(define-map service-types { service-type: (string-ascii 50) } { 
  contracts: (list 10 principal),
  count: uint 
})

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-public (set-admin (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin p)
    (ok true)
  )
)

(define-public (register-vault (v principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((exists (is-some (map-get? vaults { vault: v }))))
      (if exists
        (ok false)
        (let ((i (var-get next-index)))
          (map-set vaults { vault: v } { strategy: none, active: true })
          (map-set indices { index: i } { vault: v })
          (var-set next-index (+ i u1))
          (ok true)
        )
      )
    )
  )
)

(define-public (set-vault-strategy (v principal) (s principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((item (map-get? vaults { vault: v })))
      (match item i
        (begin
          (map-set vaults { vault: v } { strategy: (some s), active: (get active i) })
          (ok true)
        )
        (err u101)
      )
    )
  )
)

(define-public (set-vault-active (v principal) (a bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((item (map-get? vaults { vault: v })))
      (match item i
        (begin
          (map-set vaults { vault: v } { strategy: (get strategy i), active: a })
          (ok true)
        )
        (err u101)
      )
    )
  )
)

(define-read-only (get-vault (v principal))
  (default-to { strategy: none, active: false } (map-get? vaults { vault: v }))
)

(define-read-only (get-vault-at (i uint))
  (let ((it (map-get? indices { index: i })))
    (match it r (ok (get vault r)) (err u101))
  )
)

(define-read-only (get-count)
  (var-get next-index)
)

;; Service registry functions
(define-public (register-service (contract principal) (service-type (string-ascii 50)) (name (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((service-id (var-get next-service-id)))
      (map-set services { service-id: service-id } {
        contract: contract,
        service-type: service-type,
        name: name,
        active: true
      })
      (var-set next-service-id (+ service-id u1))
      
      ;; Update service-types map
      (let ((current-types (default-to { contracts: (list), count: u0 } 
                           (map-get? service-types { service-type: service-type }))))
        (map-set service-types { service-type: service-type } {
          contracts: (unwrap! (as-max-len? (append (get contracts current-types) contract) u10) (err u103)),
          count: (+ (get count current-types) u1)
        })
      )
      (ok service-id)
    )
  )
)

(define-public (set-service-active (service-id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((service (map-get? services { service-id: service-id })))
      (match service s
        (begin
          (map-set services { service-id: service-id } {
            contract: (get contract s),
            service-type: (get service-type s),
            name: (get name s),
            active: active
          })
          (ok true)
        )
        (err u101)
      )
    )
  )
)

(define-read-only (get-service (service-id uint))
  (map-get? services { service-id: service-id })
)

(define-read-only (get-services-by-type (service-type (string-ascii 50)))
  (default-to { contracts: (list), count: u0 } 
              (map-get? service-types { service-type: service-type }))
)

(define-read-only (find-service-contract (service-type (string-ascii 50)))
  ;; Returns the first active service contract of the given type
  (let ((services-info (get-services-by-type service-type)))
    (let ((contracts-list (get contracts services-info)))
      (if (> (len contracts-list) u0)
        (some (unwrap-panic (element-at contracts-list u0)))
        none
      )
    )
  )
)

(define-read-only (get-service-count)
  (var-get next-service-id)
)

;; Errors
;; u100: unauthorized  
;; u101: not-found
;; u102: already-exists
;; u103: list-overflow

;; Service initialization helper
(define-public (initialize-core-services)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    ;; Register core services
    (unwrap! (register-service .analytics "analytics" "Core Analytics Service") (err u200))
    (unwrap! (register-service .CXG-token "token" "CXG Governance Token") (err u201))
    (unwrap! (register-service .vault "vault" "Core Vault Service") (err u202))
    (unwrap! (register-service .treasury "treasury" "Treasury Management") (err u203))
    (unwrap! (register-service .dao-governance "governance" "DAO Governance") (err u204))
    (unwrap! (register-service .enterprise-monitoring "monitoring" "Enterprise Monitoring") (err u205))
    (print { event: "core-services-initialized", services: u6 })
    (ok true)
  )
)
