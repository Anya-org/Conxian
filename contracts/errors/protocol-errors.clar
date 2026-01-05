;; protocol-errors.clar
;; Conxian Protocol: Centralized error code definitions and error handling utilities

;; Constants
(define-constant ERR_BASE u28000) ;; Base error code for protocol errors

;; Core Protocol Errors (28000-28099)
(define-constant ERR_PROTOCOL_NOT_INITIALIZED (err (+ ERR_BASE u0)))
(define-constant ERR_PROTOCOL_PAUSED (err (+ ERR_BASE u1)))
(define-constant ERR_PROTOCOL_SHUTDOWN (err (+ ERR_BASE u2)))
(define-constant ERR_INVALID_PROTOCOL_VERSION (err (+ ERR_BASE u3)))
(define-constant ERR_PROTOCOL_MIGRATION_REQUIRED (err (+ ERR_BASE u4)))

;; Access Control Errors (28100-28199)
(define-constant ERR_UNAUTHORIZED_ACCESS (err (+ ERR_BASE u100)))
(define-constant ERR_INSUFFICIENT_PERMISSIONS (err (+ ERR_BASE u101)))
(define-constant ERR_ROLE_NOT_FOUND (err (+ ERR_BASE u102)))
(define-constant ERR_ROLE_ALREADY_ASSIGNED (err (+ ERR_BASE u103)))
(define-constant ERR_ACCESS_DENIED (err (+ ERR_BASE u104)))
(define-constant ERR_INVALID_SIGNATURE (err (+ ERR_BASE u105)))
(define-constant ERR_EXPIRED_SIGNATURE (err (+ ERR_BASE u106)))
(define-constant ERR_INVALID_PRINCIPAL (err (+ ERR_BASE u107)))

;; Token Errors (28200-28299)
(define-constant ERR_TOKEN_NOT_FOUND (err (+ ERR_BASE u200)))
(define-constant ERR_INVALID_TOKEN_AMOUNT (err (+ ERR_BASE u201)))
(define-constant ERR_INSUFFICIENT_BALANCE (err (+ ERR_BASE u202)))
(define-constant ERR_INSUFFICIENT_ALLOWANCE (err (+ ERR_BASE u203)))
(define-constant ERR_TOKEN_TRANSFER_FAILED (err (+ ERR_BASE u204)))
(define-constant ERR_INVALID_TOKEN_CONTRACT (err (+ ERR_BASE u205)))
(define-constant ERR_TOKEN_FROZEN (err (+ ERR_BASE u206)))
(define-constant ERR_TOKEN_MINT_LIMIT_EXCEEDED (err (+ ERR_BASE u207)))

;; Pool Errors (28300-28399)
(define-constant ERR_POOL_NOT_FOUND (err (+ ERR_BASE u300)))
(define-constant ERR_POOL_ALREADY_EXISTS (err (+ ERR_BASE u301)))
(define-constant ERR_INSUFFICIENT_POOL_LIQUIDITY (err (+ ERR_BASE u302)))
(define-constant ERR_INVALID_POOL_TYPE (err (+ ERR_BASE u303)))
(define-constant ERR_POOL_NOT_ACTIVE (err (+ ERR_BASE u304)))
(define-constant ERR_POOL_CAPACITY_EXCEEDED (err (+ ERR_BASE u305)))
(define-constant ERR_INVALID_POOL_PAIR (err (+ ERR_BASE u306)))
(define-constant ERR_POOL_CREATION_FAILED (err (+ ERR_BASE u307)))

;; Trading Errors (28400-28499)
(define-constant ERR_INVALID_TRADE_AMOUNT (err (+ ERR_BASE u400)))
(define-constant ERR_TRADE_WOULD_EXCEED_LIMIT (err (+ ERR_BASE u401)))
(define-constant ERR_PRICE_IMPACT_TOO_HIGH (err (+ ERR_BASE u402)))
(define-constant ERR_SLIPPAGE_EXCEEDED (err (+ ERR_BASE u403)))
(define-constant ERR_TRADE_FAILED (err (+ ERR_BASE u404)))
(define-constant ERR_INSUFFICIENT_OUTPUT (err (+ ERR_BASE u405)))
(define-constant ERR_INVALID_TRADE_PAIR (err (+ ERR_BASE u406)))
(define-constant ERR_TRADE_TIMEOUT (err (+ ERR_BASE u407)))

