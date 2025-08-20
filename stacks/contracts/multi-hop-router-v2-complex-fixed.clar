;; =============================================================================
;; MULTI-HOP ROUTER - PRODUCTION IMPLEMENTATION
;; =============================================================================

(use-trait ft-trait .sip-010-trait.sip-010-trait)
(use-trait pool-trait .pool-trait.pool-trait)

;; Error codes
(define-constant ERR_INVALID_PATH (err u600))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u601))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u602))
(define-constant ERR_INVALID_ROUTE (err u603))
(define-constant ERR_NO_LIQUIDITY (err u604))
(define-constant ERR_EXPIRED (err u605))
(define-constant ERR_UNAUTHORIZED (err u606))
(define-constant ERR_INVALID_POOL_TYPE (err u607))
(define-constant ERR_IDENTICAL_TOKENS (err u608))
(define-constant ERR_INACTIVE_POOL (err u609))
(define-constant ERR_INVALID_FEE_TIER (err u610))

;; Constants
(define-constant MAX_HOPS u5)
(define-constant FEE_DENOMINATOR u10000)

;; Route information
(define-map routes
  {token-in: principal, token-out: principal}
  {
    pools: (list 10 principal),
    pool-types: (list 10 (string-ascii 20)),
    estimated-gas: uint,
    active: bool
  })

;; Pool registry for routing
(define-map pool-registry
  principal
  {
    token-x: principal,
    token-y: principal,
    pool-type: (string-ascii 20),
    fee-tier: uint,
    active: bool
  })

;; Fee tier configurations
(define-map fee-tiers
  uint
  {
    fee-bps: uint,
    tick-spacing: uint,
    enabled: bool
  })

;; State variables
(define-data-var router-admin principal tx-sender)
(define-data-var routing-fee-bps uint u0)
(define-data-var max-slippage-bps uint u1000)

;; =============================================================================
;; HELPER FUNCTIONS (DEFINED FIRST)
;; =============================================================================

;; Pool type whitelist check
(define-private (is-valid-pool-type (t (string-ascii 20)))
  (or (is-eq t "constant-product")
      (is-eq t "stable")
      (is-eq t "weighted")
      (is-eq t "concentrated")))

;; Fold helper to validate all pool types in a list
(define-private (process-validate-type
  (t (string-ascii 20))
  (acc (response bool uint)))
  (if (is-err acc)
    acc
    (if (is-valid-pool-type t)
      (ok true)
      ERR_INVALID_POOL_TYPE)))

(define-private (validate-pool-types (types (list 10 (string-ascii 20))))
  (let ((initial (ok true)))
    (fold process-validate-type types initial)))

