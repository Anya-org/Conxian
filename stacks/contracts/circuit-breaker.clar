;; Circuit Breaker Framework for AutoVault DEX
;; Risk management system with automatic trading halts and protection mechanisms

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_CIRCUIT_BREAKER_AC              ;; Check volatility threshold
              (if (> volatility u2000) ;; 20% volatility threshold
                (try! (trigger-circuit-breaker BREAKER_PRICE_VOLATILITY volatility))
                (ok true)))
          
          ;; Initialize new window
          (begin
            (map-set price-tracking
              { pool: pool, window: current-window }
              {
                high-price: current-price,
                low-price: current-price,
                start-price: current-price,
                volatility-score: u0,
                last-update: block-height
              })
            (ok true))))))))

;; Constants
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_BREAKER_NOT_FOUND u402)
(define-constant ERR_INVALID_THRESHOLD u403)
(define-constant ERR_COOLDOWN_ACTIVE u404)
(define-constant ERR_EMERGENCY_STOP u405)

;; Circuit breaker types
(define-constant BREAKER_PRICE_VOLATILITY u1)
(define-constant BREAKER_VOLUME_SPIKE u2)
(define-constant BREAKER_LIQUIDITY_DRAIN u3)
(define-constant BREAKER_UNUSUAL_ACTIVITY u4)
(define-constant BREAKER_ORACLE_FAILURE u5)

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var emergency-admin principal tx-sender)
(define-data-var system-paused bool false)
(define-data-var global-circuit-breaker bool false)
(define-data-var breaker-count uint u0)

;; Circuit breaker configuration
(define-map circuit-breakers
  { breaker-id: uint }
  {
    breaker-type: uint,
    name: (string-ascii 50),
    threshold: uint,
    time-window: uint,
    cooldown-period: uint,
    enabled: bool,
    auto-resume: bool
  }
)

;; Active circuit breaker states
(define-map breaker-states
  { breaker-type: uint }
  {
    triggered: bool,
    triggered-at: uint,
    trigger-value: uint,
    auto-resume-at: uint,
    trigger-count: uint
  }
)

;; Pool-specific circuit breakers
(define-map pool-breakers
  { pool: principal, breaker-type: uint }
  {
    triggered: bool,
    triggered-at: uint,
    threshold: uint,
    pool-specific: bool
  }
)

;; Price volatility tracking
(define-map price-tracking
  { pool: principal, window: uint }
  {
    high-price: uint,
    low-price: uint,
    start-price: uint,
    volatility-score: uint,
    last-update: uint
  }
)

;; Volume spike detection
(define-map volume-tracking
  { pool: principal, period: uint }
  {
    volume: uint,
    baseline-volume: uint,
    spike-ratio: uint,
    timestamp: uint
  }
)

;; Liquidity drain detection
(define-map liquidity-tracking
  { pool: principal }
  {
    initial-liquidity: uint,
    current-liquidity: uint,
    drain-rate: uint,
    critical-threshold: uint,
    last-check: uint
  }
)

;; Emergency contact list
(define-map emergency-contacts
  { contact-id: uint }
  {
    address: principal,
    contact-type: (string-ascii 20), ;; "ADMIN", "OPERATOR", "VALIDATOR"
    permissions: uint,
    active: bool
  }
)

;; Authorization functions
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

(define-private (is-emergency-admin)
  (or (is-admin) (is-eq tx-sender (var-get emergency-admin))))

(define-private (is-authorized-contact)
  (or (is-emergency-admin)
      (is-some (map-get? emergency-contacts { contact-id: u1 })))) ;; Simplified check

;; Circuit breaker management
(define-public (create-circuit-breaker
  (breaker-type uint)
  (name (string-ascii 50))
  (threshold uint)
  (time-window uint)
  (cooldown-period uint)
  (auto-resume bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> threshold u0) (err ERR_INVALID_THRESHOLD))
    
    (let ((breaker-id (+ (var-get breaker-count) u1)))
      (map-set circuit-breakers
        { breaker-id: breaker-id }
        {
          breaker-type: breaker-type,
          name: name,
          threshold: threshold,
          time-window: time-window,
          cooldown-period: cooldown-period,
          enabled: true,
          auto-resume: auto-resume
        })
      
      ;; Initialize breaker state
      (map-set breaker-states
        { breaker-type: breaker-type }
        {
          triggered: false,
          triggered-at: u0,
          trigger-value: u0,
          auto-resume-at: u0,
          trigger-count: u0
        })
      
      (var-set breaker-count breaker-id)
      (print {
        event: "circuit-breaker-created",
        breaker-id: breaker-id,
        breaker-type: breaker-type,
        name: name,
        threshold: threshold
      })
      (ok breaker-id))))

