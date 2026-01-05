;; pool-type-registry.clar
;; Conxian DEX: Registry for pool types and their characteristics

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVALID_POOL_TYPE (err 24001))
(define-constant ERR_POOL_TYPE_EXISTS (err 24002))
(define-constant ERR_POOL_TYPE_NOT_FOUND (err 24003))
(define-constant ERR_UNAUTHORIZED_REGISTRATION (err 24004))
(define-constant ERR_INVALID_FEATURES (err 24005))

;; Registry parameters
(define-constant MAX_POOL_TYPES u50)
(define-constant MAX_FEATURES_PER_TYPE u20)
(define-constant REGISTRATION_FEE u500000) ;; 0.5 STX equivalent
(define-constant MIN_POOLS_PER_TYPE u1)
(define-constant MAX_POOLS_PER_TYPE u1000

;; Data variables
(define-data-var registry-active bool true)
(define-data-var total-pool-types uint u0)
(define-data-var last-cleanup uint u0)

;; Storage maps
(define-map pool-types { type-id: uint } { 
  name: (string-ascii 64),
  description: (string-ascii 256),
  category: (string-ascii 32),
  features: (list 20 (string-ascii 32)),
  requirements: (list 10 (string-ascii 64)),
  min-liquidity: uint,
  max-liquidity: uint,
  fee-range: { min-fee: uint, max-fee: uint },
  supported-tokens: (list 20 principal),
  active: bool,
  registration-time: uint,
  registration-fee: uint
})

(define-map type-categories { category: (string-ascii 32) } { 
  types: (list 10 uint),
  description: (string-ascii 256),
  active: bool
})

(define-map pool-type-stats { type-id: uint } { 
  total-pools: uint,
  total-liquidity: uint,
  total-volume: uint,
  average-fee: uint,
  success-rate: uint,
  last-update: uint
})

(define-map type-features { feature: (string-ascii 32) } { 
  types: (list 20 uint),
  description: (string-ascii 256),
  category: (string-ascii 16)
})

(define-map token-type-support { token: principal } { 
  supported-types: (list 10 uint),
  last-verified: uint
})

;; Events
(define-event (pool-type-registered (type-id uint) (name (string-ascii 64)) (category (string-ascii 32))))
(define-event (pool-type-deactivated (type-id uint)))
(define-event (category-created (category (string-ascii 32))))
(define-event (feature-added (type-id uint) (feature (string-ascii 32))))
(define-event (token-support-updated (token principal) (type-id uint)))
(define-event (registry-cleanup (types-removed uint)))

;; Read-only functions

(define-read-only (get-pool-type (type-id uint))
  (map-get? pool-types { type-id: type-id }))

(define-read-only (get-pool-type-name (type-id uint))
  (match (get-pool-type type-id)
    type (ok (get type name))
    none (ok "")
  )
)

(define-read-only (get-pool-type-category (type-id uint))
  (match (get-pool-type type_id)
    type (ok (get type category))
    none (ok "")
  )
)

(define-read-only (get-pool-type-features (type-id uint))
  (match (get-pool-type type_id)
    type (ok (get type features))
    none (ok (list 0 (string-ascii 32)))
  )
)

(define-read-only (get-pool-type-requirements (type_id uint))
  (match (get-pool-type type_id)
    type (ok (get type requirements))
    none (ok (list 0 (string-ascii 64)))
  )
)

(define-read-only (get-pool-type-fee-range (type_id uint))
  (match (get-pool-type type_id)
    type (ok (get type fee-range))
    none (ok { min-fee: u0, max-fee: u10000 })
  )
)

(define-read-only (get-pool-type-supported-tokens (type_id uint))
  (match (get-pool-type type_id)
    type (ok (get type supported-tokens))
    none (ok (list 0 principal))
  )
)

(define-read-only (is-pool-type-active (type_id uint))
  (match (get-pool-type type_id)
    type (ok (get type active))
    none (ok false)
  )
)

(define-read-only (get-category-info (category (string-ascii 32)))
  (map-get? type-categories { category: category }))

(define-read-only (get-category-types (category (string-ascii 32)))
  (match (get-category-info category)
    cat (ok (get cat types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-feature-info (feature (string-ascii 32)))
  (map-get? type-features { feature: feature }))

(define-read-only (get-feature-types (feature (string-ascii 32)))
  (match (get-feature-info feature)
    feature (ok (get feature types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-token-support (token principal))
  (map-get? token-type-support { token: token }))

(define-read-only (get-token-supported-types (token principal))
  (match (get-token-support token))
    support (ok (get support supported-types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-pool-type-stats (type_id uint))
  (map-get? pool-type-stats { type_id: type_id }))

(define-read-only (is-registry-active)
  (var-get registry-active))

(define-read-only (get-total-pool-types)
  (var-get total-pool-types))

;; Public functions

(define-public (register-pool-type 
  (name (string-ascii 64)) 
  (description (string-ascii 256)) 
  (category (string-ascii 32))
  (features (list 20 (string-ascii 32)))
  (requirements (list 10 (string-ascii 64)))
  (min-liquidity uint)
  (max-liquidity uint)
  (min-fee uint)
  (max-fee uint)
  (supported-tokens (list 20 principal))
)
  (begin
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR_INVALID_POOL_TYPE)
    (asserts! (> (len description) u0) ERR_INVALID_POOL_TYPE)
    (asserts! (> (len category) u0) ERR_INVALID_POOL_TYPE)
    (asserts! (> min-liquidity u0) ERR_INVALID_POOL_TYPE)
    (asserts! (> max-liquidity min-liquidity) ERR_INVALID_POOL_TYPE)
    (asserts! (>= max-fee min-fee) ERR_INVALID_POOL_TYPE)
    (asserts! (<= max-fee u10000) ERR_INVALID_POOL_TYPE)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if pool type already exists
    (asserts! (not (pool-type-exists name category)) ERR_POOL_TYPE_EXISTS)
    
    ;; Validate features
    (asserts! (validate-features features) ERR_INVALID_FEATURES)
    
    ;; Generate type ID
    (let ((type-id (+ (var-get total-pool-types) u1)))
      
      ;; Register pool type
      (map-set pool-types { type-id: type-id } {
        name: name,
        description: description,
        category: category,
        features: features,
        requirements: requirements,
        min-liquidity: min-liquidity,
        max-liquidity: max-liquidity,
        fee-range: { min-fee: min-fee, max-fee: max-fee },
        supported-tokens: supported-tokens,
        active: true,
        registration-time: block-height,
        registration-fee: REGISTRATION_FEE
      })
      
      ;; Update category
      (let ((category-info (get-category-info category)))
        (if (is-some category-info)
            (begin
              (let ((cat (unwrap-optional category-info)))
                (map-set type-categories { category: category } {
                  types: (append (get cat types) type-id),
                  description: (get cat description),
                  active: (get cat active)
                })
              )
            )
            (map-set type-categories { category: category } {
              types: (list type-id),
              description: (concat "Category for " category),
              active: true
            })
        )
      )
      
      ;; Update feature mappings
      (fold features u0
        (lambda ((result uint) (feature (string-ascii 32)))
          (let ((feature-info (get-feature-info feature)))
            (if (is-some feature-info)
                (begin
                  (let ((feat (unwrap-optional feature-info)))
                    (map-set type-features { feature: feature } {
                      types: (append (get feat types) type-id),
                      description: (get feat description),
                      category: (get feat category)
                    })
                  )
                )
                (map-set type-features { feature: feature } {
                  types: (list type-id),
                  description: (concat "Feature " feature),
                  category: "general"
                })
            )
            (+ result u1)
          )
        )
      )
      
      ;; Update token support mappings
      (fold supported-tokens u0
        (lambda ((result uint) (token principal))
          (let ((token-support (get-token-support token)))
            (if (is-some token-support)
                (begin
                  (let ((support (unwrap-optional token-support)))
                    (map-set token-type-support { token: token } {
                      supported-types: (append (get support supported-types) type-id),
                      last-verified: block-height
                    })
                  )
                )
                (map-set token-type-support { token: token } {
                  supported-types: (list type-id),
                  last-verified: block-height
                })
            )
            (+ result u1)
          )
        )
      )
      
      ;; Initialize stats
      (map-set pool-type-stats { type-id: type-id } {
        total-pools: u0,
        total-liquidity: u0,
        total-volume: u0,
        average-fee: min-fee,
        success-rate: u10000,
        last-update: block-height
      })
      
      ;; Update totals
      (var-set total-pool-types (+ (var-get total-pool-types) u1))
      
      ;; Emit event
      (emit-event (pool-type-registered type-id name category))
      
      (ok type-id)
    )
  )
)

(define-public (add-feature-to-type (type-id uint) (feature (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len feature) u0) ERR_INVALID_FEATURES)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if pool type exists
    (let ((type-info (get-pool-type type_id)))
      (asserts! (is-some type_info) ERR_POOL_TYPE_NOT_FOUND)
      
      (let ((pool-type (unwrap-optional type_info)))
        ;; Check if feature already exists
        (let ((current-features (get pool-type features)))
          (asserts! (not (has-feature current-features feature)) ERR_INVALID_FEATURES)
          
          ;; Update pool type features
          (map-set pool-types { type-id: type_id } {
            name: (get pool-type name),
            description: (get pool-type description),
            category: (get pool-type category),
            features: (append current-features feature),
            requirements: (get pool-type requirements),
            min-liquidity: (get pool-type min-liquidity),
            max-liquidity: (get pool-type max-liquidity),
            fee-range: (get pool-type fee-range),
            supported-tokens: (get pool-type supported-tokens),
            active: (get pool-type active),
            registration-time: (get pool-type registration-time),
            registration-fee: (get pool-type registration-fee)
          })
          
          ;; Update feature mapping
          (let ((feature-info (get-feature-info feature)))
            (if (is-some feature-info)
                (begin
                  (let ((feat (unwrap-optional feature_info)))
                    (map-set type-features { feature: feature } {
                      types: (append (get feat types) type-id),
                      description: (get feat description),
                      category: (get feat category)
                    })
                  )
                )
                (map-set type-features { feature: feature } {
                  types: (list type-id),
                  description: (concat "Feature " feature),
                  category: "general"
                })
            )
          )
          
          ;; Emit event
          (emit-event (feature-added type_id feature))
          
          (ok true)
        )
      )
    )
  )
)

(define-public (update-token-support (type_id uint) (token principal) (supported bool))
  (begin
    ;; Validate inputs
    (asserts! (principal? token) ERR_INVALID_POOL_TYPE)
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if pool type exists
    (let ((type_info (get-pool-type type_id)))
      (asserts! (is-some type_info) ERR_POOL_TYPE_NOT_FOUND)
      
      (let ((pool-type (unwrap-optional type_info)))
        ;; Update token support
        (let ((token-support (get-token-support token)))
          (if supported
              (begin
                ;; Add support
                (if (is-some token-support)
                    (begin
                      (let ((support (unwrap-optional token-support)))
                        (map-set token-type-support { token: token } {
                          supported-types: (append (get support supported-types) type_id),
                          last-verified: block-height
                        })
                      )
                    )
                    (map-set token-type-support { token: token } {
                      supported-types: (list type_id),
                      last-verified: block-height
                    })
                )
                
                ;; Update pool type supported tokens
                (let ((current-tokens (get pool-type supported-tokens)))
                  (if (not (has-token current-tokens token))
                      (map-set pool-types { type-id: type_id } {
                        name: (get pool-type name),
                        description: (get pool-type description),
                        category: (get pool-type category),
                        features: (get pool-type features),
                        requirements: (get pool-type requirements),
                        min-liquidity: (get pool-type min-liquidity),
                        max-liquidity: (get pool-type max-liquidity),
                        fee-range: (get pool-type fee-range),
                        supported-tokens: (append current-tokens token),
                        active: (get pool-type active),
                        registration-time: (get pool-type registration-time),
                        registration-fee: (get pool-type registration-fee)
                      })
                  )
                  true
                )
              )
              (begin
                ;; Remove support
                (if (is-some token-support)
                    (begin
                      (let ((support (unwrap-optional token-support)))
                        (map-set token-type-support { token: token } {
                          supported-types: (remove-from-list (get support supported-types) type_id),
                          last-verified: block-height
                        })
                      )
                    )
                    true
                )
                
                ;; Update pool type supported tokens
                (let ((current-tokens (get pool-type supported-tokens)))
                  (if (has-token current-tokens token)
                      (map-set pool-types { type-id: type_id } {
                        name: (get pool-type name),
                        description: (get pool-type description),
                        category: (get pool-type category),
                        features: (get pool-type features),
                        requirements: (get pool-type requirements),
                        min-liquidity: (get pool-type min-liquidity),
                        max-liquidity: (get pool-type max-liquidity),
                        fee-range: (get pool-type fee-range),
                        supported-tokens: (remove-from-list current-tokens token),
                        active: (get pool-type active),
                        registration-time: (get pool-type registration-time),
                        registration-fee: (get pool-type registration-fee)
                      })
                  )
                  true
                )
              )
          )
          
          ;; Emit event
          (emit-event (token-support-updated token type_id))
          
          (ok true)
        )
      )
    )
  )
)

(define-public (deactivate-pool-type (type_id uint))
  (begin
    ;; Validate inputs
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if pool type exists
    (let ((type_info (get-pool-type type_id)))
      (asserts! (is-some type_info) ERR_POOL_TYPE_NOT_FOUND)
      
      (let ((pool-type (unwrap-optional type_info)))
        ;; Deactivate pool type
        (map-set pool-types { type-id: type_id } {
          name: (get pool-type name),
          description: (get pool-type description),
          category: (get pool-type category),
          features: (get pool-type features),
          requirements: (get pool-type requirements),
          min-liquidity: (get pool-type min-liquidity),
          max-liquidity: (get pool-type max-liquidity),
          fee-range: (get pool-type fee-range),
          supported-tokens: (get pool-type supported-tokens),
          active: false,
          registration-time: (get pool-type registration-time),
          registration-fee: (get pool-type registration-fee)
        })
        
        ;; Emit event
        (emit-event (pool-type-deactivated type_id))
        
        (ok true)
      )
    )
  )
)

(define-public (update-pool-type-stats (type_id uint) (pools uint) (liquidity uint) (volume uint) (fee uint))
  (begin
    ;; Validate inputs
    (asserts! (var-get registry-active) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Check if pool type exists
    (let ((stats (get-pool-type-stats type_id)))
      (if (is-some stats)
          (begin
            (let ((current-stats (unwrap-optional stats))
                  (total-pools (get current-stats total-pools)))
              
              ;; Update stats with weighted averages
              (map-set pool-type-stats { type-id: type_id } {
                total-pools: (+ total-pools pools),
                total-liquidity: (+ (get current-stats total-liquidity) liquidity),
                total-volume: (+ (get current-stats total-volume) volume),
                average-fee: (/ (+ (* (get current-stats average-fee) total-pools) fee) (+ total-pools pools)),
                success-rate: (get current-stats success-rate),
                last-update: block-height
              })
            )
          )
          (map-set pool-type-stats { type-id: type_id } {
            total-pools: pools,
            total-liquidity: liquidity,
            total-volume: volume,
            average-fee: fee,
            success-rate: u10000,
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
    
    ;; Remove inactive pool types with no pools
    (let ((cleaned-count u0))
      ;; This would iterate through all pool types and remove inactive ones
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

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { types: (list 0 uint), description: (string-ascii 256), active: bool } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (pool-type-exists (name (string-ascii 64)) (category (string-ascii 32)))
  (begin
    ;; Check if pool type with same name and category exists
    ;; Simplified implementation
    false
  )
)

(define-private (validate-features (features (list 20 (string-ascii 32))))
  (begin
    ;; Validate features list
    (and (<= (len features) MAX_FEATURES_PER_TYPE)
         (fold features true
           (lambda ((valid bool) (feature (string-ascii 32)))
             (and valid (> (len feature) u0))
           )
         )
    )
  )
)

(define-private (has-feature (features (list 20 (string-ascii 32))) (feature (string-ascii 32)))
  (begin
    ;; Check if feature exists in list
    (fold features false
      (lambda ((found bool) (current-feature (string-ascii 32)))
        (or found (is-eq current-feature feature))
      )
    )
  )
)

(define-private (has-token (tokens (list 20 principal)) (token principal))
  (begin
    ;; Check if token exists in list
    (fold tokens false
      (lambda ((found bool) (current-token principal))
        (or found (is-eq current-token token))
      )
    )
  )
)

(define-private (remove-from-list (list (list 20 principal)) (item principal))
  (begin
    ;; Remove item from list
    (fold list (list 0 principal)
      (lambda ((result (list 20 principal)) (current-item principal))
        (if (is-eq current-item item)
            result
            (append result current-item)
        )
      )
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

(define-public (create-category (category (string-ascii 32)) (description (string-ascii 256)))
  (begin
    ;; Only admin can create categories
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Create category
    (map-set type-categories { category: category } {
      types: (list 0 uint),
      description: description,
      active: true
    })
    
    ;; Emit event
    (emit-event (category-created category))
    
    (ok true)
  )
)

(define-public (emergency-remove-pool-type (type_id uint))
  (begin
    ;; Only admin can emergency remove
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_REGISTRATION)
    
    ;; Remove pool type
    (map-delete pool-types { type-id: type_id })
    (map-delete pool-type-stats { type-id: type_id })
    
    (ok true)
  )
)

;; Query functions

(define-read-only (get-pool-types-by-category (category (string-ascii 32)))
  (match (get-category-info category)
    cat (ok (get cat types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-pool-types-by-feature (feature (string-ascii 32)))
  (match (get-feature-info feature)
    feat (ok (get feat types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-pool-types-supporting-token (token principal))
  (match (get-token-support token))
    support (ok (get support supported-types))
    none (ok (list 0 uint))
  )
)

(define-read-only (get-registry-summary)
  {
    active: (var-get registry-active),
    total-types: (var-get total-pool-types),
    last-cleanup: (var-get last-cleanup)
  }
)
