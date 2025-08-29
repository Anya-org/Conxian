;; =============================================================================
;; TWAP ORACLE V2 - MANIPULATION RESISTANT (Refactored)
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED u400)
(define-constant ERR_INVALID_PAIR u401)
(define-constant ERR_INSUFFICIENT_HISTORY u402)
(define-constant ERR_MANIPULATION_DETECTED u403)
(define-constant ERR_STALE_PRICE u404)
(define-constant ERR_INVALID_PERIOD u405)

;; Constants
(define-constant DEFAULT_TWAP_PERIOD u144)          ;; ~24h (assuming ~10m blocks)
(define-constant MAX_PRICE_AGE u6)                  ;; stale after 6 blocks
(define-constant MANIPULATION_THRESHOLD u500)       ;; 5.00% (basis points *100)
(define-constant MAX_OBSERVATIONS u256)             ;; ring buffer size
(define-constant MAX_SAMPLE u5)                     ;; we only sample last 5 for lightweight TWAP

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var manipulation-detection-enabled bool true)
(define-data-var max-price-age-blocks uint MAX_PRICE_AGE)

;; Maps
(define-map pair-config
  {token-a: principal, token-b: principal}
  {min-liquidity: uint, twap-period: uint, active: bool, observation-index: uint})

(define-map price-observations
  {pair: {token-a: principal, token-b: principal}, index: uint}
  {timestamp: uint, price: uint, liquidity: uint, volume: uint, block-height: uint})

(define-map twap-cache
  {pair: {token-a: principal, token-b: principal}, period: uint}
  {twap-price: uint, calculated-at: uint, valid-until: uint, observations-used: uint})

(define-map manipulation-flags
  {pair: {token-a: principal, token-b: principal}}
  {detected: bool, detection-block: uint, price-deviation: uint, volume-spike: uint})

;; Helpers
(define-private (min (a uint) (b uint)) (if (< a b) a b))
(define-private (max-u (a uint) (b uint)) (if (> a b) a b))
(define-private (is-owner) (is-eq tx-sender (var-get contract-owner)))

;; Compute average of last N observations (bounded by MAX_SAMPLE)
(define-private (compute-average-last-n (pair {token-a: principal, token-b: principal}) (n uint))
  ;; Returns {CXG, count} over up to last n (capped at MAX_SAMPLE) observations.
  (match (map-get? pair-config pair)
    cfg
  (let (
    (n-capped (if (> n MAX_SAMPLE) MAX_SAMPLE n))
            (start-index (get observation-index cfg))
            (idx0 start-index)
            (idx1 (if (> start-index u0) (- start-index u1) (- MAX_OBSERVATIONS u1)))
            (idx2 (if (> idx1 u0) (- idx1 u1) (- MAX_OBSERVATIONS u1)))
            (idx3 (if (> idx2 u0) (- idx2 u1) (- MAX_OBSERVATIONS u1)))
            (idx4 (if (> idx3 u0) (- idx3 u1) (- MAX_OBSERVATIONS u1)))
            (obs0 (map-get? price-observations {pair: pair, index: idx0}))
            (obs1 (map-get? price-observations {pair: pair, index: idx1}))
            (obs2 (map-get? price-observations {pair: pair, index: idx2}))
            (obs3 (map-get? price-observations {pair: pair, index: idx3}))
            (obs4 (map-get? price-observations {pair: pair, index: idx4}))
            ;; fold
            (sum0 u0) (cnt0 u0)
            (sum1 (match obs0 obs (if (> n-capped u0) (+ sum0 (get price obs)) sum0) sum0))
            (cnt1 (match obs0 obs (if (> n-capped u0) (+ cnt0 u1) cnt0) cnt0))
            (sum2 (if (< cnt1 n-capped) (match obs1 obs (+ sum1 (get price obs)) sum1) sum1))
            (cnt2 (if (< cnt1 n-capped) (match obs1 obs (+ cnt1 u1) cnt1) cnt1))
            (sum3 (if (< cnt2 n-capped) (match obs2 obs (+ sum2 (get price obs)) sum2) sum2))
            (cnt3 (if (< cnt2 n-capped) (match obs2 obs (+ cnt2 u1) cnt2) cnt2))
            (sum4 (if (< cnt3 n-capped) (match obs3 obs (+ sum3 (get price obs)) sum3) sum3))
            (cnt4 (if (< cnt3 n-capped) (match obs3 obs (+ cnt3 u1) cnt3) cnt3))
            (sum5 (if (< cnt4 n-capped) (match obs4 obs (+ sum4 (get price obs)) sum4) sum4))
            (cnt5 (if (< cnt4 n-capped) (match obs4 obs (+ cnt4 u1) cnt4) cnt4)))
        (if (is-eq cnt5 u0)
          {CXG: u0, count: u0}
          {CXG: (/ sum5 cnt5), count: cnt5}))
    {CXG: u0, count: u0}))

