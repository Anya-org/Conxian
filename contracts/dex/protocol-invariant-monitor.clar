;; protocol-invariant-monitor.clar
;; Conxian Protocol: Protocol invariant monitoring and validation system

;; Dependencies
(use-trait .defi-traits .defi-traits.defi-traits)
(use-trait .core-traits .core-traits.core-traits)

;; Constants
(define-constant ERR_INVARIANT_VIOLATION (err 29001))
(define-constant ERR_MONITOR_NOT_ACTIVE (err 29002))
(define-constant ERR_INVALID_INVARIANT (err 29003))
(define-constant ERR_VALIDATION_FAILED (err 29004))
(define-constant ERR_CRITICAL_VIOLATION (err 29005))

;; Monitoring parameters
(define-constant MONITORING_INTERVAL u100) ;; Check every 100 blocks
(define-constant CRITICAL_THRESHOLD u5) ;; 5 violations trigger critical alert
(define-constant MAX_VIOLATION_HISTORY u1000
(define-constant RECOVERY_TIMEOUT u1000) ;; 1000 blocks for recovery
(define-constant MIN_CONFIDENCE u8000) ;; 80% confidence required

;; Data variables
(define-data-var monitor-active bool true)
(define-data-var total-checks uint u0)
(define-data-var total-violations uint u0)
(define-data-var last-monitoring-block uint u0)

;; Storage maps
(define-map protocol-invariants { invariant-id: (string-ascii 32) } { 
  name: (string-ascii 64),
  description: (string-ascii 256),
  validation-function: (string-ascii 64),
  criticality: (string-ascii 16),
  enabled: bool,
  last-checked: uint,
  violation-count: uint,
  consecutive-violations: uint,
  last-violation: uint,
  confidence: uint
})

(define-map violation-records { violation-id: (buff 32) } { 
  invariant-id: (string-ascii 32),
  timestamp: uint,
  severity: (string-ascii 16),
  details: (string-ascii 512),
  resolved: bool,
  resolution: (optional (string-ascii 256))
})

(define-map monitoring-state { contract: principal } { 
  last-checked: uint,
  violations: uint,
  status: (string-ascii 16),
  last-violation: uint,
  recovery-attempts: uint
})

(define-map invariant-history { invariant-id: (string-ascii 32) } { 
  violations: (list 100 { timestamp: uint, severity: (string-ascii 16), details: (string-ascii 512) }),
  last-violation: uint,
  total-violations: uint,
  recovery-time: uint
})

;; Events
(define-event (invariant-registered (invariant-id (string-ascii 32)) (name (string-ascii 64)) (criticality (string-ascii 16))))
(define-event (invariant-violation (invariant-id (string-ascii 32)) (severity (string-ascii 16)) (details (string-ascii 512))))
(define-event (invariant-restored (invariant-id (string-ascii 32)) (confidence uint)))
(define-event (critical-alert (invariant-id (string-ascii 32)) (violation-count uint)))
(define-event (monitoring-disabled))
(define-event (monitoring-enabled))

;; Read-only functions

(define-read-only (get-invariant (invariant-id (string-ascii 32)))
  (map-get? protocol-invariants { invariant-id: invariant-id }))

(define-read-only (get-invariant-name (invariant-id (string-ascii 32)))
  (match (get-invariant invariant-id)
    invariant (ok (get invariant name))
    none (ok "")
  )
)

(define-read-only (get-invariant-criticality (invariant-id (string-ascii 32)))
  (match (get-invariant invariant-id)
    invariant (ok (get invariant criticality))
    none (ok "low")
  )
)

(define-read-only (is-invariant-enabled (invariant-id (string-ascii 32)))
  (match (get-invariant invariant-id)
    invariant (ok (get invariant enabled))
    none (ok false)
  )
)

(define-read-only (get-violation-record (violation-id (buff 32)))
  (map-get? violation-records { violation-id: violation-id }))

(define-read-only (get-monitoring-state (contract principal))
  (map-get? monitoring-state { contract: contract }))

(define-read-only (get-invariant-history (invariant-id (string-ascii 32)))
  (map-get? invariant-history { invariant-id: invariant-id }))

(define-read-only (is-monitor-active)
  (var-get monitor-active))

(define-read-only (get-total-checks)
  (var-get total-checks))

(define-read-only (get-total-violations)
  (var-get total-violations))

(define-read-only (get-last-monitoring-block)
  (var-get last-monitoring-block))

;; Public functions

(define-public (register-invariant 
  (invariant-id (string-ascii 32)) 
  (name (string-ascii 64)) 
  (description (string-ascii 256))
  (validation-function (string-ascii 64))
  (criticality (string-ascii 16))
)
  (begin
    ;; Validate inputs
    (asserts! (> (len invariant-id) u0) ERR_INVALID_INVARIANT)
    (asserts! (> (len name) u0) ERR_INVALID_INVARIANT)
    (asserts! (> (len description) u0) ERR_INVALID_INVARIANT)
    (asserts! (> (len validation-function) u0) ERR_INVALID_INVARIANT)
    (asserts! (> (len criticality) u0) ERR_INVALID_INVARIANT)
    (asserts! (is-valid-criticality criticality) ERR_INVALID_INVARIANT)
    (asserts! (var-get monitor-active) ERR_MONITOR_NOT_ACTIVE)
    
    ;; Register invariant
    (map-set protocol-invariants { invariant-id: invariant-id } {
      name: name,
      description: description,
      validation-function: validation-function,
      criticality: criticality,
      enabled: true,
      last-checked: u0,
      violation-count: u0,
      consecutive-violations: u0,
      last-violation: u0,
      confidence: u10000
    })
    
    ;; Initialize history
    (map-set invariant-history { invariant-id: invariant-id } {
      violations: (list 0 { timestamp: uint, severity: (string-ascii 16), details: (string-ascii 512) }),
      last-violation: u0,
      total-violations: u0,
      recovery-time: u0
    })
    
    ;; Emit event
    (emit-event (invariant-registered invariant-id name criticality))
    
    (ok true)
  )
)

(define-public (check-invariant (invariant-id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len invariant_id) u0) ERR_INVALID_INVARIANT)
    (asserts! (var-get monitor-active) ERR_MONITOR_NOT_ACTIVE)
    
    ;; Check if invariant exists and is enabled
    (let ((invariant_info (get-invariant invariant_id)))
      (asserts! (is-some invariant_info) ERR_INVALID_INVARIANT)
      
      (let ((invariant (unwrap-optional invariant_info)))
        (asserts! (get invariant enabled) ERR_INVALID_INVARIANT)
        
        ;; Perform validation
        (let ((validation-result (validate-invariant invariant_id invariant)))
          (match validation_result
            success
              (begin
                ;; Update invariant state
                (map-set protocol-invariants { invariant-id: invariant_id } {
                  name: (get invariant name),
                  description: (get invariant description),
                  validation-function: (get invariant validation-function),
                  criticality: (get invariant criticality),
                  enabled: (get invariant enabled),
                  last-checked: block-height,
                  violation-count: (get invariant violation-count),
                  consecutive-violations: u0, // Reset on success
                  last-violation: (get invariant last-violation),
                  confidence: (get success confidence)
                })
                
                ;; Update global counters
                (var-set total-checks (+ (var-get total-checks) u1))
                (var-set last-monitoring-block block-height)
                
                ;; Emit restoration event if previously violated
                (if (> (get invariant consecutive-violations) u0)
                    (emit-event (invariant-restored invariant_id (get success confidence)))
                    true
                )
                
                (ok {
                  invariant-id: invariant_id,
                  status: "valid",
                  confidence: (get success confidence),
                  last-checked: block-height
                })
              )
            error
              (begin
                ;; Handle violation
                (handle-invariant-violation invariant_id invariant error)
              )
          )
        )
      )
    )
  )
)