(define-public (trigger-circuit-breaker (breaker-type uint) (trigger-value uint))
  (begin
    (asserts! (not (var-get system-paused)) (err ERR_EMERGENCY_STOP))
    
    (let ((breaker-state (map-get? breaker-states { breaker-type: breaker-type })))
      (match breaker-state
        state
          (begin
            ;; Update breaker state
            (map-set breaker-states
              { breaker-type: breaker-type }
              (merge state {
                triggered: true,
                triggered-at: block-height,
                trigger-value: trigger-value,
                trigger-count: (+ (get trigger-count state) u1)
              }))
            
            ;; Check if global circuit breaker should be triggered
            (if (> (get trigger-count state) u2) ;; Multiple triggers
              (var-set global-circuit-breaker true)
              false)
            
            (print {
              event: "circuit-breaker-triggered",
              breaker-type: breaker-type,
              trigger-value: trigger-value,
              block-height: block-height,
              global-halt: (var-get global-circuit-breaker)
            })
            (ok true))
        
        (err u404)))))

;; Volatility monitoring
(define-public (monitor-price-volatility (pool principal) (current-price uint))
  (begin
    (let ((window u144) ;; 24 hour window (approximately)
          (current-window (/ block-height window)))
      
      (let ((tracking-data (map-get? price-tracking { pool: pool, window: current-window })))
        (match tracking-data
          data
            ;; Update existing window
            (let ((new-high (max (get high-price data) current-price))
                  (new-low (min (get low-price data) current-price))
                  (volatility (calculate-volatility (get start-price data) new-high new-low)))
              
              (map-set price-tracking
                { pool: pool, window: current-window }
                (merge data {
                  high-price: new-high,
                  low-price: new-low,
                  volatility-score: volatility,
                  last-update: block-height
                }))
              
              ;; Check volatility threshold
              (if (> volatility u2000) ;; 20% volatility threshold
                (try! (trigger-circuit-breaker BREAKER_PRICE_VOLATILITY volatility))
                (ok true)))
          
          ;; Initialize new window
          (begin
            (map-set price-tracking
              { pool: pool, window: current-window }
              {
                high-price: current-price,
                low-price: current-price,
                start-price: current-price,
                volatility-score: u0,
                last-update: block-height
              })
            (ok true))))))

(define-private (calculate-volatility (start-price uint) (high-price uint) (low-price uint))
  ;; Calculate volatility as percentage range
  (if (> start-price u0)
    (/ (* (- high-price low-price) u10000) start-price)
    u0))

;; Volume spike detection
(define-public (monitor-volume-spike (pool principal) (current-volume uint))
  (begin
    (let ((period u144) ;; 24 hour period
          (current-period (/ block-height period)))
      
      (let ((volume-data (map-get? volume-tracking { pool: pool, period: current-period })))
        (match volume-data
          data
            ;; Update current period
            (let ((total-volume (+ (get volume data) current-volume))
                  (baseline (get baseline-volume data))
                  (spike-ratio (if (> baseline u0) (/ total-volume baseline) u0)))
              
              (map-set volume-tracking
                { pool: pool, period: current-period }
                (merge data {
                  volume: total-volume,
                  spike-ratio: spike-ratio,
                  timestamp: block-height
                }))
              
              ;; Check for volume spike (5x normal volume)
              (if (> spike-ratio u500) ;; 500% = 5x spike
                (try! (trigger-circuit-breaker BREAKER_VOLUME_SPIKE spike-ratio))
                (ok true)))
          
          ;; Initialize tracking
          (begin
            (map-set volume-tracking
              { pool: pool, period: current-period }
              {
                volume: current-volume,
                baseline-volume: current-volume, ;; Set baseline
                spike-ratio: u100, ;; 100% = normal
                timestamp: block-height
              })
            (ok true))))))

;; Liquidity drain monitoring
(define-public (monitor-liquidity-drain (pool principal) (current-liquidity uint))
  (begin
    (let ((liquidity-data (map-get? liquidity-tracking { pool: pool })))
      (match liquidity-data
        data
          (let ((initial-liquidity (get initial-liquidity data))
                (drain-rate (if (> initial-liquidity u0)
                              (/ (* (- initial-liquidity current-liquidity) u10000) initial-liquidity)
                              u0)))
            
            (map-set liquidity-tracking
              { pool: pool }
              (merge data {
                current-liquidity: current-liquidity,
                drain-rate: drain-rate,
                last-check: block-height
              }))
            
            ;; Check for critical liquidity drain (>50% loss)
            (if (> drain-rate u5000) ;; 50% drain
              (try! (trigger-circuit-breaker BREAKER_LIQUIDITY_DRAIN drain-rate))
              (ok true)))
        
        ;; Initialize liquidity tracking
        (begin
          (map-set liquidity-tracking
            { pool: pool }
            {
              initial-liquidity: current-liquidity,
              current-liquidity: current-liquidity,
              drain-rate: u0,
              critical-threshold: u5000, ;; 50%
              last-check: block-height
            })
          (ok true)))))

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
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set system-paused false)
    (var-set global-circuit-breaker false)
    
    ;; Reset all circuit breakers
    (try! (reset-all-breakers))
    
    (print {
      event: "emergency-resume-activated",
      admin: tx-sender,
      block-height: block-height
    })
    (ok true)))