;; Manipulation detection
(define-private (check-for-manipulation (pair {token-a: principal, token-b: principal}) (current-price uint) (current-volume uint))
  (let ((CXG-info (compute-average-last-n pair u5)))
    (if (>= (get count CXG-info) u2)
      (let ((CXG-price (get CXG CXG-info))
            (deviation (if (> current-price (get CXG CXG-info))
                        (/ (* (- current-price (get CXG CXG-info)) u10000) (max-u u1 (get CXG CXG-info)))
                        (/ (* (- (get CXG CXG-info) current-price) u10000) (max-u u1 (get CXG CXG-info))))))
        (if (> deviation MANIPULATION_THRESHOLD)
          (begin
            (map-set manipulation-flags {pair: pair} {detected: true, detection-block: block-height, price-deviation: deviation, volume-spike: current-volume})
            (err ERR_MANIPULATION_DETECTED))
          (ok true)))
      (ok true))))

;; Calculate fresh TWAP for a period (simple mean of up to last 5 within window)
(define-private (calculate-fresh-twap (pair {token-a: principal, token-b: principal}) (period uint))
  (let ((cfg (unwrap! (map-get? pair-config pair) (err ERR_INVALID_PAIR)))
        (current-index (get observation-index (unwrap! (map-get? pair-config pair) (err ERR_INVALID_PAIR))))
        (start-height (if (> block-height period) (- block-height period) u0)))
    (let (
          (idx0 current-index)
          (idx1 (if (> current-index u0) (- current-index u1) (- MAX_OBSERVATIONS u1)))
          (idx2 (if (> idx1 u0) (- idx1 u1) (- MAX_OBSERVATIONS u1)))
          (idx3 (if (> idx2 u0) (- idx2 u1) (- MAX_OBSERVATIONS u1)))
          (idx4 (if (> idx3 u0) (- idx3 u1) (- MAX_OBSERVATIONS u1))))
      (let (
            (obs0 (map-get? price-observations {pair: pair, index: idx0}))
            (obs1 (map-get? price-observations {pair: pair, index: idx1}))
            (obs2 (map-get? price-observations {pair: pair, index: idx2}))
            (obs3 (map-get? price-observations {pair: pair, index: idx3}))
            (obs4 (map-get? price-observations {pair: pair, index: idx4})))
        (let (
              (sum0 u0) (cnt0 u0)
              (sum1 (match obs0 obs (if (>= (get block-height obs) start-height) (+ sum0 (get price obs)) sum0) sum0))
              (cnt1 (match obs0 obs (if (>= (get block-height obs) start-height) (+ cnt0 u1) cnt0) cnt0))
              (sum2 (match obs1 obs (if (>= (get block-height obs) start-height) (+ sum1 (get price obs)) sum1) sum1))
              (cnt2 (match obs1 obs (if (>= (get block-height obs) start-height) (+ cnt1 u1) cnt1) cnt1))
              (sum3 (match obs2 obs (if (>= (get block-height obs) start-height) (+ sum2 (get price obs)) sum2) sum2))
              (cnt3 (match obs2 obs (if (>= (get block-height obs) start-height) (+ cnt2 u1) cnt2) cnt2))
              (sum4 (match obs3 obs (if (>= (get block-height obs) start-height) (+ sum3 (get price obs)) sum3) sum3))
              (cnt4 (match obs3 obs (if (>= (get block-height obs) start-height) (+ cnt3 u1) cnt3) cnt3))
              (sum5 (match obs4 obs (if (>= (get block-height obs) start-height) (+ sum4 (get price obs)) sum4) sum4))
              (cnt5 (match obs4 obs (if (>= (get block-height obs) start-height) (+ cnt4 u1) cnt4) cnt4)))
          (if (is-eq cnt5 u0)
            (err ERR_INSUFFICIENT_HISTORY)
            (let ((CXG (/ sum5 cnt5)))
              (begin
                (map-set twap-cache {pair: pair, period: period} {twap-price: CXG, calculated-at: block-height, valid-until: (+ block-height (min period u10)), observations-used: cnt5})
                (ok CXG)))))))))

