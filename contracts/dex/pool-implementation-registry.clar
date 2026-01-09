;; pool-implementation-registry.clar
;; Conxian DEX: Registry for pool implementations and factory contracts

;; Dependencies
(use-trait defi-traits .defi-traits.defi-traits)
(use-trait factory-trait .factory-trait.factory-trait)

;; Constants
(define-constant ERR_INVALID_IMPLEMENTATION (err 22001))
(define-constant ERR_IMPLEMENTATION_EXISTS (err 22002))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err 22003))
(define-constant ERR_UNAUTHORIZED_REGISTRATION (err 22004))
(define-constant ERR_INVALID_FACTORY (err 22005))

;; Registry parameters
(define-constant MAX_IMPLEMENTATIONS u50)
(define-constant MAX_FACTORIES_PER_TYPE u10)
(define-constant REGISTRATION_FEE u1000000) ;; 1 STX equivalent
(define-constant MIN_LIQUIDITY_REQUIREMENT u10000000) ;; 10 STX equivalent

;; Data variables
(define-data-var registry-active bool true)
(define-data-var total-implementations uint u0)
(define-data-var total-factories uint u0)
(define-data-var last-cleanup uint u0)

;; Storage maps
(define-map pool-implementations { impl-id: uint } { 
  name: (string-ascii 64),
  version: (string-ascii 16),
  contract-address: principal,
  factory-address: principal,
  pool-type: (string-ascii 32),
  features: (list 10 (string-ascii 32)),
  min-liquidity: uint,
  max-liquidity: uint,
  fee-tier: uint,
  active: bool,
  registration-time: uint,
  registration-fee: uint
})

(define-map factory-registrations { factory: principal } { 
  impl-id: uint,
  pool-type: (string-ascii 32),
  authorized: bool,
  registration-time: uint,
  total-pools-created: uint
})

(define-map implementation-factories { impl-id: uint } { 
  factories: (list 10 principal),
  primary-factory: principal
})

(define-map pool-type-implementations { pool-type: (string-ascii 32) } { 
  implementations: (list 10 uint),
  default-impl: uint
})

(define-map implementation-stats { impl-id: uint } { 
  total-pools: uint,
  total-volume: uint,
  total-fees: uint,
  average-utilization: uint,
  last-update: uint
})

;; Events
(define-event (implementation-registered (impl-id uint) (name (string-ascii 64)) (contract principal)))
(define-event (factory-registered (factory principal) (impl-id uint)))
(define-event (implementation-deactivated (impl-id uint)))
(define-event (default-implementation-updated (pool-type (string-ascii 32)) (old-impl uint) (new-impl uint)))
(define-event (pool-created (impl-id uint) (pool principal) (factory principal)))
(define-event (registry-cleanup (implementations-removed uint)))

;; Read-only functions

(define-read-only (get-implementation (impl-id uint))
  (map-get? pool-implementations { impl-id: impl-id }))

(define-read-only (get-implementation-name (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl name))
    none (ok "")
  )
)

(define-read-only (get-implementation-contract (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl contract-address))
    none (ok tx-sender)
  )
)

(define-read-only (get-implementation-factory (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl factory-address))
    none (ok tx-sender)
  )
)

(define-read-only (get-implementation-type (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl pool-type))
    none (ok "")
  )
)

(define-read-only (get-implementation-features (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl features))
    none (ok (list 0 (string-ascii 32)))
  )
)

(define-read-only (is-implementation-active (impl-id uint))
  (match (get-implementation impl-id)
    impl (ok (get impl active))
    none (ok false)
  )
)

(define-read-only (get-factory-registration (factory principal))
  (map-get? factory-registrations { factory: factory }))

(define-read-only (is-factory-authorized (factory principal))
  (match (get-factory-registration factory)
    reg (ok (get reg authorized))
    none (ok false)
  )
)

(define-read-only (get-pool-type-implementations (pool-type (string-ascii 32)))
  (map-get? pool-type-implementations { pool-type: pool-type }))

(define-read-only (get-default-implementation (pool-type (string-ascii 32)))
  (match (get-pool-type-implementations pool-type)
    types (ok (get types default-impl))
    none (ok u0)
  )
)