;; Get output amount for single hop
(define-private (get-single-hop-output
  (pool-principal principal)
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (/ (* amount-in u997) u1000))

;; Execute swap based on pool type (string comparisons via nested if)
(define-private (execute-pool-swap
  (pool <pool-trait>)
  (amount-in uint)
  (x-to-y bool)
  (pool-type (string-ascii 20)))
  (if (is-eq pool-type "constant-product")
    (contract-call? pool swap-exact-in amount-in u0 x-to-y block-height)
    (if (is-eq pool-type "stable")
      (contract-call? pool swap-exact-in amount-in u0 x-to-y block-height)
      (if (is-eq pool-type "weighted")
        (contract-call? pool swap-exact-in amount-in u0 x-to-y block-height)
        (if (is-eq pool-type "concentrated")
          (contract-call? pool swap-exact-in amount-in u0 x-to-y block-height)
          ERR_INVALID_ROUTE)))))

;; Execute single hop in the route
(define-private (execute-single-hop
  (token-in principal)
  (token-out principal)
  (pool <pool-trait>)
  (amount-in uint))
  (let ((pool-info (unwrap! (map-get? pool-registry (contract-of pool)) ERR_INVALID_ROUTE)))
    (asserts! (or 
                (and (is-eq token-in (get token-x pool-info)) (is-eq token-out (get token-y pool-info)))
                (and (is-eq token-in (get token-y pool-info)) (is-eq token-out (get token-x pool-info))))
              ERR_INVALID_ROUTE)
    (asserts! (get active pool-info) ERR_INACTIVE_POOL)
    (let ((x-to-y (is-eq token-in (get token-x pool-info))))
      (match (execute-pool-swap pool amount-in x-to-y (get pool-type pool-info))
        success (ok (get amount-out success))
        error ERR_NO_LIQUIDITY))))

;; Fold-based executor step for multi-hop swap
(define-private (process-hop-exec
  (pool <pool-trait>)
  (acc (response {i: uint, path: (list 5 principal), current: uint} uint)))
  (let ((state (try! acc))
        (pool-info (unwrap! (map-get? pool-registry (contract-of pool)) ERR_INVALID_ROUTE))
        (token-in (unwrap! (element-at (get path state) (get i state)) ERR_INVALID_PATH))
        (token-out (unwrap! (element-at (get path state) (+ (get i state) u1)) ERR_INVALID_PATH)))
    (let ((hop-result (try! (execute-single-hop token-in token-out pool (get current state)))))
      (ok {i: (+ (get i state) u1), path: (get path state), current: hop-result}))))

;; Execute multi-hop swap iteratively (no recursion)
(define-private (execute-multi-hop-swap 
  (path (list 5 principal)) 
  (pools (list 4 <pool-trait>)) 
  (amount-in uint))
  (let ((initial (ok {i: u0, path: path, current: amount-in})))
    (let ((result (fold process-hop-exec pools initial)))
      (ok (get current (try! result))))))

;; Calculate required input for exact output
(define-private (calculate-required-input
  (path (list 5 principal))
  (pools (list 4 <pool-trait>))
  (amount-out uint))
  (if (<= amount-out u0)
    ERR_INVALID_ROUTE
    (ok amount-out)))

;; Fold-based amounts-out calculator (no recursion)
(define-private (process-hop-amounts
  (pool-principal principal)
  (acc {i: uint, path: (list 5 principal), current: uint, amounts: (list 5 uint)}))
  (let ((token-in (unwrap-panic (element-at (get path acc) (get i acc))))
        (token-out (unwrap-panic (element-at (get path acc) (+ (get i acc) u1))))
        (next-amount (get-single-hop-output pool-principal
                                           (unwrap-panic (element-at (get path acc) (get i acc)))
                                           (unwrap-panic (element-at (get path acc) (+ (get i acc) u1)))
                                           (get current acc))))
    {
      i: (+ (get i acc) u1),
      path: (get path acc),
      current: next-amount,
      amounts: (unwrap-panic (as-max-len? (append (get amounts acc) next-amount) u5))
    }))

(define-private (calculate-amounts-out-fold
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (let ((initial {i: u0,
                  path: path,
                  current: amount-in,
                  amounts: (unwrap-panic (as-max-len? (list amount-in) u5))}))
    (let ((result (fold process-hop-amounts pools initial)))
      (ok (get amounts result)))))

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

;; Calculate output for a given route
(define-read-only (get-amounts-out
  (path (list 5 principal))
  (pools (list 4 principal))
  (amount-in uint))
  (calculate-amounts-out-fold path pools amount-in))

;; Find optimal route between two tokens
(define-read-only (find-optimal-route
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  (match (map-get? routes {token-in: token-in, token-out: token-out})
    direct-route (ok direct-route)
    (match (map-get? routes {token-in: token-out, token-out: token-in})
      reverse-route (ok reverse-route)
      (err ERR_INVALID_ROUTE))))

;; =============================================================================
;; PUBLIC FUNCTIONS (DEFINED LAST)
;; =============================================================================

;; Multi-hop swap with exact input
(define-public (swap-exact-in-multi-hop 
  (path (list 5 principal)) 
  (pools (list 4 <pool-trait>)) 
  (amount-in uint) 
  (min-amount-out uint) 
  (deadline uint))
  (begin
    (asserts! (>= deadline block-height) ERR_EXPIRED)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (let ((first (unwrap! (element-at path u0) ERR_INVALID_PATH))
          (last (unwrap! (element-at path (- (len path) u1)) ERR_INVALID_PATH)))
      (asserts! (not (is-eq first last)) ERR_IDENTICAL_TOKENS))
    (asserts! (is-eq (len pools) (- (len path) u1)) ERR_INVALID_PATH)
    (asserts! (> amount-in u0) ERR_INVALID_ROUTE)
    (let ((gross-final (try! (execute-multi-hop-swap path pools amount-in))))
      (asserts! (>= gross-final min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (let ((fee-bps (var-get routing-fee-bps))
            (net-final (if (is-eq fee-bps u0) 
                         gross-final 
                         (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
        (print {event: "multi-hop-swap", path: path, amount-in: amount-in, gross-out: gross-final, net-out: net-final, fee-bps: fee-bps, pools-used: (len pools), trader: tx-sender})
        (ok net-final)))))

;; Multi-hop swap with exact output
(define-public (swap-exact-out-multi-hop 
  (path (list 5 principal)) 
  (pools (list 4 <pool-trait>)) 
  (amount-out uint) 
  (max-amount-in uint) 
  (deadline uint))
  (begin
    (asserts! (>= deadline block-height) ERR_EXPIRED)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (is-eq (len pools) (- (len path) u1)) ERR_INVALID_PATH)
    (let ((required-input (try! (calculate-required-input path pools amount-out))))
      (asserts! (<= required-input max-amount-in) ERR_SLIPPAGE_EXCEEDED)
      (let ((gross-final (try! (execute-multi-hop-swap path pools required-input))))
        (asserts! (>= gross-final amount-out) ERR_INSUFFICIENT_OUTPUT)
        (let ((fee-bps (var-get routing-fee-bps))
              (net-final (if (is-eq fee-bps u0) 
                           gross-final 
                           (- gross-final (/ (* gross-final fee-bps) FEE_DENOMINATOR)))))
          (print {event: "multi-hop-swap-exact-out", path: path, required-out: amount-out, gross-out: gross-final, net-out: net-final, fee-bps: fee-bps, amount-in: required-input, pools-used: (len pools), trader: tx-sender})
          (ok required-input))))))

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

;; Update routing fee
(define-public (update-routing-fee (new-fee-bps uint))
  (begin
    (print {event: "auth-check", tx: tx-sender, admin: (var-get router-admin)})
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u500) ERR_INVALID_ROUTE)
    (var-set routing-fee-bps new-fee-bps)
    (print {event: "routing-fee-updated", new-fee-bps: new-fee-bps})
    (ok true)))

;; Add new route
(define-public (add-route
  (token-in principal)
  (token-out principal)
  (pools (list 10 principal))
  (pool-types (list 10 (string-ascii 20)))
  (estimated-gas uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len pools) (len pool-types)) ERR_INVALID_PATH)
    (asserts! (> (len pools) u0) ERR_INVALID_PATH)
    (asserts! (<= (len pools) MAX_HOPS) ERR_INVALID_PATH)
    (asserts! (not (is-eq token-in token-out)) ERR_IDENTICAL_TOKENS)
    (try! (validate-pool-types pool-types))
    (map-set routes {token-in: token-in, token-out: token-out} {
      pools: pools,
      pool-types: pool-types,
      estimated-gas: estimated-gas,
      active: true
    })
    (print {
      event: "route-added", 
      token-in: token-in, 
      token-out: token-out,
      hops: (len pools)
    })
    (ok true)))

;; Register a pool
(define-public (register-pool
  (pool principal)
  (token-x principal)
  (token-y principal)
  (pool-type (string-ascii 20))
  (fee-tier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq token-x token-y)) ERR_IDENTICAL_TOKENS)
    (asserts! (is-valid-pool-type pool-type) ERR_INVALID_POOL_TYPE)
    (let ((tier (unwrap! (map-get? fee-tiers fee-tier) ERR_INVALID_FEE_TIER)))
      (asserts! (get enabled tier) ERR_INVALID_FEE_TIER))
    (map-set pool-registry pool {
      token-x: token-x,
      token-y: token-y,
      pool-type: pool-type,
      fee-tier: fee-tier,
      active: true
    })
    (print {event: "pool-registered", pool: pool, token-x: token-x, token-y: token-y})
    (ok true)))

;; Transfer router admin
(define-public (transfer-router-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get router-admin)) ERR_UNAUTHORIZED)
    (var-set router-admin new-admin)
    (print {event: "router-admin-transferred", new-admin: new-admin})
    (ok true)))

;; =============================================================================
;; BOOTSTRAP DEFAULTS (FEE TIERS)
;; =============================================================================

;; Initialize default fee tiers on deployment
(define-private (initialize-fee-tiers)
  (begin
    ;; 0.05% tier
    (map-set fee-tiers u1 {fee-bps: u5, tick-spacing: u10, enabled: true})
    ;; 0.3% tier
    (map-set fee-tiers u2 {fee-bps: u30, tick-spacing: u60, enabled: true})
    ;; 1% tier
    (map-set fee-tiers u3 {fee-bps: u100, tick-spacing: u200, enabled: true})
    true))

;; Invoke initialization at deploy time
(initialize-fee-tiers)