;; Oracle Errors (28500-28599)
(define-constant ERR_ORACLE_NOT_AVAILABLE (err (+ ERR_BASE u500)))
(define-constant ERR_ORACLE_DATA_STALE (err (+ ERR_BASE u501)))
(define-constant ERR_INVALID_ORACLE_PRICE (err (+ ERR_BASE u502)))
(define-constant ERR_ORACLE_FEED_NOT_FOUND (err (+ ERR_BASE u503)))
(define-constant ERR_ORACLE_CONFIDENCE_LOW (err (+ ERR_BASE u504)))
(define-constant ERR_ORACLE_VERIFICATION_FAILED (err (+ ERR_BASE u505)))
(define-constant ERR_ORACLE_TIMEOUT (err (+ ERR_BASE u506)))

;; Math Errors (28600-28699)
(define-constant ERR_MATH_OVERFLOW (err (+ ERR_BASE u600)))
(define-constant ERR_MATH_UNDERFLOW (err (+ ERR_BASE u601)))
(define-constant ERR_DIVISION_BY_ZERO (err (+ ERR_BASE u602)))
(define-constant ERR_INVALID_PRECISION (err (+ ERR_BASE u603)))
(define-constant ERR_CALCULATION_FAILED (err (+ ERR_BASE u604)))
(define-constant ERR_INVALID_INPUT (err (+ ERR_BASE u605)))
(define-constant ERR_PRECISION_LOSS (err (+ ERR_BASE u606)))

;; State Errors (28700-28799)
(define-constant ERR_STATE_INVALID (err (+ ERR_BASE u700)))
(define-constant ERR_STATE_TRANSITION_INVALID (err (+ ERR_BASE u701)))
(define-constant ERR_STATE_LOCKED (err (+ ERR_BASE u702)))
(define-constant ERR_STATE_NOT_READY (err (+ ERR_BASE u703)))
(define-constant ERR_STATE_CORRUPTED (err (+ ERR_BASE u704)))
(define-constant ERR_STATE_MIGRATION_FAILED (err (+ ERR_BASE u705)))

;; Configuration Errors (28800-28899)
(define-constant ERR_INVALID_CONFIGURATION (err (+ ERR_BASE u800)))
(define-constant ERR_CONFIG_NOT_FOUND (err (+ ERR_BASE u801)))
(define-constant ERR_CONFIG_UPDATE_FAILED (err (+ ERR_BASE u802)))
(define-constant ERR_INVALID_PARAMETER (err (+ ERR_BASE u803)))
(define-constant ERR_PARAMETER_OUT_OF_RANGE (err (+ ERR_BASE u804)))
(define-constant ERR_REQUIRED_PARAMETER_MISSING (err (+ ERR_BASE u805)))

;; System Errors (28900-28999)
(define-constant ERR_SYSTEM_OVERLOADED (err (+ ERR_BASE u900)))
(define-constant ERR_SYSTEM_MAINTENANCE (err (+ ERR_BASE u901)))
(define-constant ERR_SYSTEM_SHUTDOWN (err (+ ERR_BASE u902)))
(define-constant ERR_RATE_LIMIT_EXCEEDED (err (+ ERR_BASE u903)))
(define-constant ERR_RESOURCE_EXHAUSTED (err (+ ERR_BASE u904)))
(define-constant ERR_SYSTEM_ERROR (err (+ ERR_BASE u905)))

;; Data variables
(define-data-var error-reporting-enabled bool true)
(define-data-var total-errors-reported uint u0)
(define-data-var error-threshold uint u1000) ;; Alert after 1000 errors

