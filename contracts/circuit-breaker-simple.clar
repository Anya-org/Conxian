;; Simplified Circuit Breaker Framework for AutoVault DEX
;; Risk management system with automatic trading halts

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_BREAKER_NOT_FOUND u402)
(define-constant ERR_INVALID_THRESHOLD u403)

;; Circuit breaker types
(define-constant BREAKER_PRICE_VOLATILITY u1)
(define-constant BREAKER_VOLUME_SPIKE u2)
(define-constant BREAKER_LIQUIDITY_DRAIN u3)

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var emergency-admin principal tx-sender)
(define-data-var system-paused bool false)
(define-data-var global-circuit-breaker bool false)

;; Authorization
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

(define-private (is-emergency-admin)
  (or (is-admin) (is-eq tx-sender (var-get emergency-admin))))

;; Circuit breaker status
(define-map circuit-breaker-status
  { breaker-type: uint }
  { 
    triggered: bool,
    last-triggered: uint,
    threshold: uint
  }
)

;; Core circuit breaker functions
(define-public (trigger-circuit-breaker (breaker-type uint) (trigger-value uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    (map-set circuit-breaker-status
      { breaker-type: breaker-type }
      {
        triggered: true,
        last-triggered: block-height,
        threshold: trigger-value
      })
    
    (print {
      event: "circuit-breaker-triggered",
      breaker-type: breaker-type,
      trigger-value: trigger-value,
      block-height: block-height
    })
    (ok true)))

(define-public (reset-circuit-breaker (breaker-type uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    (map-set circuit-breaker-status
      { breaker-type: breaker-type }
      {
        triggered: false,
        last-triggered: block-height,
        threshold: u0
      })
    
    (ok true)))

(define-read-only (is-circuit-breaker-triggered (breaker-type uint))
  (match (map-get? circuit-breaker-status { breaker-type: breaker-type })
    status (get triggered status)
    false))

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
    (var-set system-paused true)
    (var-set global-circuit-breaker true)
    
    (print {
      event: "emergency-pause-activated",
      admin: tx-sender,
      block-height: block-height
    })
    (ok true)))

(define-public (emergency-resume)
  (begin
    (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
    (var-set system-paused false)
    (var-set global-circuit-breaker false)
    
    (print {
      event: "emergency-resume-activated",
      admin: tx-sender,
      block-height: block-height
    })
    (ok true)))

;; Read-only functions
(define-read-only (get-system-status)
  {
    system-paused: (var-get system-paused),
    global-circuit-breaker: (var-get global-circuit-breaker),
    price-volatility-triggered: (is-circuit-breaker-triggered BREAKER_PRICE_VOLATILITY),
    volume-spike-triggered: (is-circuit-breaker-triggered BREAKER_VOLUME_SPIKE),
    liquidity-drain-triggered: (is-circuit-breaker-triggered BREAKER_LIQUIDITY_DRAIN)
  })

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)))

(define-public (set-emergency-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set emergency-admin new-admin)
    (ok true)))
