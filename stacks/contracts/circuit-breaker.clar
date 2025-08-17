;; AutoVault Circuit Breaker (Minimal Clean Version)
;; Focus: basic monitoring (price, volume, liquidity) + emergency halt. Removed corrupted sections.

;; Error codes
(define-constant ERR_UNAUTHORIZED u401)
(define-constant ERR_EMERGENCY_STOP u405)

;; Breaker types
(define-constant BREAKER_PRICE_VOLATILITY u1)
(define-constant BREAKER_VOLUME_SPIKE u2)
(define-constant BREAKER_LIQUIDITY_DRAIN u3)

;; Core state
(define-data-var admin principal tx-sender)
(define-data-var emergency-admin principal tx-sender)
(define-data-var system-paused bool false)
(define-data-var global-circuit-breaker bool false)
;; Optional external oracle integration
(define-data-var oracle-enabled bool false)
(define-data-var oracle-contract (optional principal) none)

(define-public (set-oracle-config (enabled bool) (oracle principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set oracle-enabled enabled)
    (var-set oracle-contract (if enabled (some oracle) none))
    (print { event: "cb-set-oracle", enabled: enabled, oracle: oracle })
    (ok true)))

;; Breaker state
(define-map breaker-states { breaker-type: uint } {
  triggered: bool,
  triggered-at: uint,
  trigger-value: uint
})

;; Tracking maps
(define-map price-tracking { pool: principal, window: uint } {
  high: uint,
  low: uint,
  start: uint,
  vol: uint
})

(define-map volume-tracking { pool: principal, period: uint } {
  volume: uint,
  baseline: uint,
  ratio: uint
})

(define-map liquidity-tracking { pool: principal } {
  initial: uint,
  current: uint,
  drain: uint
})

;; Auth helpers
(define-private (is-admin) (is-eq tx-sender (var-get admin)))
(define-private (is-emergency-admin) (or (is-admin) (is-eq tx-sender (var-get emergency-admin))))

;; Trigger breaker (internal use by monitors & manual)
(define-public (trigger-circuit-breaker (breaker-type uint) (value uint))
  (begin
    (asserts! (not (var-get system-paused)) (err ERR_EMERGENCY_STOP))
    (map-set breaker-states { breaker-type: breaker-type } {
      triggered: true,
      triggered-at: block-height,
      trigger-value: value
    })
    (var-set global-circuit-breaker true)
    (print { event: "breaker-trigger", code: u1001, breaker-type: breaker-type, value: value, height: block-height })
    (ok true)))

;; Utility
(define-private (calc-vol (s uint) (h uint) (l uint))
  (if (> s u0) (/ (* (- h l) u10000) s) u0))

;; Price volatility monitor
(define-public (monitor-price-volatility (pool principal) (price uint))
  (let ((window u144) (w (/ block-height window)))
    (let ((d (map-get? price-tracking { pool: pool, window: w })))
      (match d prev
        (let ((hi (if (> price (get high prev)) price (get high prev)))
              (lo (if (< price (get low prev)) price (get low prev)))
              (v (calc-vol (get start prev) hi lo)))
          (map-set price-tracking { pool: pool, window: w } { high: hi, low: lo, start: (get start prev), vol: v })
          (if (> v u2000)
            (trigger-circuit-breaker BREAKER_PRICE_VOLATILITY v)
            (ok true)))
        (begin
          (map-set price-tracking { pool: pool, window: w } { high: price, low: price, start: price, vol: u0 })
          (ok true))))))

;; Convenience wrapper pulling price from oracle when enabled
;; NOTE: Currently simplified - in production, would use dynamic contract-call
;; For now, oracle integration is feature-flagged but calls direct oracle-aggregator
(define-public (monitor-price-volatility-oracle (pool principal) (base principal) (quote principal))
  (let ((enabled (var-get oracle-enabled)))
    (if enabled
        (let ((res (contract-call? .oracle-aggregator get-price base quote)))
          (match res 
            price-data (let ((p (get price price-data)))
                        (monitor-price-volatility pool p))
            err-val (err ERR_UNAUTHORIZED)))
        (err ERR_UNAUTHORIZED))))

;; Volume spike monitor
(define-public (monitor-volume-spike (pool principal) (amount uint))
  (let ((period u144) (p (/ block-height period)))
    (let ((d (map-get? volume-tracking { pool: pool, period: p })))
      (match d prev
        (let ((vol (+ (get volume prev) amount))
              (base (get baseline prev))
              (ratio (if (> base u0) (/ vol base) u0)))
          (map-set volume-tracking { pool: pool, period: p } { volume: vol, baseline: base, ratio: ratio })
          ;; ratio is an unscaled multiple (e.g. 6 = 600%), threshold 5 => 500%
          (if (> ratio u5)
            (trigger-circuit-breaker BREAKER_VOLUME_SPIKE ratio)
            (ok true)))
        (begin
          (map-set volume-tracking { pool: pool, period: p } { volume: amount, baseline: amount, ratio: u100 })
          (ok true))))))

;; Liquidity drain monitor
(define-public (monitor-liquidity-drain (pool principal) (current uint))
  (let ((d (map-get? liquidity-tracking { pool: pool })))
    (match d prev
      (let ((init (get initial prev))
            (drain (if (> init u0) (/ (* (- init current) u10000) init) u0)))
        (map-set liquidity-tracking { pool: pool } { initial: init, current: current, drain: drain })
        (if (> drain u5000)
          (trigger-circuit-breaker BREAKER_LIQUIDITY_DRAIN drain)
          (ok true)))
      (begin
        (map-set liquidity-tracking { pool: pool } { initial: current, current: current, drain: u0 })
        (ok true)))))

;; Emergency controls
(define-public (emergency-pause)
  (begin
    (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
    (var-set system-paused true)
    (var-set global-circuit-breaker true)
    (print { event: "emergency-pause", code: u1002, sender: tx-sender, height: block-height })
    (ok true)))

(define-public (emergency-resume)
  (begin
    (asserts! (is-emergency-admin) (err ERR_UNAUTHORIZED))
    (var-set system-paused false)
    (var-set global-circuit-breaker false)
    (print { event: "emergency-resume", code: u1003, sender: tx-sender, height: block-height })
    (ok true)))

;; Read-only helpers
(define-read-only (is-circuit-breaker-triggered (breaker-type uint))
  (let ((s (map-get? breaker-states { breaker-type: breaker-type })))
    (match s st (get triggered st) false)))

(define-read-only (is-system-operational)
  (and (not (var-get system-paused)) (not (var-get global-circuit-breaker))))

(define-read-only (risk-summary)
  {
    price: (is-circuit-breaker-triggered BREAKER_PRICE_VOLATILITY),
    volume: (is-circuit-breaker-triggered BREAKER_VOLUME_SPIKE),
    liquidity: (is-circuit-breaker-triggered BREAKER_LIQUIDITY_DRAIN),
    halted: (var-get global-circuit-breaker),
    operational: (is-system-operational),
    checked-at: block-height
  })

;; Admin maintenance
(define-public (set-admin (new-admin principal))
  (begin (asserts! (is-admin) (err ERR_UNAUTHORIZED)) (var-set admin new-admin) (ok true)))

(define-public (set-emergency-admin (new-admin principal))
  (begin (asserts! (is-admin) (err ERR_UNAUTHORIZED)) (var-set emergency-admin new-admin) (ok true)))