;; Storage maps
(define-map error-reports { error-id: (buff 32) } { 
  error-code: uint,
  error-message: (string-ascii 256),
  contract: principal,
  function: (string-ascii 64),
  timestamp: uint,
  severity: (string-ascii 16),
  resolved: bool,
  resolution: (optional (string-ascii 256))
})

(define-map error-categories { category: (string-ascii 32) } { 
  total-errors: uint,
  last-error: uint,
  severity: (string-ascii 16),
  active: bool
})

(define-map error-statistics { contract: principal } { 
  total-errors: uint,
  error-types: (list 10 { code: uint, count: uint }),
  last-error: uint,
  error-rate: uint
})

(define-map error-resolutions { error-code: uint } { 
  resolution: (string-ascii 256),
  automated-fix: bool,
  success-rate: uint,
  last-applied: uint
})

;; Events
(define-event (error-reported (error-id (buff 32)) (error-code uint) (severity (string-ascii 16))))
(define-event (error-resolved (error-id (buff 32)) (resolution (string-ascii 256))))
(define-event (error-threshold-exceeded (category (string-ascii 32)) (count uint)))
(define-event (error-escalated (error-id (buff 32)) (severity (string-ascii 16))))

;; Read-only functions

(define-read-only (get-error-report (error-id (buff 32)))
  (map-get? error-reports { error-id: error-id }))

(define-read-only (get-error-category (category (string-ascii 32)))
  (map-get? error-categories { category: category }))

(define-read-only (get-error-statistics (contract principal))
  (map-get? error-statistics { contract: contract }))

(define-read-only (get-error-resolution (error-code uint))
  (map-get? error-resolutions { error-code: error-code }))

(define-read-only (is-error-reporting-enabled)
  (var-get error-reporting-enabled))

(define-read-only (get-total-errors-reported)
  (var-get total-errors-reported))

(define-read-only (get-error-threshold)
  (var-get error-threshold))

;; Public functions