(define-read-only (get-implementation-stats (impl-id uint))
  (map-get? implementation-stats { impl-id: impl-id }))

(define-read-only (is-registry-active)
  (var-get registry-active))

(define-read-only (get-total-implementations)
  (var-get total-implementations))

(define-read-only (get-total-factories)
  (var-get total-factories)
)

;; Public functions

(define-public (register-implementation 
  (name (string-ascii 64)) 
  (version (string-ascii 16)) 
  (contract-address principal) 
  (factory-address principal)
  (pool-type (string-ascii 32))
  (features (list 10 (string-ascii 32)))
  (min-liquidity uint)
  (max-liquidity uint)
  (fee-tier uint)
)
  (begin
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> (len version) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (principal? contract-address) ERR_INVALID_IMPLEMENTATION)
    (asserts! (principal? factory-address) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> (len pool-type) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> min-liquidity u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (> max-liquidity min-liquidity) ERR_INVALID_IMPLEMENTATION)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if implementation already exists
    (asserts! (not (implementation-exists name version)) ERR_IMPLEMENTATION_EXISTS)
    
    ;; Generate implementation ID
    (let ((impl-id (+ (var-get total-implementations) u1)))
      
      ;; Register implementation
      (map-set pool-implementations { impl-id: impl-id } {
        name: name,
        version: version,
        contract-address: contract-address,
        factory-address: factory-address,
        pool-type: pool-type,
        features: features,
        min-liquidity: min-liquidity,
        max-liquidity: max-liquidity,
        fee-tier: fee-tier,
        active: true,
        registration-time: block-height,
        registration-fee: REGISTRATION_FEE
      })
      
      ;; Update factory registration
      (map-set factory-registrations { factory: factory-address } {
        impl-id: impl-id,
        pool-type: pool-type,
        authorized: true,
        registration-time: block-height,
        total-pools-created: u0
      })
      
      ;; Update implementation factories
      (map-set implementation-factories { impl-id: impl-id } {
        factories: (list factory-address),
        primary-factory: factory-address
      })
      
      ;; Update pool type implementations
      (let ((current-types (get-pool-type-implementations pool-type)))
        (if (is-some current-types)
            (begin
              (let ((types (unwrap-optional current-types)))
                (map-set pool-type-implementations { pool-type: pool-type } {
                  implementations: (append (get types implementations) impl-id),
                  default-impl: (if (is-eq (get types default-impl) u0) impl-id (get types default-impl))
                })
              )
            )
            (map-set pool-type-implementations { pool-type: pool-type } {
              implementations: (list impl-id),
              default-impl: impl-id
            })
        )
      )
      
      ;; Initialize stats
      (map-set implementation-stats { impl-id: impl-id } {
        total-pools: u0,
        total-volume: u0,
        total-fees: u0,
        average-utilization: u0,
        last-update: block-height
      })
      
      ;; Update totals
      (var-set total-implementations (+ (var-get total-implementations) u1))
      (var-set total-factories (+ (var-get total-factories) u1))
      
      ;; Emit event
      (emit-event (implementation-registered impl-id name contract-address))
      
      (ok impl-id)
    )
  )
)

(define-public (register-additional-factory (impl-id uint) (factory-address principal))
  (begin
    ;; Validate inputs
    (asserts! (principal? factory-address) ERR_INVALID_FACTORY)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if implementation exists
    (let ((impl-info (get-implementation impl-id)))
      (asserts! (is-some impl-info) ERR_IMPLEMENTATION_NOT_FOUND)
      
      (let ((impl (unwrap-optional impl-info)))
        ;; Check if factory is already registered
        (asserts! (not (is-factory-authorized factory-address)) ERR_IMPLEMENTATION_EXISTS)
        
        ;; Update factory registration
        (map-set factory-registrations { factory: factory-address } {
          impl-id: impl-id,
          pool-type: (get impl pool-type),
          authorized: true,
          registration-time: block-height,
          total-pools-created: u0
        })
        
        ;; Update implementation factories
        (let ((current-factories (implementation-factories impl-id)))
          (map-set implementation-factories { impl-id: impl-id } {
            factories: (append (get current-factories factories) factory-address),
            primary-factory: (get current-factories primary-factory)
          })
        )
        
        ;; Update totals
        (var-set total-factories (+ (var-get total-factories) u1))
        
        ;; Emit event
        (emit-event (factory-registered factory-address impl-id))
        
        (ok true)
      )
    )
  )
)