(define-public (check-all-invariants)
  (begin
    ;; Validate inputs
    (asserts! (var-get monitor-active) ERR_MONITOR_NOT_ACTIVE)
    
    ;; Check all enabled invariants
    ;; This would iterate through all invariants
    ;; Simplified implementation
    
    (let ((checked-count u0))
      ;; Update global counters
      (var-set total-checks (+ (var-get total-checks) checked_count))
      (var-set last-monitoring-block block-height)
      
      (ok {
        checked-count: checked_count,
        violations: (var-get total-violations),
        last-check: block-height
      })
    )
  )
)

(define-public (handle-invariant-violation (invariant-id (string-ascii 32)) (invariant { name: (string-ascii 64), description: (string-ascii 256), validation-function: (string-ascii 64), criticality: (string-ascii 16), enabled: bool, last-checked: uint, violation-count: uint, consecutive-violations: uint, last-violation: uint, confidence: uint }) (error (response bool uint)))
  (begin
    ;; Generate violation ID
    (let ((violation-id (hash160 (concat (string-ascii invariant_id) (int-to-buff block-height))))
          (severity (determine-severity invariant error)))
      
      ;; Create violation record
      (map-set violation-records { violation-id: violation_id } {
        invariant-id: invariant-id,
        timestamp: block-height,
        severity: severity,
        details: (unwrap-panic error), // Extract error message
        resolved: false,
        resolution: none
      })
      
      ;; Update invariant state
      (map-set protocol-invariants { invariant-id: invariant_id } {
        name: (get invariant name),
        description: (get invariant description),
        validation-function: (get invariant validation-function),
        criticality: (get invariant criticality),
        enabled: (get invariant enabled),
        last-checked: block-height,
        violation-count: (+ (get invariant violation-count) u1),
        consecutive-violations: (+ (get invariant consecutive-violations) u1),
        last-violation: block-height,
        confidence: (max u0 (- (get invariant confidence) u1000)) // Decrease confidence
      })
      
      ;; Update history
      (let ((history (get-invariant-history invariant_id)))
        (if (is-some history)
            (begin
              (let ((hist (unwrap-optional history)))
                (map-set invariant-history { invariant-id: invariant_id } {
                  violations: (append (get hist violations) { timestamp: block-height, severity: severity, details: (unwrap-panic error) }),
                  last-violation: block-height,
                  total-violations: (+ (get hist total-violations) u1),
                  recovery-time: (get hist recovery-time)
                })
              )
            )
            (map-set invariant-history { invariant-id: invariant_id } {
              violations: (list { timestamp: block-height, severity: severity, details: (unwrap-panic error) }),
              last-violation: block-height,
              total-violations: u1,
              recovery-time: u0
            })
        )
      )
      
      ;; Update global counters
      (var-set total-violations (+ (var-get total-violations) u1))
      (var-set last-monitoring-block block-height)
      
      ;; Check for critical alert
      (if (>= (+ (get invariant consecutive-violations) u1) CRITICAL_THRESHOLD)
          (emit-event (critical-alert invariant_id (+ (get invariant consecutive-violations) u1)))
          true
      )
      
      ;; Emit violation event
      (emit-event (invariant-violation invariant_id severity (unwrap-panic error)))
      
      (ok {
        invariant-id: invariant_id,
        violation-id: violation_id,
        severity: severity,
        consecutive-violations: (+ (get invariant consecutive-violations) u1)
      })
    )
  )
)

