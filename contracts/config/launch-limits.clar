;; Launch Limits Configuration
;; Configuration for launch parameters and limits

;; Launch parameters
(define-data-var launch-config { key: (string-ascii 32) } { value: (optional uint), active: bool })

;; Default launch limits
(define-constant MIN_LAUNCH_PARTICIPANTS u100)
(define-constant MAX_LAUNCH_PARTICIPANTS u10000)
(define-constant MIN_CONTRIBUTION u1000000) ;; 1 STX
(define-constant MAX_CONTRIBUTION u10000000000) ;; 10,000 STX
(define-constant LAUNCH_DURATION u10080) ;; 1 day in blocks
(define-constant MIN_SUCCESS_THRESHOLD u50000000000) ;; 50,000 STX
(define-constant MAX_SUCCESS_THRESHOLD u1000000000000) ;; 1,000,000 STX

;; Access control
(define-constant CONTRACT_OWNER tx-sender)
(define-data-var launch-admin principal CONTRACT_OWNER)

;; Events - using print statements instead
(define-constant EVENT_LAUNCH_LIMIT_UPDATED "launch-limit-updated")
(define-constant EVENT_LAUNCH_ACTIVATED "launch-activated")
(define-constant EVENT_LAUNCH_DEACTIVATED "launch-deactivated")

;; Read-only functions
(define-read-only (get-launch-limit (key (string-ascii 32)))
  (match (map-get? launch-config { key: key })
    config (ok (get config value))
    none (err 11001)
  )
)

(define-read-only (is-limit-active (key (string-ascii 32)))
  (match (map-get? launch-config { key: key })
    config (ok (get config active))
    none (ok false)
  )
)

(define-read-only (get-min-participants)
  MIN_LAUNCH_PARTICIPANTS)

(define-read-only (get-max-participants)
  MAX_LAUNCH_PARTICIPANTS)

(define-read-only (get-min-contribution)
  MIN_CONTRIBUTION)

(define-read-only (get-max-contribution)
  MAX_CONTRIBUTION)

(define-read-only (get-launch-duration)
  LAUNCH_DURATION)

(define-read-only (get-min-success-threshold)
  MIN_SUCCESS_THRESHOLD)

(define-read-only (get-max-success-threshold)
  MAX_SUCCESS_THRESHOLD)

;; Public functions
(define-public (set-launch-limit (key (string-ascii 32)) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get launch-admin)) (err 11002))
    (asserts! (> value u0) (err 11003))
    
    (let ((old-value (default-to u0 (get-launch-limit key))))
      (map-set launch-config { key: key } { value: value, active: true })
      (print {
        event: EVENT_LAUNCH_LIMIT_UPDATED,
        key: key,
        old-value: old-value,
        new-value: value,
      })
      (ok true)
    )
  )
)

(define-public (activate-limit (key (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get launch-admin)) (err 11004))
    
    (match (map-get? launch-config { key: key })
      config
        (begin
          (map-set launch-config { key: key } { 
            value: (get config value), 
            active: true 
          })
          (print {
            event: EVENT_LAUNCH_ACTIVATED,
            key: key,
          })
          (ok true)
        )
      none (err 11005)
    )
  )
)

(define-public (deactivate-limit (key (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get launch-admin)) (err 11006))
    
    (match (map-get? launch-config { key: key })
      config
        (begin
          (map-set launch-config { key: key } { 
            value: (get config value), 
            active: false 
          })
          (print {
            event: EVENT_LAUNCH_DEACTIVATED,
            key: key,
          })
          (ok true)
        )
      none (err 11007)
    )
  )
)

;; Validation functions
(define-public (validate-contribution (amount uint))
  (begin
    (asserts! (>= amount MIN_CONTRIBUTION) (err 11008))
    (asserts! (<= amount MAX_CONTRIBUTION) (err 11009))
    (ok true)
  )
)

(define-public (validate-participant-count (count uint))
  (begin
    (asserts! (>= count MIN_LAUNCH_PARTICIPANTS) (err 11010))
    (asserts! (<= count MAX_LAUNCH_PARTICIPANTS) (err 11011))
    (ok true)
  )
)

(define-public (validate-success-threshold (threshold uint))
  (begin
    (asserts! (>= threshold MIN_SUCCESS_THRESHOLD) (err 11012))
    (asserts! (<= threshold MAX_SUCCESS_THRESHOLD) (err 11013))
    (ok true)
  )
)

;; Admin functions
(define-public (set-launch-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 11014))
    (var-set launch-admin new-admin)
    (ok true)
  )
)

(define-public (emergency-reset-all-limits)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err 11015))
    
    ;; Clear all limits
    (map-delete launch-config { key: "min-participants" })
    (map-delete launch-config { key: "max-participants" })
    (map-delete launch-config { key: "min-contribution" })
    (map-delete launch-config { key: "max-contribution" })
    (map-delete launch-config { key: "launch-duration" })
    (map-delete launch-config { key: "success-threshold" })
    
    (ok true)
  )
)