(define-public (deactivate-implementation (impl-id uint))
  (begin
    ;; Validate inputs
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if implementation exists
    (let ((impl-info (get-implementation impl-id)))
      (asserts! (is-some impl-info) ERR_IMPLEMENTATION_NOT_FOUND)
      
      (let ((impl (unwrap-optional impl-info)))
        ;; Deactivate implementation
        (map-set pool-implementations { impl-id: impl-id } {
          name: (get impl name),
          version: (get impl version),
          contract-address: (get impl contract-address),
          factory-address: (get impl factory-address),
          pool-type: (get impl pool-type),
          features: (get impl features),
          min-liquidity: (get impl min-liquidity),
          max-liquidity: (get impl max-liquidity),
          fee-tier: (get impl fee-tier),
          active: false,
          registration-time: (get impl registration-time),
          registration-fee: (get impl registration-fee)
        })
        
        ;; Update default implementation if needed
        (let ((pool-type-impls (get-pool-type-implementations (get impl pool-type))))
          (if (is-some pool-type-impls)
              (begin
                (let ((types (unwrap-optional pool-type-impls)))
                  (if (is-eq (get types default-impl) impl-id)
                      (begin
                        ;; Find new default
                        (let ((active-impls (filter-active-implementations (get types implementations))))
                          (if (> (len active-impls) u0)
                              (map-set pool-type-implementations { pool-type: (get impl pool-type) } {
                                implementations: (get types implementations),
                                default-impl: (get active-impls u0)
                              })
                              (map-set pool-type-implementations { pool-type: (get impl pool-type) } {
                                implementations: (get types implementations),
                                default-impl: u0
                              })
                          )
                        )
                      )
                      true
                  )
                )
                true
            )
        )
        
        ;; Emit event
        (emit-event (implementation-deactivated impl-id))
        
        (ok true)
      )
    )
  )
)

(define-public (set-default-implementation (pool-type (string-ascii 32)) (impl-id uint))
  (begin
    ;; Validate inputs
    (asserts! (> (len pool-type) u0) ERR_INVALID_IMPLEMENTATION)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if implementation exists and is active
    (let ((impl-info (get-implementation impl-id)))
      (asserts! (is-some impl-info) ERR_IMPLEMENTATION_NOT_FOUND)
      
      (let ((impl (unwrap-optional impl-info)))
        (asserts! (get impl active) ERR_IMPLEMENTATION_NOT_FOUND)
        (asserts! (is-eq (get impl pool-type) pool-type) ERR_INVALID_IMPLEMENTATION)
        
        ;; Update pool type implementations
        (let ((current-types (get-pool-type-implementations pool-type)))
          (if (is-some current-types)
              (begin
                (let ((types (unwrap-optional current-types)))
                  (map-set pool-type-implementations { pool-type: pool-type } {
                    implementations: (get types implementations),
                    default-impl: impl-id
                  })
                )
              )
              (map-set pool-type-implementations { pool-type: pool-type } {
                implementations: (list impl-id),
                default-impl: impl-id
              })
          )
        )
        
        ;; Emit event
        (emit-event (default-implementation-updated pool-type (get-optional (get-default-implementation pool-type)) impl-id))
        
        (ok true)
      )
    )
  )
)

(define-public (record-pool-creation (impl-id uint) (pool principal) (factory principal))
  (begin
    ;; Validate inputs
    (asserts! (principal? pool) ERR_INVALID_IMPLEMENTATION)
    (asserts! (principal? factory) ERR_INVALID_FACTORY)
    
    ;; Check if factory is authorized
    (asserts! (is-factory-authorized factory) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Update factory stats
    (let ((factory-reg (get-factory-registration factory)))
      (if (is-some factory-reg)
          (map-set factory-registrations { factory: factory } {
            impl-id: (get-optional factory-reg).impl-id,
            pool-type: (get-optional factory-reg).pool-type,
            authorized: (get-optional factory-reg).authorized,
            registration-time: (get-optional factory-reg).registration-time,
            total-pools-created: (+ (get-optional factory-reg).total-pools-created u1)
          })
          true
      )
    )
    
    ;; Update implementation stats
    (let ((impl-stats (get-implementation-stats impl-id)))
      (if (is-some impl-stats)
          (map-set implementation-stats { impl-id: impl-id } {
            total-pools: (+ (get-optional impl-stats).total-pools u1),
            total-volume: (get-optional impl-stats).total-volume,
            total-fees: (get-optional impl-stats).total-fees,
            average-utilization: (get-optional impl-stats).average-utilization,
            last-update: block-height
          })
          (map-set implementation-stats { impl-id: impl-id } {
            total-pools: u1,
            total-volume: u0,
            total-fees: u0,
            average-utilization: u0,
            last-update: block-height
          })
      )
    )
    
    ;; Emit event
    (emit-event (pool-created impl-id pool factory))
    
    (ok true)
  )
)

(define-public (update-implementation-stats (impl-id uint) (volume uint) (fees uint) (utilization uint))
  (begin
    ;; Validate inputs
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if implementation exists
    (let ((impl-stats (get-implementation-stats impl-id)))
      (if (is-some impl-stats)
          (begin
            (let ((stats (unwrap-optional impl-stats))
                  (total-pools (get stats total-pools)))
              
              ;; Update stats with weighted average
              (map-set implementation-stats { impl-id: impl-id } {
                total-pools: total-pools,
                total-volume: (+ (get stats total-volume) volume),
                total-fees: (+ (get stats total-fees) fees),
                average-utilization: (/ (+ (* (get stats average-utilization) total-pools) utilization) (+ total-pools u1)),
                last-update: block-height
              })
            )
          )
          (map-set implementation-stats { impl-id: impl-id } {
            total-pools: u1,
            total-volume: volume,
            total-fees: fees,
            average-utilization: utilization,
            last-update: block-height
          })
      )
    )
    
    (ok true)
  )
)

(define-public (cleanup-registry)
  (begin
    ;; Only admin can cleanup
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Remove inactive implementations with no pools
    (let ((cleaned-count u0))
      ;; This would iterate through all implementations and remove inactive ones
      ;; Simplified implementation
      
      ;; Update last cleanup time
      (var-set last-cleanup block-height)
      
      ;; Emit event
      (emit-event (registry-cleanup cleaned-count))
      
      (ok cleaned-count)
    )
  )
)

;; Private helper functions

(define-private (implementation-exists (name (string-ascii 64)) (version (string-ascii 16)))
  (begin
    ;; Check if implementation with same name and version exists
    ;; Simplified implementation
    false
  )
)

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { implementations: (list 0 uint), default-impl: u0 } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (filter-active-implementations (impl-ids (list 10 uint)))
  (begin
    ;; Filter active implementations
    ;; Simplified implementation
    impl-ids
  )
)

;; Admin functions

(define-public (set-registry-active (active bool))
  (begin
    ;; Only admin can set registry status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_REGISTRATION)
    
    (var-set registry-active active)
    (ok true)
  )
)

(define-public (emergency-remove-implementation (impl-id uint))
  (begin
    ;; Only admin can emergency remove
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Remove implementation
    (map-delete pool-implementations { impl-id: impl-id })
    (map-delete implementation-stats { impl-id: impl-id })
    (map-delete implementation-factories { impl-id: impl-id })
    
    ;; Update totals
    (var-set total-implementations (- (var-get total-implementations) u1))
    
    (ok true)
  )
)

;; Query functions

(define-read-only (get-implementations-by-type (pool-type (string-ascii 32)))
  (match (get-pool-type-implementations pool-type)
    types (ok (get types implementations))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-factories-by-implementation (impl-id uint))
  (match (implementation-factories impl-id)
    factories (ok (get factories factories))
    none (ok (list 0 principal))
  )
)

(define-read-only (get-registry-summary)
  {
    active: (var-get registry-active),
    total-implementations: (var-get total-implementations),
    total-factories: (var-get total-factories),
    last-cleanup: (var-get last-cleanup)
  }
)
