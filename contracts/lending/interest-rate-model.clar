;; interest-rate-model.clar
;; Interest Rate Model with Kink-Based Curves (Aave/Compound Style)
;; Conxian Protocol Standard Contract
;; Compliant with CXIP-013 and Sovereign Autonomy ethos
;;
;; Interest Rate Model Formula:
;; - Below Kink: rate = baseRate + (utilization * slope1)
;; - Above Kink: rate = kinkRate + ((utilization - kink) * slope2)
;;
;; Rates are in basis points (10000 = 100%)

;; --- Error Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_PARAM (err u1002))
(define-constant ERR_ASSET_NOT_FOUND (err u1003))

;; --- Global Constants ---
(define-constant BASE_RATE_DEFAULT u0)        ;; 0% base rate
(define-constant SLOPE1_DEFAULT u400)         ;; 4% slope below kink
(define-constant SLOPE2_DEFAULT u8000)       ;; 80% slope above kink
(define-constant KINK_DEFAULT u8000)         ;; 80% optimal utilization
(define-constant RESERVE_FACTOR_DEFAULT u1000) ;; 10% reserve factor

;; --- Asset Parameters Storage ---
(define-map asset-params
  principal
  {
    base-rate: uint,      ;; Base borrow rate (bps/year)
    slope1: uint,         ;; Slope below kink (bps/year per bps utilization)
    slope2: uint,         ;; Slope above kink (bps/year per bps utilization)
    kink: uint,           ;; Optimal utilization point (bps)
    reserve-factor: uint,  ;; Portion of interest that goes to reserves (bps)
    enabled: bool
  }
)

;; --- Admin ---
(define-data-var admin principal tx-sender)

;; --- Read-Only Functions ---

;; @desc Get the borrow rate for an asset given utilization (in basis points).
;; @param asset: The asset principal.
;; @param utilization: The market utilization in basis points (0-10000).
;; @returns (response uint uint) Borrow rate in basis points per year.
(define-read-only (get-borrow-rate (asset principal) (utilization uint))
  (match (map-get? asset-params asset)
    params
    (ok (calculate-borrow-rate params utilization))
    (ok (calculate-borrow-rate {
      base-rate: BASE_RATE_DEFAULT,
      slope1: SLOPE1_DEFAULT,
      slope2: SLOPE2_DEFAULT,
      kink: KINK_DEFAULT,
      reserve-factor: RESERVE_FACTOR_DEFAULT,
      enabled: true
    } utilization))
  )
)

;; @desc Get the supply rate for an asset given utilization.
;; @param asset: The asset principal.
;; @param utilization: The market utilization in basis points (0-10000).
;; @returns (response uint uint) Supply rate in basis points per year.
(define-read-only (get-supply-rate (asset principal) (utilization uint))
  (match (map-get? asset-params asset)
    params
    (ok (calculate-supply-rate params utilization))
    (ok (calculate-supply-rate {
      base-rate: BASE_RATE_DEFAULT,
      slope1: SLOPE1_DEFAULT,
      slope2: SLOPE2_DEFAULT,
      kink: KINK_DEFAULT,
      reserve-factor: RESERVE_FACTOR_DEFAULT,
      enabled: true
    } utilization))
  )
)

;; @desc Returns the current interest rate parameters for an asset.
;; @param asset: The asset principal.
;; @returns (optional { base-rate, slope1, slope2, kink, reserve-factor, enabled })
(define-read-only (get-asset-params (asset principal))
  (map-get? asset-params asset)
)

;; @desc Returns utilization rate given total deposits and borrows.
;; @param total-deposits: Total deposits in the market.
;; @param total-borrows: Total borrows in the market.
;; @returns (response uint uint) Utilization in basis points.
(define-read-only (get-utilization-rate (total-deposits uint) (total-borrows uint))
  (ok (if (is-eq total-deposits u0)
    u0
    (min u10000 (/ (* total-borrows u10000) total-deposits))
  ))
)

;; --- Private Calculation Functions ---

;; @desc Calculate borrow rate based on utilization curve.
;; @param params: Interest rate parameters.
;; @param utilization: Current utilization in basis points.
;; @returns uint: Borrow rate in basis points per year.
(define-private (calculate-borrow-rate (params { base-rate: uint, slope1: uint, slope2: uint, kink: uint, reserve-factor: uint, enabled: bool }) (utilization uint))
  (let (
    (base-rate (get base-rate params))
    (slope1 (get slope1 params))
    (slope2 (get slope2 params))
    (kink (get kink params))
  )
    (if (< utilization kink)
      ;; Below kink: baseRate + utilization * slope1
      (+ base-rate (/ (* utilization slope1) u10000))
      ;; Above kink: kinkRate + excess * slope2
      (let (
        (kink-rate (+ base-rate (/ (* kink slope1) u10000)))
        (excess (- utilization kink))
      )
        (+ kink-rate (/ (* excess slope2) u10000))
      )
    )
  )
)