(define-public (report-error 
  (error-code uint) 
  (error-message (string-ascii 256)) 
  (contract principal) 
  (function-name (string-ascii 64))
  (severity (string-ascii 16))
)
  (begin
    ;; Validate inputs
    (asserts! (> (len error-message) u0) ERR_INVALID_INPUT)
    (asserts! (> (len function-name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len severity) u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-severity severity) ERR_INVALID_INPUT)
    (asserts! (var-get error-reporting-enabled) ERR_SYSTEM_ERROR)
    
    ;; Generate error ID
    (let ((error-id (hash160 (concat (concat (int-to-buff error-code) (principal-to-buff? contract)) (string-ascii function-name))))
      
      ;; Create error report
      (map-set error-reports { error-id: error-id } {
        error-code: error-code,
        error-message: error-message,
        contract: contract,
        function: function-name,
        timestamp: block-height,
        severity: severity,
        resolved: false,
        resolution: none
      })
      
      ;; Update category statistics
      (let ((category (get-error-category-from-code error-code)))
        (let ((category-info (get-error-category category)))
          (if (is-some category-info)
              (begin
                (let ((cat (unwrap-optional category-info)))
                  (map-set error-categories { category: category } {
                    total-errors: (+ (get cat total-errors) u1),
                    last-error: block-height,
                    severity: (get cat severity),
                    active: (get cat active)
                  })
                )
              )
              (map-set error-categories { category: category } {
                total-errors: u1,
                last-error: block-height,
                severity: severity,
                active: true
              })
          )
          
          ;; Check threshold
          (let ((total-errors (get-optional (get-error-category category)).total-errors))
            (if (>= total-errors (var-get error-threshold))
                (emit-event (error-threshold-exceeded category total-errors))
                true
            )
          )
        )
      )
      
      ;; Update contract statistics
      (let ((contract-stats (get-error-statistics contract)))
        (if (is-some contract_stats)
            (begin
              (let ((stats (unwrap-optional contract_stats)))
                (map-set error-statistics { contract: contract } {
                  total-errors: (+ (get stats total-errors) u1),
                  error-types: (update-error-types (get stats error-types) error-code),
                  last-error: block-height,
                  error-rate: (get stats error-rate) // Would calculate actual rate
                })
              )
            )
            (map-set error-statistics { contract: contract } {
              total-errors: u1,
              error-types: (list { code: error-code, count: u1 }),
              last-error: block-height,
              error-rate: u10000
            })
        )
      )
      
      ;; Update global counter
      (var-set total-errors-reported (+ (var-get total-errors-reported) u1))
      
      ;; Emit event
      (emit-event (error-reported error-id error-code severity))
      
      (ok error-id)
    )
  )
)

(define-public (resolve-error (error-id (buff 32)) (resolution (string-ascii 256)))
  (begin
    ;; Validate inputs
    (asserts! (> (len resolution) u0) ERR_INVALID_INPUT)
    (asserts! (var-get error-reporting-enabled) ERR_SYSTEM_ERROR)
    
    ;; Check if error exists
    (let ((error-report (get-error-report error_id)))
      (asserts! (is-some error_report) ERR_STATE_INVALID)
      
      (let ((report (unwrap-optional error_report)))
        ;; Update error report
        (map-set error-reports { error-id: error_id } {
          error-code: (get report error-code),
          error-message: (get report error-message),
          contract: (get report contract),
          function: (get report function),
          timestamp: (get report timestamp),
          severity: (get report severity),
          resolved: true,
          resolution: (some resolution)
        })
        
        ;; Update resolution statistics
        (let ((resolution-info (get-error-resolution (get report error-code))))
          (if (is-some resolution_info)
              (begin
                (let ((res (unwrap-optional resolution_info)))
                  (map-set error-resolutions { error-code: (get report error-code) } {
                    resolution: (get res resolution),
                    automated-fix: (get res automated-fix),
                    success-rate: (/ (+ (* (get res success-rate) u100) u1) u101),
                    last-applied: block-height
                  })
                )
              )
              (map-set error-resolutions { error-code: (get report error-code) } {
                resolution: resolution,
                automated-fix: false,
                success-rate: u10000,
                last-applied: block-height
              })
          )
        )
        
        ;; Emit event
        (emit-event (error-resolved error_id resolution))
        
        (ok true)
      )
    )
  )
)

(define-public (escalate-error (error-id (buff 32)) (new-severity (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len new-severity) u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-severity new-severity) ERR_INVALID_INPUT)
    (asserts! (var-get error-reporting-enabled) ERR_SYSTEM_ERROR)
    
    ;; Check if error exists
    (let ((error-report (get-error-report error_id)))
      (asserts! (is-some error_report) ERR_STATE_INVALID)
      
      (let ((report (unwrap-optional error_report)))
        ;; Update error severity
        (map-set error-reports { error-id: error_id } {
          error-code: (get report error-code),
          error-message: (get report error-message),
          contract: (get report contract),
          function: (get report function),
          timestamp: (get report timestamp),
          severity: new-severity,
          resolved: (get report resolved),
          resolution: (get report resolution)
        })
        
        ;; Emit event
        (emit-event (error-escalated error_id new-severity))
        
        (ok true)
      )
    )
  )
)

(define-public (set-error-resolution (error-code uint) (resolution (string-ascii 256)) (automated-fix bool))
  (begin
    ;; Only admin can set error resolutions
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_ACCESS)
    
    ;; Validate inputs
    (asserts! (> (len resolution) u0) ERR_INVALID_INPUT)
    
    ;; Set error resolution
    (map-set error-resolutions { error-code: error_code } {
      resolution: resolution,
      automated-fix: automated-fix,
      success-rate: u10000,
      last-applied: block-height
    })
    
    (ok true)
  )
)

(define-public (set-error-reporting-enabled (enabled bool))
  (begin
    ;; Only admin can set reporting status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_ACCESS)
    
    (var-set error-reporting-enabled enabled)
    (ok true)
  )
)