(define-private (reset-all-breakers)
  ;; Reset all breaker states (simplified implementation)
  (begin
    (map-set breaker-states { breaker-type: BREAKER_PRICE_VOLATILITY } {
      triggered: false, triggered-at: u0, trigger-value: u0, auto-resume-at: u0, trigger-count: u0
    })
    (map-set breaker-states { breaker-type: BREAKER_VOLUME_SPIKE } {
      triggered: false, triggered-at: u0, trigger-value: u0, auto-resume-at: u0, trigger-count: u0
    })
    (map-set breaker-states { breaker-type: BREAKER_LIQUIDITY_DRAIN } {
      triggered: false, triggered-at: u0, trigger-value: u0, auto-resume-at: u0, trigger-count: u0
    })
    (ok true)))

;; Auto-resume functionality
(define-public (check-auto-resume)
  (begin
    (let ((current-block block-height))
      ;; Check each breaker type for auto-resume
      (try! (check-breaker-auto-resume BREAKER_PRICE_VOLATILITY current-block))
      (try! (check-breaker-auto-resume BREAKER_VOLUME_SPIKE current-block))
      (try! (check-breaker-auto-resume BREAKER_LIQUIDITY_DRAIN current-block))
      
      (print {
        event: "auto-resume-check-completed",
        block-height: current-block
      })
      (ok true))))

(define-private (check-breaker-auto-resume (breaker-type uint) (current-block uint))
  (let ((state (map-get? breaker-states { breaker-type: breaker-type })))
    (match state
      breaker-state
        (if (and (get triggered breaker-state)
                 (> current-block (get auto-resume-at breaker-state))
                 (> (get auto-resume-at breaker-state) u0))
          (begin
            (map-set breaker-states
              { breaker-type: breaker-type }
              (merge breaker-state {
                triggered: false,
                auto-resume-at: u0
              }))
            (print {
              event: "circuit-breaker-auto-resumed",
              breaker-type: breaker-type,
              block-height: current-block
            })
            (ok true))
          (ok true))
      (ok true))))

;; Read-only functions
(define-read-only (is-circuit-breaker-triggered (breaker-type uint))
  (let ((state (map-get? breaker-states { breaker-type: breaker-type })))
    (match state
      breaker-state (get triggered breaker-state)
      false)))

(define-read-only (is-system-operational)
  (and (not (var-get system-paused))
       (not (var-get global-circuit-breaker))))

(define-read-only (get-circuit-breaker (breaker-id uint))
  (map-get? circuit-breakers { breaker-id: breaker-id }))

(define-read-only (get-breaker-state (breaker-type uint))
  (map-get? breaker-states { breaker-type: breaker-type }))

(define-read-only (get-pool-safety-status (pool principal))
  {
    price-volatility-ok: (not (is-circuit-breaker-triggered BREAKER_PRICE_VOLATILITY)),
    volume-spike-ok: (not (is-circuit-breaker-triggered BREAKER_VOLUME_SPIKE)),
    liquidity-drain-ok: (not (is-circuit-breaker-triggered BREAKER_LIQUIDITY_DRAIN)),
    system-operational: (is-system-operational),
    last-check: block-height
  })

(define-read-only (get-volatility-data (pool principal) (window uint))
  (map-get? price-tracking { pool: pool, window: window }))

(define-read-only (get-volume-data (pool principal) (period uint))
  (map-get? volume-tracking { pool: pool, period: period }))

(define-read-only (get-liquidity-data (pool principal))
  (map-get? liquidity-tracking { pool: pool }))

;; Risk assessment
(define-read-only (assess-system-risk)
  (let ((volatility-risk (if (is-circuit-breaker-triggered BREAKER_PRICE_VOLATILITY) u30 u10))
        (volume-risk (if (is-circuit-breaker-triggered BREAKER_VOLUME_SPIKE) u25 u5))
        (liquidity-risk (if (is-circuit-breaker-triggered BREAKER_LIQUIDITY_DRAIN) u35 u10))
        (system-risk (if (var-get global-circuit-breaker) u50 u0)))
    
    (let ((total-risk (+ volatility-risk volume-risk liquidity-risk system-risk)))
      {
        total-risk-score: total-risk,
        risk-level: (if (> total-risk u70) "CRITICAL"
                     (if (> total-risk u40) "HIGH"
                      (if (> total-risk u20) "MEDIUM" "LOW"))),
        volatility-risk: volatility-risk,
        volume-risk: volume-risk,
        liquidity-risk: liquidity-risk,
        system-risk: system-risk,
        assessment-time: block-height
      })))

;; Utility functions
(define-private (max (a uint) (b uint))
  (if (> a b) a b))

(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Administrative functions
(define-public (add-emergency-contact (address principal) (contact-type (string-ascii 20)) (permissions uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    
    (map-set emergency-contacts
      { contact-id: u1 } ;; Simplified single contact
      {
        address: address,
        contact-type: contact-type,
        permissions: permissions,
        active: true
      })
    
    (print {
      event: "emergency-contact-added",
      address: address,
      contact-type: contact-type
    })
    (ok true)))

(define-public (set-emergency-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set emergency-admin new-admin)
    (ok true)))