;; @desc Calculate supply rate from borrow rate.
;; @desc supplyRate = borrowRate * utilization * (1 - reserveFactor)
;; @param params: Interest rate parameters.
;; @param utilization: Current utilization in basis points.
;; @returns uint: Supply rate in basis points per year.
(define-private (calculate-supply-rate (params { base-rate: uint, slope1: uint, slope2: uint, kink: uint, reserve-factor: uint, enabled: bool }) (utilization uint))
  (let (
    (borrow-rate (calculate-borrow-rate params utilization))
    (reserve-factor (get reserve-factor params))
    (utilization-factor (- u10000 reserve-factor))
  )
    (/ (* borrow-rate utilization utilization-factor) (* u10000 u10000))
  )
)

;; @desc Safe min function for Clarity.
(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

;; --- Admin Functions ---

;; @desc Set interest rate parameters for an asset.
;; @param asset: The asset principal.
;; @param base-rate: Base borrow rate in basis points.
;; @param slope1: Slope below kink.
;; @param slope2: Slope above kink.
;; @param kink: Optimal utilization point (bps).
;; @param reserve-factor: Reserve factor (bps).
;; @returns (response bool uint)
(define-public (set-asset-params
  (asset principal)
  (base-rate uint)
  (slope1 uint)
  (slope2 uint)
  (kink uint)
  (reserve-factor uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (< kink u10001) ERR_INVALID_PARAM)
    (asserts! (<= reserve-factor u10000) ERR_INVALID_PARAM)
    (map-set asset-params asset {
      base-rate: base-rate,
      slope1: slope1,
      slope2: slope2,
      kink: kink,
      reserve-factor: reserve-factor,
      enabled: true
    })
    (print { event: "interest-rate-updated", asset: asset, base-rate: base-rate, slope1: slope1, slope2: slope2, kink: kink })
    (ok true)
  )
)

;; @desc Enable or disable interest accrual for an asset.
;; @param asset: The asset principal.
;; @param enabled: Whether interest accrual is enabled.
;; @returns (response bool uint)
(define-public (set-asset-enabled (asset principal) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (match (map-get? asset-params asset)
      params (map-set asset-params asset (merge params { enabled: enabled }))
      (err ERR_ASSET_NOT_FOUND)
    )
    (ok true)
  )
)

;; @desc Remove an asset's interest rate configuration.
;; @param asset: The asset principal.
;; @returns (response bool uint)
(define-public (remove-asset (asset principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-delete asset-params asset)
    (ok true)
  )
)

;; @desc Initialize the contract with an admin.
;; @param new-admin: The admin principal.
;; @returns (response bool uint)
(define-public (initialize (new-admin principal))
  (begin
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Transfer admin rights to a new principal.
;; @param new-admin: The new admin principal.
;; @returns (response bool uint)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- Pre-configured Market Parameters ---

;; @desc Set conservative STX parameters (higher rates for volatility).
;; @param asset: The STX asset principal.
;; @returns (response bool uint)
(define-public (configure-stx-market (asset principal))
  (set-asset-params
    asset
    u100    ;; base-rate: 1%
    u500    ;; slope1: 5%
    u10000  ;; slope2: 100%
    u7000   ;; kink: 70%
    u1500   ;; reserve-factor: 15%
  )
)

;; @desc Set standard sBTC parameters (lower rates for stability).
;; @param asset: The sBTC asset principal.
;; @returns (response bool uint)
(define-public (configure-sbtc-market (asset principal))
  (set-asset-params
    asset
    u0      ;; base-rate: 0%
    u300    ;; slope1: 3%
    u6000   ;; slope2: 60%
    u8000   ;; kink: 80%
    u1000   ;; reserve-factor: 10%
  )
)

;; @desc Set aggressive ALT parameters (max yield for volatile assets).
;; @param asset: The ALT asset principal.
;; @returns (response bool uint)
(define-public (configure-alt-market (asset principal))
  (set-asset-params
    asset
    u200    ;; base-rate: 2%
    u800    ;; slope1: 8%
    u15000  ;; slope2: 150%
    u6500   ;; kink: 65%
    u2000   ;; reserve-factor: 20%
  )
)

;; --- Utility Functions ---

;; @desc Calculate the annual borrow interest for a given amount and rate.
;; @param amount: The borrow amount.
;; @param borrow-rate: The annual borrow rate in basis points.
;; @param seconds: The duration in seconds.
;; @returns uint: The interest amount.
(define-read-only (calculate-interest (amount uint) (borrow-rate uint) (seconds uint))
  (/ (* amount borrow-rate seconds) (* u10000 u31536000))
)

;; @desc Get protocol status for dashboard.
;; @returns (ok { admin: principal })
(define-read-only (get-protocol-status)
  (ok { 
    model-version: "v1.0.0",
    admin: (var-get admin)
  })
)