(define-public (resolve-violation (violation-id (buff 32)) (resolution (string-ascii 256)))
  (begin
    ;; Validate inputs
    (asserts! (> (len resolution) u0) ERR_VALIDATION_FAILED)
    
    ;; Check if violation exists
    (let ((violation_record (get-violation-record violation_id)))
      (asserts! (is-some violation_record) ERR_VALIDATION_FAILED)
      
      (let ((record (unwrap-optional violation_record)))
        ;; Update violation record
        (map-set violation-records { violation-id: violation_id } {
          invariant-id: (get record invariant-id),
          timestamp: (get record timestamp),
          severity: (get record severity),
          details: (get record details),
          resolved: true,
          resolution: (some resolution)
        })
        
        (ok true)
      )
    )
  )
)

(define-public (enable-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len invariant_id) u0) ERR_INVALID_INVARIANT)
    (asserts! (var-get monitor_active) ERR_MONITOR_NOT_ACTIVE)
    
    ;; Check if invariant exists
    (let ((invariant_info (get-invariant invariant_id)))
      (asserts! (is-some invariant_info) ERR_INVALID_INVARIANT)
      
      (let ((invariant (unwrap-optional invariant_info)))
        ;; Enable invariant
        (map-set protocol-invariants { invariant-id: invariant_id } {
          name: (get invariant name),
          description: (get invariant description),
          validation-function: (get invariant validation-function),
          criticality: (get invariant criticality),
          enabled: true,
          last-checked: (get invariant last-checked),
          violation-count: (get invariant violation-count),
          consecutive-violations: (get invariant consecutive-violations),
          last-violation: (get invariant last-violation),
          confidence: (get invariant confidence)
        })
        
        (ok true)
      )
    )
  )
)