(define-public (set-error-threshold (threshold uint))
  (begin
    ;; Only admin can set threshold
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED_ACCESS)
    
    (var-set error-threshold threshold)
    (ok true)
  )
)

(define-public (batch-resolve-errors (error-ids (list 20 (buff 32))) (resolution (string-ascii 256)))
  (begin
    ;; Validate list size
    (asserts! (<= (len error-ids) u20) ERR_INVALID_INPUT)
    
    ;; Resolve each error
    (fold error-ids u0
      (lambda ((result uint) (error-id (buff 32)))
        (match (resolve-error error_id resolution)
          success (+ result u1)
          error result
        )
      )
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { total-errors: uint, last-error: uint, severity: (string-ascii 16), active: bool } option))

(define-private (get-optional (option))
  (default-to u0 option))

(define-private (is-valid-severity (severity (string-ascii 16)))
  (or 
    (is-eq severity "low")
    (is-eq severity "medium")
    (is-eq severity "high")
    (is-eq severity "critical")
  )
)

(define-private (get-error-category-from-code (error-code uint))
  (begin
    ;; Determine category based on error code range
    (if (>= error-code (+ ERR_BASE u900))
        "system"
        (if (>= error-code (+ ERR_BASE u800))
            "configuration"
            (if (>= error-code (+ ERR_BASE u700))
                "state"
                (if (>= error-code (+ ERR_BASE u600))
                    "math"
                    (if (>= error-code (+ ERR_BASE u500))
                        "oracle"
                        (if (>= error-code (+ ERR_BASE u400))
                            "trading"
                            (if (>= error-code (+ ERR_BASE u300))
                                "pool"
                                (if (>= error-code (+ ERR_BASE u200))
                                    "token"
                                    (if (>= error-code (+ ERR_BASE u100))
                                        "access"
                                        "core"
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
  )
)

(define-private (update-error-types (error-types (list 10 { code: uint, count: uint })) (error-code uint))
  (begin
    ;; Update error type counts
    (fold error-types (list 0 { code: uint, count: uint })
      (lambda ((result (list 10 { code: uint, count: uint })) (error-type { code: uint, count: uint }))
        (if (is-eq (get error-type code) error-code)
            (append result { code: error-code, count: (+ (get error-type count) u1) })
            (append result error-type)
        )
      )
    )
  )
)

;; Utility functions

(define-read-only (get-error-message (error-code uint))
  (begin
    ;; Return human-readable error message for error code
    (match error-code
      ERR_PROTOCOL_NOT_INITIALIZED "Protocol is not initialized"
      ERR_PROTOCOL_PAUSED "Protocol is currently paused"
      ERR_PROTOCOL_SHUTDOWN "Protocol is shutdown"
      ERR_INVALID_PROTOCOL_VERSION "Invalid protocol version"
      ERR_PROTOCOL_MIGRATION_REQUIRED "Protocol migration required"
      ERR_UNAUTHORIZED_ACCESS "Unauthorized access"
      ERR_INSUFFICIENT_PERMISSIONS "Insufficient permissions"
      ERR_ROLE_NOT_FOUND "Role not found"
      ERR_ROLE_ALREADY_ASSIGNED "Role already assigned"
      ERR_ACCESS_DENIED "Access denied"
      ERR_INVALID_SIGNATURE "Invalid signature"
      ERR_EXPIRED_SIGNATURE "Expired signature"
      ERR_INVALID_PRINCIPAL "Invalid principal"
      ERR_TOKEN_NOT_FOUND "Token not found"
      ERR_INVALID_TOKEN_AMOUNT "Invalid token amount"
      ERR_INSUFFICIENT_BALANCE "Insufficient balance"
      ERR_INSUFFICIENT_ALLOWANCE "Insufficient allowance"
      ERR_TOKEN_TRANSFER_FAILED "Token transfer failed"
      ERR_INVALID_TOKEN_CONTRACT "Invalid token contract"
      ERR_TOKEN_FROZEN "Token is frozen"
      ERR_TOKEN_MINT_LIMIT_EXCEEDED "Token mint limit exceeded"
      ERR_POOL_NOT_FOUND "Pool not found"
      ERR_POOL_ALREADY_EXISTS "Pool already exists"
      ERR_INSUFFICIENT_POOL_LIQUIDITY "Insufficient pool liquidity"
      ERR_INVALID_POOL_TYPE "Invalid pool type"
      ERR_POOL_NOT_ACTIVE "Pool is not active"
      ERR_POOL_CAPACITY_EXCEEDED "Pool capacity exceeded"
      ERR_INVALID_POOL_PAIR "Invalid pool pair"
      ERR_POOL_CREATION_FAILED "Pool creation failed"
      ERR_INVALID_TRADE_AMOUNT "Invalid trade amount"
      ERR_TRADE_WOULD_EXCEED_LIMIT "Trade would exceed limit"
      ERR_PRICE_IMPACT_TOO_HIGH "Price impact too high"
      ERR_SLIPPAGE_EXCEEDED "Slippage exceeded"
      ERR_TRADE_FAILED "Trade failed"
      ERR_INSUFFICIENT_OUTPUT "Insufficient output"
      ERR_INVALID_TRADE_PAIR "Invalid trade pair"
      ERR_TRADE_TIMEOUT "Trade timeout"
      ERR_ORACLE_NOT_AVAILABLE "Oracle not available"
      ERR_ORACLE_DATA_STALE "Oracle data is stale"
      ERR_INVALID_ORACLE_PRICE "Invalid oracle price"
      ERR_ORACLE_FEED_NOT_FOUND "Oracle feed not found"
      ERR_ORACLE_CONFIDENCE_LOW "Oracle confidence low"
      ERR_ORACLE_VERIFICATION_FAILED "Oracle verification failed"
      ERR_ORACLE_TIMEOUT "Oracle timeout"
      ERR_MATH_OVERFLOW "Math overflow"
      ERR_MATH_UNDERFLOW "Math underflow"
      ERR_DIVISION_BY_ZERO "Division by zero"
      ERR_INVALID_PRECISION "Invalid precision"
      ERR_CALCULATION_FAILED "Calculation failed"
      ERR_INVALID_INPUT "Invalid input"
      ERR_PRECISION_LOSS "Precision loss"
      ERR_STATE_INVALID "Invalid state"
      ERR_STATE_TRANSITION_INVALID "Invalid state transition"
      ERR_STATE_LOCKED "State is locked"
      ERR_STATE_NOT_READY "State is not ready"
      ERR_STATE_CORRUPTED "State is corrupted"
      ERR_STATE_MIGRATION_FAILED "State migration failed"
      ERR_INVALID_CONFIGURATION "Invalid configuration"
      ERR_CONFIG_NOT_FOUND "Configuration not found"
      ERR_CONFIG_UPDATE_FAILED "Configuration update failed"
      ERR_INVALID_PARAMETER "Invalid parameter"
      ERR_PARAMETER_OUT_OF_RANGE "Parameter out of range"
      ERR_REQUIRED_PARAMETER_MISSING "Required parameter missing"
      ERR_SYSTEM_OVERLOADED "System is overloaded"
      ERR_SYSTEM_MAINTENANCE "System under maintenance"
      ERR_SYSTEM_SHUTDOWN "System is shutdown"
      ERR_RATE_LIMIT_EXCEEDED "Rate limit exceeded"
      ERR_RESOURCE_EXHAUSTED "Resource exhausted"
      ERR_SYSTEM_ERROR "System error"
      "Unknown error"
    )
  )
)

(define-read-only (get-error-summary)
  {
    reporting-enabled: (var-get error-reporting-enabled),
    total-errors: (var-get total-errors-reported),
    threshold: (var-get error-threshold),
    active-categories: u0 // Would count active categories
  }
)

(define-read-only (validate-error-code (error-code uint))
  (begin
    ;; Validate error code is within expected range
    (and (>= error-code ERR_BASE) (<= error-code (+ ERR_BASE u999)))
  )
)