;; Public: get TWAP
(define-public (get-twap-price (token-a principal) (token-b principal) (period uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (asserts! (is-some (map-get? pair-config pair)) (err ERR_INVALID_PAIR))
    (asserts! (> period u0) (err ERR_INVALID_PERIOD))
    (match (map-get? twap-cache {pair: pair, period: period})
      cache (if (< block-height (get valid-until cache)) (ok (get twap-price cache)) (calculate-fresh-twap pair period))
      (calculate-fresh-twap pair period))))

;; Public: observe new price
(define-public (observe-price (token-a principal) (token-b principal) (price uint) (liquidity uint) (volume uint))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (let ((cfg? (map-get? pair-config pair)))
      (asserts! (is-some cfg?) (err ERR_INVALID_PAIR))
      (let ((cfg (unwrap! cfg? (err ERR_INVALID_PAIR))))
        (asserts! (>= liquidity (get min-liquidity cfg)) (err ERR_INVALID_PAIR))
        (asserts! (get active cfg) (err ERR_INVALID_PAIR))
        (let ((next-index (mod (+ (get observation-index cfg) u1) MAX_OBSERVATIONS)))
          (map-set price-observations {pair: pair, index: next-index} {timestamp: block-height, price: price, liquidity: liquidity, volume: volume, block-height: block-height})
          (map-set pair-config pair {min-liquidity: (get min-liquidity cfg), twap-period: (get twap-period cfg), active: (get active cfg), observation-index: next-index})
          (if (var-get manipulation-detection-enabled)
            (let ((res (check-for-manipulation pair price volume)))
              (match res okv (ok true) errv (err errv)))
            (ok true)))))))

;; Admin
(define-public (initialize-pair (token-a principal) (token-b principal) (min-liquidity uint) (twap-period uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set pair-config {token-a: token-a, token-b: token-b} {min-liquidity: min-liquidity, twap-period: twap-period, active: true, observation-index: u0})
    (ok true)))

(define-public (set-manipulation-detection (enabled bool))
  (begin (asserts! (is-owner) (err ERR_UNAUTHORIZED)) (var-set manipulation-detection-enabled enabled) (ok true)))

(define-public (set-max-price-age (new-age uint))
  (begin (asserts! (is-owner) (err ERR_UNAUTHORIZED)) (var-set max-price-age-blocks new-age) (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin (asserts! (is-owner) (err ERR_UNAUTHORIZED)) (var-set contract-owner new-owner) (ok true)))

;; Read-only
(define-read-only (get-pair-config (token-a principal) (token-b principal))
  (map-get? pair-config {token-a: token-a, token-b: token-b}))

(define-read-only (get-latest-price (token-a principal) (token-b principal))
  (let ((pair {token-a: token-a, token-b: token-b}))
    (match (map-get? pair-config pair)
      cfg (map-get? price-observations {pair: pair, index: (get observation-index cfg)})
      none)))

(define-read-only (get-manipulation-status (token-a principal) (token-b principal))
  (map-get? manipulation-flags {pair: {token-a: token-a, token-b: token-b}}))

(define-read-only (is-price-stale (token-a principal) (token-b principal))
  (match (get-latest-price token-a token-b)
    obs (> (- block-height (get block-height obs)) (var-get max-price-age-blocks))
    true))