(define-public (disable-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Validate inputs
    (asserts! (> (len invariant_id) u0) ERR_INVALID_INVARIANT)
    (asserts! (var-get monitor_active) ERR_MONITOR_NOT_ACTIVE)
    
    ;; Check if invariant exists
    (let ((invariant_info (get-invariant invariant_id)))
      (asserts! (is-some invariant_info) ERR_INVALID_INVARIANT)
      
      (let ((invariant (unwrap-optional invariant_info)))
        ;; Disable invariant
        (map-set protocol-invariants { invariant-id: invariant_id } {
          name: (get invariant name),
          description: (get invariant description),
          validation-function: (get invariant validation-function),
          criticality: (get invariant criticality),
          enabled: false,
          last-checked: (get invariant last-checked),
          violation-count: (get invariant violation-count),
          consecutive-violations: (get invariant consecutive-violations),
          last-violation: (get invariant last-violation),
          confidence: (get invariant confidence)
        })
        
        (ok true)
      )
    )
  )
)

(define-public (set-monitor-active (active bool))
  (begin
    ;; Only admin can set monitor status
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_MONITOR_NOT_ACTIVE)
    
    (var-set monitor-active active)
    
    ;; Emit event
    (if active
        (emit-event (monitoring-enabled))
        (emit-event (monitoring-disabled))
    )
    
    (ok true)
  )
)

;; Private helper functions

(define-private (is-some (option))
  (not (is-none option)))

(define-private (unwrap-optional (option))
  (default-to { name: (string-ascii 64), description: (string-ascii 256), validation-function: (string-ascii 64), criticality: (string-ascii 16), enabled: bool, last-checked: uint, violation-count: uint, consecutive-violations: uint, last-violation: uint, confidence: uint } option))

(define-private (is-valid-criticality (criticality (string-ascii 16)))
  (or 
    (is-eq criticality "low")
    (is-eq criticality "medium")
    (is-eq criticality "high")
    (is-eq criticality "critical")
  )
)

(define-private (validate-invariant (invariant_id (string-ascii 32)) (invariant { name: (string-ascii 64), description: (string-ascii 256), validation-function: (string-ascii 64), criticality: (string-ascii 16), enabled: bool, last-checked: uint, violation-count: uint, consecutive-violations: uint, last-violation: uint, confidence: uint }))
  (begin
    ;; Perform validation based on invariant type
    (match (get invariant validation-function)
      "check-total-supply" (check-total-supply-invariant invariant_id)
      "check-pool-balance" (check-pool-balance-invariant invariant_id)
      "check-price-stability" (check-price-stability-invariant invariant_id)
      "check-liquidity-ratio" (check-liquidity-ratio-invariant invariant_id)
      "check-oracle-integrity" (check-oracle-integrity-invariant invariant_id)
      (check-generic-invariant invariant_id) // Default
    )
  )
)

(define-private (check-total-supply-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Check that total token supply doesn't exceed maximum
    ;; Simplified implementation
    
    (let ((total-supply u1000000000) ;; Would get actual supply
          (max-supply u10000000000))
      
      (if (<= total-supply max-supply)
          (ok { confidence: u10000 })
          (err ERR_INVARIANT_VIOLATION)
      )
    )
  )
)

(define-private (check-pool-balance-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Check that pool reserves are balanced
    ;; Simplified implementation
    
    (let ((reserve-0 u1000000)
          (reserve-1 u1000000)
          (tolerance u1000)) ;; 10% tolerance
      
      (let ((ratio (/ (* reserve-0 u10000) reserve-1)))
        (if (and (>= ratio (- u10000 tolerance)) (<= ratio (+ u10000 tolerance)))
            (ok { confidence: u9500 })
            (err ERR_INVARIANT_VIOLATION)
        )
      )
    )
  )
)

(define-private (check-price-stability-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Check that price doesn't deviate too much from oracle
    ;; Simplified implementation
    
    (let ((pool-price u1000000)
          (oracle-price u1050000)
          (max-deviation u500)) ;; 5% max deviation
    
      (let ((deviation (/ (* (abs (- pool-price oracle-price)) u10000) oracle-price)))
        (if (<= deviation max-deviation)
            (ok { confidence: u9000 })
            (err ERR_INVARIANT_VIOLATION)
        )
      )
    )
  )
)

(define-private (check-liquidity-ratio-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Check that liquidity ratio is within acceptable range
    ;; Simplified implementation
    
    (let ((liquidity-ratio u5000) ;; 50%
          (min-ratio u2000) ;; 20%
          (max-ratio u8000)) ;; 80%
      
      (if (and (>= liquidity-ratio min-ratio) (<= liquidity-ratio max-ratio))
          (ok { confidence: u9500 })
          (err ERR_INVARIANT_VIOLATION)
      )
    )
  )
)

(define-private (check-oracle-integrity-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Check that oracle data is consistent
    ;; Simplified implementation
    
    (let ((oracle-age u50) ;; Blocks since last update
          (max-age u100))
      
      (if (<= oracle-age max-age)
          (ok { confidence: u10000 })
          (err ERR_INVARIANT_VIOLATION)
      )
    )
  )
)

(define-private (check-generic-invariant (invariant_id (string-ascii 32)))
  (begin
    ;; Generic invariant check
    ;; Simplified implementation
    
    (ok { confidence: u8000 })
  )
)

(define-private (determine-severity (invariant { name: (string-ascii 64), description: (string-ascii 256), validation-function: (string-ascii 64), criticality: (string-ascii 16), enabled: bool, last-checked: uint, violation-count: uint, consecutive-violations: uint, last-violation: uint, confidence: uint }) (error (response bool uint)))
  (begin
    ;; Determine severity based on invariant criticality and violation count
    (match (get invariant criticality)
      "critical" "critical"
      "high" 
        (if (>= (get invariant consecutive-violations) u3)
            "critical"
            "high"
        )
      "medium"
        (if (>= (get invariant consecutive-violations) u5)
            "high"
            "medium"
        )
      "low"
        (if (>= (get invariant consecutive-violations) u10)
            "medium"
            "low"
        )
      "low" ;; Default
    )
  )
)

;; Utility functions

(define-read-only (get-monitor-status)
  {
    active: (var-get monitor-active),
    total-checks: (var-get total-checks),
    total-violations: (var-get total-violations),
    last-check: (var-get last-monitoring-block),
    violation-rate: (if (> (var-get total-checks) u0)
                      (/ (* (var-get total-violations) u10000) (var-get total-checks))
                      u0)
  }
)

(define-read-only (get-invariant-summary (invariant_id (string-ascii 32)))
  (match (get-invariant invariant_id)
    invariant
      (ok {
        name: (get invariant name),
        criticality: (get invariant criticality),
        enabled: (get invariant enabled),
        violation-count: (get invariant violation-count),
        consecutive-violations: (get invariant consecutive-violations),
        confidence: (get invariant confidence),
        last-checked: (get invariant last-checked)
      })
    none (err ERR_INVALID_INVARIANT)
  )
)
