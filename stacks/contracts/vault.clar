;; AutoVault Stacks DeFi - Minimal Vault Scaffold
;; It maintains per-user accounting with admin-controlled fees and basic events.

(use-trait sip010 .sip-010-trait.sip-010-trait)
;; Implements the admin surface used by Timelock via trait-typed calls
(impl-trait .vault-admin-trait.vault-admin-trait)
;; DEV: bind to local mock token by default. Admin can update.
(define-data-var token principal .mock-ft)

(define-map shares
  { user: principal }
  { amount: uint }
)

;; User balance tracking for enhanced features
(define-map user-balances
  { user: principal }
  { balance: uint }
)

;; Protocol parameters
(define-constant BPS_DENOM u10000)
(define-data-var admin principal .timelock)
(define-data-var fee-deposit-bps uint u30) ;; 0.30%
(define-data-var fee-withdraw-bps uint u10) ;; 0.10%
(define-data-var performance-fee-bps uint u500) ;; 5.00% on yield above benchmark
(define-data-var flash-loan-fee-bps uint u30) ;; 0.30% flash loan fee
(define-data-var liquidation-fee-bps uint u500) ;; 5.00% liquidation penalty
(define-data-var protocol-reserve uint u0)
(define-data-var total-balance uint u0)
(define-data-var total-shares uint u0)
(define-data-var paused bool false)
(define-data-var global-cap uint u340282366920938463463374607431768211455) ;; max uint
;; Risk controls
(define-data-var user-cap uint u340282366920938463463374607431768211455)
(define-data-var rate-limit-enabled bool false)
(define-data-var block-limit uint u340282366920938463463374607431768211455)
(define-map block-volume
  { height: uint }
  { amount: uint }
)
;; Treasury and fee split
(define-data-var treasury principal tx-sender)
(define-data-var fee-split-bps uint u5000) ;; share of fees to treasury (50% default)
(define-data-var treasury-reserve uint u0)

;; Enhanced revenue tracking
(define-data-var total-fees-collected uint u0)
(define-data-var total-performance-fees uint u0)
(define-data-var yield-benchmark uint u500) ;; 5% annual benchmark for performance fees
(define-data-var last-performance-calculation uint u0)

;; Flash loan tracking
(define-data-var total-flash-loans uint u0)
(define-data-var total-flash-loan-fees uint u0)
(define-data-var last-compound-time uint u0)

;; Compound tracking
(define-data-var total-compounded uint u0)

;; Liquidation tracking  
(define-data-var total-liquidations uint u0)
(define-data-var total-liquidation-fees uint u0)

;; AUTONOMIC ECONOMICS PARAMETERS (PRD ALIGNED)
(define-data-var auto-fees-enabled bool false)
(define-data-var util-high uint u8000) ;; 80% utilization threshold
(define-data-var util-low uint u2000) ;; 20% utilization threshold
(define-data-var min-withdraw-fee uint u5) ;; 0.05% min fee
(define-data-var max-withdraw-fee uint u100) ;; 1.00% max fee

;; Enhanced autonomic economics parameters (reserve bands & ramp configuration)
(define-data-var reserve-target-low-bps uint u500)  ;; 5% of total-balance
(define-data-var reserve-target-high-bps uint u1500) ;; 15% of total-balance
(define-data-var deposit-fee-step-bps uint u5) ;; step change (0.05%) when adjusting
(define-data-var withdraw-fee-step-bps uint u5) ;; step change (0.05%) when adjusting
(define-data-var auto-economics-enabled bool false) ;; master switch for extended autonomics

;; Performance benchmark configuration
(define-data-var performance-benchmark-apy uint u500) ;; 5% APY benchmark for performance fees
(define-data-var benchmark-update-interval uint u144) ;; 24 hours in blocks
(define-data-var last-benchmark-update uint u0)
(define-data-var competitive-yield-tracking bool false) ;; Track competitor yields for optimization

(define-read-only (get-balance (who principal))
  (let (
      (user-shares (default-to u0 (get amount (map-get? shares { user: who }))))
      (ts (var-get total-shares))
      (tb (var-get total-balance))
    )
    (if (is-eq ts u0)
      u0
      (/ (* user-shares tb) ts) ;; floor conversion shares->assets
    )
  )
)

;; helpers
(define-private (min-uint
    (a uint)
    (b uint)
  )
  (if (< a b)
    a
    b
  )
)

(define-private (max-uint
    (a uint)
    (b uint)
  )
  (if (> a b)
    a
    b
  )
)

;; Math helpers for proportional accounting
(define-private (mul-div-floor
    (a uint)
    (b uint)
    (c uint)
  )
  (/ (* a b) c)
)

(define-private (mul-div-ceil
    (a uint)
    (b uint)
    (c uint)
  )
  (if (is-eq c u0)
    u0
    (/ (+ (* a b) (- c u1)) c)
  )
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (get-fees)
  {
    deposit-bps: (var-get fee-deposit-bps),
    withdraw-bps: (var-get fee-withdraw-bps),
    performance-fee-bps: (var-get performance-fee-bps),
    flash-loan-fee-bps: (var-get flash-loan-fee-bps),
    liquidation-fee-bps: (var-get liquidation-fee-bps)
  }
)

(define-read-only (get-protocol-reserve)
  (var-get protocol-reserve))

(define-read-only (get-treasury-reserve)
  (var-get treasury-reserve))

(define-read-only (get-revenue-stats)
  {
    total-fees-collected: (var-get total-fees-collected),
    total-performance-fees: (var-get total-performance-fees),
    total-flash-loan-fees: (var-get total-flash-loan-fees),
    total-liquidation-fees: (var-get total-liquidation-fees),
    treasury-reserve: (var-get treasury-reserve),
    protocol-reserve: (var-get protocol-reserve)
  }
)

(define-read-only (get-total-balance)
  (var-get total-balance)
)

(define-read-only (get-total-shares)
  (var-get total-shares)
)

(define-read-only (get-shares (who principal))
  (default-to u0 (get amount (map-get? shares { user: who })))
)

(define-read-only (get-tvl)
  (var-get total-balance)
)

(define-read-only (get-paused)
  (var-get paused)
)

(define-read-only (get-global-cap)
  (var-get global-cap)
)

(define-read-only (get-token)
  (ok (var-get token))
)

(define-read-only (get-user-cap)
  (var-get user-cap)
)

(define-read-only (get-rate-limit-enabled)
  (var-get rate-limit-enabled)
)

(define-read-only (get-block-limit)
  (var-get block-limit)
)

(define-read-only (get-treasury)
  (ok (var-get treasury))
)

(define-read-only (get-fee-split-bps)
  (var-get fee-split-bps)
)

(define-read-only (get-auto-fees-enabled)
  (var-get auto-fees-enabled)
)

(define-read-only (get-util-thresholds)
  {
    high: (var-get util-high),
    low: (var-get util-low),
  }
)

(define-read-only (get-fee-bounds)
  {
    min: (var-get min-withdraw-fee),
    max: (var-get max-withdraw-fee),
  }
)

(define-read-only (get-reserve-bands)
  {
    low: (var-get reserve-target-low-bps),
    high: (var-get reserve-target-high-bps),
  }
)

(define-read-only (get-fee-ramps)
  {
    deposit-step: (var-get deposit-fee-step-bps),
    withdraw-step: (var-get withdraw-fee-step-bps),
  }
)

;; Performance benchmark and competitive yield tracking getters
(define-read-only (get-performance-benchmark)
  {
    apy-bps: (var-get performance-benchmark-apy),
    last-update: (var-get last-benchmark-update),
    update-interval: (var-get benchmark-update-interval),
    competitive-tracking: (var-get competitive-yield-tracking)
  }
)

(define-read-only (get-autonomous-economics-status)
  {
    auto-fees-enabled: (var-get auto-fees-enabled),
    auto-economics-enabled: (var-get auto-economics-enabled),
    competitive-yield-tracking: (var-get competitive-yield-tracking),
    performance-benchmark: (var-get performance-benchmark-apy)
  }
)

(define-read-only (get-utilization)
  (if (is-eq (var-get global-cap) u0)
    u0
    (/ (* (var-get total-balance) u10000) (var-get global-cap))
  )
)

(define-read-only (get-reserve-ratio)
  (let ((tb (var-get total-balance)))
    (if (is-eq tb u0)
      u0
      (/ (* (var-get protocol-reserve) u10000) tb)
    )
  )
)

(define-public (set-admin (new principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin new)
    (print {
      event: "set-admin",
      caller: tx-sender,
      new: new,
    })
    (ok true)
  )
)

(define-public (set-fees
    (new-deposit-bps uint)
    (new-withdraw-bps uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (<= new-deposit-bps BPS_DENOM) (err u101))
    (asserts! (<= new-withdraw-bps BPS_DENOM) (err u101))
    (var-set fee-deposit-bps new-deposit-bps)
    (var-set fee-withdraw-bps new-withdraw-bps)
    (print {
      event: "set-fees",
      caller: tx-sender,
      deposit-bps: new-deposit-bps,
      withdraw-bps: new-withdraw-bps,
    })
    (ok true)
  )
)

(define-public (set-paused (p bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set paused p)
    (print {
      event: "set-paused",
      caller: tx-sender,
      paused: p,
    })
    (ok true)
  )
)

(define-public (set-global-cap (cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set global-cap cap)
    (print {
      event: "set-global-cap",
      caller: tx-sender,
      cap: cap,
    })
    (ok true)
  )
)

(define-public (set-token (c principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    ;; Safety: only allow token change when vault is paused and empty
    (asserts! (is-eq (var-get paused) true) (err u109))
    (asserts! (is-eq (var-get total-balance) u0) (err u108))
    (var-set token c)
    (print {
      event: "set-token",
      caller: tx-sender,
      token: c,
    })
    (ok true)
  )
)

(define-public (set-treasury (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set treasury p)
    (print {
      event: "set-treasury",
      caller: tx-sender,
      treasury: p,
    })
    (ok true)
  )
)

(define-public (set-fee-split-bps (bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (<= bps BPS_DENOM) (err u101))
    (var-set fee-split-bps bps)
    (print {
      event: "set-fee-split-bps",
      caller: tx-sender,
      bps: bps,
    })
    (ok true)
  )
)

(define-public (set-user-cap (cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set user-cap cap)
    (print {
      event: "set-user-cap",
      caller: tx-sender,
      cap: cap,
    })
    (ok true)
  )
)

(define-public (set-rate-limit
    (enabled bool)
    (cap-per-block uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set rate-limit-enabled enabled)
    (var-set block-limit cap-per-block)
    (print {
      event: "set-rate-limit",
      caller: tx-sender,
      enabled: enabled,
      cap: cap-per-block,
    })
    (ok true)
  )
)

(define-public (set-auto-fees-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set auto-fees-enabled enabled)
    (print {
      event: "set-auto-fees-enabled",
      caller: tx-sender,
      enabled: enabled,
    })
    (ok true)
  )
)

(define-public (set-util-thresholds
    (high uint)
    (low uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (> high low) (err u106)) ;; Ensure high > low
    (var-set util-high high)
    (var-set util-low low)
    (print {
      event: "set-util-thresholds",
      caller: tx-sender,
      high: high,
      low: low,
    })
    (ok true)
  )
)

(define-public (set-fee-bounds
    (min uint)
    (max uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (< min max) (err u107)) ;; Ensure min < max
    (var-set min-withdraw-fee min)
    (var-set max-withdraw-fee max)
    (print {
      event: "set-fee-bounds",
      caller: tx-sender,
      min: min,
      max: max,
    })
    (ok true)
  )
)

;; Set reserve target band (admin / timelock)
(define-public (set-reserve-bands (low-bps uint) (high-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (< low-bps high-bps) (err u107))
    (asserts! (<= high-bps u10000) (err u101))
    (var-set reserve-target-low-bps low-bps)
    (var-set reserve-target-high-bps high-bps)
    (print { event: "set-reserve-bands", low: low-bps, high: high-bps })
    (ok true)
  )
)

;; Set fee ramp step sizes (admin / timelock)
(define-public (set-fee-ramps (deposit-step uint) (withdraw-step uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (> deposit-step u0) (err u1))
    (asserts! (> withdraw-step u0) (err u1))
    (var-set deposit-fee-step-bps deposit-step)
    (var-set withdraw-fee-step-bps withdraw-step)
    (print { event: "set-fee-ramps", dstep: deposit-step, wstep: withdraw-step })
    (ok true)
  )
)

;; Enable/disable extended autonomic economics (distinct from auto-fees-enabled)
(define-public (set-auto-economics-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set auto-economics-enabled enabled)
    (print { event: "set-auto-economics-enabled", enabled: enabled })
    (ok true)
  )
)

;; Set performance benchmark APY for competitive yield optimization
(define-public (set-performance-benchmark (apy-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (<= apy-bps u2000) (err u108)) ;; Max 20% APY benchmark
    (var-set performance-benchmark-apy apy-bps)
    (var-set last-benchmark-update block-height)
    (print { 
      event: "performance-benchmark-updated", 
      apy-bps: apy-bps,
      timestamp: block-height 
    })
    (ok true)
  )
)

;; Enable competitive yield tracking for cross-protocol optimization
(define-public (set-competitive-yield-tracking (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set competitive-yield-tracking enabled)
    (print { 
      event: "competitive-yield-tracking", 
      enabled: enabled,
      timestamp: block-height 
    })
    (ok true)
  )
)

;; Automated yield benchmark adjustment based on market conditions
(define-public (adjust-benchmark-dynamically)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (var-get competitive-yield-tracking) (err u109))
    
    (let ((current-block block-height)
          (last-update (var-get last-benchmark-update))
          (update-interval (var-get benchmark-update-interval)))
      
      ;; Only update benchmark every 24 hours
      (asserts! (>= (- current-block last-update) update-interval) (err u110))
      
      ;; Simulate market-based benchmark adjustment
      ;; Production would integrate with external yield aggregators
      (let ((market-avg-yield u600) ;; 6% market average (simulated)
            (adjustment-factor u50)) ;; 0.5% adjustment buffer
        
        (var-set performance-benchmark-apy (+ market-avg-yield adjustment-factor))
        (var-set last-benchmark-update current-block)
        
        (print {
          event: "benchmark-auto-adjusted",
          old-benchmark: (var-get performance-benchmark-apy),
          new-benchmark: (+ market-avg-yield adjustment-factor),
          market-yield: market-avg-yield,
          timestamp: current-block
        })
        (ok true)
      )
    )
  )
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (is-eq (var-get paused) false) (err u103))
    (asserts! (> amount u0) (err u1))
    (let (
        (user tx-sender)
        (current-shares (default-to u0 (get amount (map-get? shares { user: tx-sender }))))
        (fee (/ (* amount (var-get fee-deposit-bps)) BPS_DENOM))
        (credited (- amount fee))
      )
      (asserts! (<= (+ (var-get total-balance) credited) (var-get global-cap))
        (err u102)
      )
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((cur-assets (if (is-eq ts u0) u0 (/ (* current-shares tb) ts))))
          (asserts! (<= (+ cur-assets credited) (var-get user-cap)) (err u104))
        )
      )
      ;; rate limit check/update
      (let (
          (h block-height)
          (cur (default-to u0
            (get amount (map-get? block-volume { height: block-height }))
          ))
        )
        (if (var-get rate-limit-enabled)
          (asserts! (<= (+ cur amount) (var-get block-limit)) (err u105))
          true
        )
        (map-set block-volume { height: h } { amount: (+ cur amount) })
      )
      ;; Pull tokens from user into the vault using the stored token contract
      (unwrap!
        (as-contract (contract-call? .mock-ft transfer-from user tx-sender amount))
        (err u200)
      )
      ;; Mint shares proportional to current NAV
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((minted (if (or (is-eq ts u0) (is-eq tb u0))
                        credited
                        (mul-div-floor credited ts tb))))
          (map-set shares { user: tx-sender } { amount: (+ current-shares minted) })
          (var-set total-shares (+ ts minted))
        )
      )
      (let (
          (tshare (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
          (pshare (- fee (/ (* fee (var-get fee-split-bps)) BPS_DENOM)))
        )
        (var-set treasury-reserve (+ (var-get treasury-reserve) tshare))
        (var-set protocol-reserve (+ (var-get protocol-reserve) pshare))
      )
      (var-set total-balance (+ (var-get total-balance) credited))
      (print {
        event: "deposit",
        user: tx-sender,
        gross: amount,
        fee: fee,
        net: credited,
      })
      (ok credited)
    )
  )
)

(define-public (deposit-v2 (amount uint) (ft <sip010>))
  (begin
    (asserts! (is-eq (var-get paused) false) (err u103))
    (asserts! (> amount u0) (err u1))
    (asserts! (is-eq (contract-of ft) (var-get token)) (err u201)) ;; invalid-token
    (let (
        (user tx-sender)
        (current-shares (default-to u0 (get amount (map-get? shares { user: tx-sender }))))
        (fee (/ (* amount (var-get fee-deposit-bps)) BPS_DENOM))
        (credited (- amount fee))
      )
      (asserts! (<= (+ (var-get total-balance) credited) (var-get global-cap))
        (err u102)
      )
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((cur-assets (if (is-eq ts u0) u0 (/ (* current-shares tb) ts))))
          (asserts! (<= (+ cur-assets credited) (var-get user-cap)) (err u104))
        )
      )
      ;; rate limit check/update
      (let (
          (h block-height)
          (cur (default-to u0
            (get amount (map-get? block-volume { height: block-height }))
          ))
        )
        (if (var-get rate-limit-enabled)
          (asserts! (<= (+ cur amount) (var-get block-limit)) (err u105))
          true
        )
        (map-set block-volume { height: h } { amount: (+ cur amount) })
      )
      ;; Pull tokens from user into the vault using the provided SIP-010 token
      (unwrap! (as-contract (contract-call? ft transfer-from user tx-sender amount)) (err u200))
      ;; Mint shares proportional to current NAV
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((minted (if (or (is-eq ts u0) (is-eq tb u0))
                        credited
                        (mul-div-floor credited ts tb))))
          (map-set shares { user: tx-sender } { amount: (+ current-shares minted) })
          (var-set total-shares (+ ts minted))
        )
      )
      (let (
          (tshare (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
          (pshare (- fee (/ (* fee (var-get fee-split-bps)) BPS_DENOM)))
        )
        (var-set treasury-reserve (+ (var-get treasury-reserve) tshare))
        (var-set protocol-reserve (+ (var-get protocol-reserve) pshare))
      )
      (var-set total-balance (+ (var-get total-balance) credited))
      (print {
        event: "deposit-v2",
        user: tx-sender,
        gross: amount,
        fee: fee,
        net: credited,
      })
      (ok credited)
    )
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (is-eq (var-get paused) false) (err u103))
    (asserts! (> amount u0) (err u1))
    (let (
        (user tx-sender)
        (current-shares (default-to u0 (get amount (map-get? shares { user: tx-sender }))))
      )
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((cur-assets (if (is-eq ts u0) u0 (/ (* current-shares tb) ts))))
          (asserts! (>= cur-assets amount) (err u2))
        )
      )
      (let (
          (fee (/ (* amount (var-get fee-withdraw-bps)) BPS_DENOM))
          (payout (- amount fee))
        )
        (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
          (let ((burn (mul-div-ceil amount ts tb)))
            (asserts! (>= current-shares burn) (err u2))
            (map-set shares { user: tx-sender } { amount: (- current-shares burn) })
            (var-set total-shares (- ts burn))
          )
        )
        (let (
            (tshare (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
            (pshare (- fee (/ (* fee (var-get fee-split-bps)) BPS_DENOM)))
          )
          (var-set treasury-reserve (+ (var-get treasury-reserve) tshare))
          (var-set protocol-reserve (+ (var-get protocol-reserve) pshare))
        )
        (var-set total-balance (- (var-get total-balance) amount))
        ;; Send net payout using the stored token contract
        (unwrap! (as-contract (contract-call? .mock-ft transfer user payout))
          (err u200)
        )
        (print {
          event: "withdraw",
          user: tx-sender,
          gross: amount,
          fee: fee,
          net: payout,
        })
        (ok payout)
      )
    )
  )
)

(define-public (withdraw-v2 (amount uint) (ft <sip010>))
  (begin
    (asserts! (is-eq (var-get paused) false) (err u103))
    (asserts! (> amount u0) (err u1))
    (asserts! (is-eq (contract-of ft) (var-get token)) (err u201)) ;; invalid-token
    (let (
        (user tx-sender)
        (current-shares (default-to u0 (get amount (map-get? shares { user: tx-sender }))))
      )
      (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
        (let ((cur-assets (if (is-eq ts u0) u0 (/ (* current-shares tb) ts))))
          (asserts! (>= cur-assets amount) (err u2))
        )
      )
      (let (
          (fee (/ (* amount (var-get fee-withdraw-bps)) BPS_DENOM))
          (payout (- amount fee))
        )
        (let ((ts (var-get total-shares)) (tb (var-get total-balance)))
          (let ((burn (mul-div-ceil amount ts tb)))
            (asserts! (>= current-shares burn) (err u2))
            (map-set shares { user: tx-sender } { amount: (- current-shares burn) })
            (var-set total-shares (- ts burn))
          )
        )
        (let (
            (tshare (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
            (pshare (- fee (/ (* fee (var-get fee-split-bps)) BPS_DENOM)))
          )
          (var-set treasury-reserve (+ (var-get treasury-reserve) tshare))
          (var-set protocol-reserve (+ (var-get protocol-reserve) pshare))
        )
        (var-set total-balance (- (var-get total-balance) amount))
        ;; Send net payout using the provided SIP-010 token
        (unwrap! (as-contract (contract-call? ft transfer user payout)) (err u200))
        (print {
          event: "withdraw-v2",
          user: tx-sender,
          gross: amount,
          fee: fee,
          net: payout,
        })
        (ok payout)
      )
    )
  )
)

(define-public (withdraw-reserve
    (to principal)
    (amount uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (> amount u0) (err u1))
    (let ((res (var-get protocol-reserve)))
      (asserts! (>= res amount) (err u2))
      (var-set protocol-reserve (- res amount))
      (unwrap! (as-contract (contract-call? .mock-ft transfer to amount))
        (err u200)
      )
      (print {
        event: "withdraw-reserve",
        caller: tx-sender,
        to: to,
        amount: amount,
      })
      (ok true)
    )
  )
)

(define-public (withdraw-treasury
    (to principal)
    (amount uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (asserts! (> amount u0) (err u1))
    (let ((tres (var-get treasury-reserve)))
      (asserts! (>= tres amount) (err u2))
      (var-set treasury-reserve (- tres amount))
      (unwrap! (as-contract (contract-call? .mock-ft transfer to amount))
        (err u200)
      )
      (print {
        event: "withdraw-treasury",
        caller: tx-sender,
        to: to,
        amount: amount,
      })
      (ok true)
    )
  )
)

(define-public (update-fees-based-on-utilization)
  (let ((util (if (is-eq (var-get global-cap) u0)
      u0
      (/ (* (var-get total-balance) u10000) (var-get global-cap))
    )))
    (if (var-get auto-fees-enabled)
      (if (> util (var-get util-high))
        (var-set fee-withdraw-bps
          (min-uint (var-get max-withdraw-fee) (+ (var-get fee-withdraw-bps) u5))
        )
        (if (< util (var-get util-low))
          (var-set fee-withdraw-bps
            (max-uint (var-get min-withdraw-fee)
              (- (var-get fee-withdraw-bps) u5)
            ))
          true
        )
      )
      true
    )
    (print {
      event: "auto-fee-adjust",
      new-fee: (var-get fee-withdraw-bps),
      utilization: util,
    })
    (ok util)
  )
)

;; Extended autonomic economics controller: adjusts withdraw & deposit fees
;; based on utilization (re-uses update-fees-based-on-utilization) and reserve bands.
;; Anyone may call when enabled to keep system permissionless (like a keeper).
(define-public (update-autonomics)
  (begin
    (asserts! (is-eq (var-get auto-economics-enabled) true) (err u110))
    ;; First adjust withdraw fees via existing utilization controller (if enabled)
    (unwrap! (update-fees-based-on-utilization) (err u111))
    
    ;; Update performance benchmark if competitive tracking enabled
    (if (var-get competitive-yield-tracking)
      (let ((current-block block-height)
            (last-update (var-get last-benchmark-update))
            (update-interval (var-get benchmark-update-interval)))
        (if (>= (- current-block last-update) update-interval)
          (unwrap! (adjust-benchmark-dynamically) (err u112))
          true
        )
      )
      true
    )
    
    ;; Then adjust deposit fee based on reserve ratio vs target band
    (let (
        (ratio (unwrap! (ok (get-reserve-ratio)) (err u0)))
        (low (var-get reserve-target-low-bps))
        (high (var-get reserve-target-high-bps))
        (dstep (var-get deposit-fee-step-bps))
      )
      (if (< ratio low)
        (var-set fee-deposit-bps (min-uint BPS_DENOM (+ (var-get fee-deposit-bps) dstep)))
        (if (> ratio high)
          (var-set fee-deposit-bps (max-uint u0 (if (> (var-get fee-deposit-bps) dstep) (- (var-get fee-deposit-bps) dstep) u0)))
          true
        )
      )
      (print {
        event: "update-autonomics",
        reserve-ratio: ratio,
        new-deposit-fee: (var-get fee-deposit-bps),
        withdraw-fee: (var-get fee-withdraw-bps)
      })
      ;; Analytics hook (best-effort). This will no-op if analytics contract not present at compile deployment time.
      ;; (try! (as-contract (contract-call? .analytics record-vault-event "auto-update" tx-sender u0 "autonomics-adjust")))
      (ok true)
    )
  )
)

;; Errors
;; u1: invalid-amount
;; u2: insufficient-balance
;; u100: unauthorized
;; u101: invalid-fee
;; u102: cap-exceeded
;; u103: paused
;; u104: user-cap-exceeded
;; u105: rate-limit-exceeded
;; u106: invalid-thresholds (high <= low)
;; u107: invalid-fee-bounds (min >= max)
;; u108: token-change-requires-empty-vault
;; u109: token-change-requires-paused

;; === AIP-5: Vault Precision Enhancements ===
(define-constant PRECISION_MULTIPLIER u1000000) ;; 6 decimal places for precision
(define-constant MINIMUM_WITHDRAWAL u1000) ;; Dust protection

(define-data-var precision-enabled bool true)

;; Enhanced precision share calculation
(define-read-only (calculate-shares-precise (amount uint))
  (if (var-get precision-enabled)
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      (* amount PRECISION_MULTIPLIER)
      (/ (* amount total-sh PRECISION_MULTIPLIER) total-bal)))
    ;; Fallback to original calculation
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      amount
      (/ (* amount total-sh) total-bal)))))

;; Enhanced precision balance calculation  
(define-read-only (calculate-balance-precise (share-amount uint))
  (if (var-get precision-enabled)
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      u0
      (/ (* share-amount total-bal PRECISION_MULTIPLIER) total-sh)))
    ;; Fallback to original calculation
    (let (
      (total-bal (var-get total-balance))
      (total-sh (var-get total-shares))
    )
    (if (is-eq total-sh u0)
      u0
      (/ (* share-amount total-bal) total-sh)))))

;; Precision-enhanced deposit function
(define-public (deposit-precise (amount uint))
  (begin
    (asserts! (is-eq (var-get paused) false) (err u103))
    (asserts! (> amount u0) (err u1))
    (let (
        (user tx-sender)
        (current-shares (default-to u0 (get amount (map-get? shares { user: tx-sender }))))
        (fee (/ (* amount (var-get fee-deposit-bps)) BPS_DENOM))
        (credited (- amount fee))
        (minted-shares (calculate-shares-precise credited))
      )
      (asserts! (<= (+ (var-get total-balance) credited) (var-get global-cap))
        (err u102)
      )
      ;; Pull tokens from user into the vault
      (unwrap!
        (contract-call? .mock-ft transfer-from user (as-contract tx-sender) amount)
        (err u200)
      )
      ;; Update shares with precision calculation
      (map-set shares { user: tx-sender } { amount: (+ current-shares minted-shares) })
      (var-set total-shares (+ (var-get total-shares) minted-shares))
      (var-set total-balance (+ (var-get total-balance) credited))
      
      (let (
          (tshare (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
          (pshare (- fee (/ (* fee (var-get fee-split-bps)) BPS_DENOM)))
        )
        (var-set treasury-reserve (+ (var-get treasury-reserve) tshare))
        (var-set protocol-reserve (+ (var-get protocol-reserve) pshare))
      )
      (ok minted-shares))))

;; Admin function to toggle precision mode
(define-public (set-precision-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set precision-enabled enabled)
    (ok true)))

;; Helper function for admin authorization
(define-private (is-authorized-admin)
  (is-eq tx-sender (var-get admin)))

;; Enhanced fee collection with revenue optimization
(define-private (collect-enhanced-fees (amount uint) (fee-type (string-ascii 20)))
  (let ((fee-rate (if (is-eq fee-type "deposit")
                    (var-get fee-deposit-bps)
                    (if (is-eq fee-type "withdraw")
                      (var-get fee-withdraw-bps)
                      (if (is-eq fee-type "performance")
                        (var-get performance-fee-bps)
                        (if (is-eq fee-type "flash-loan")
                          (var-get flash-loan-fee-bps)
                          (var-get liquidation-fee-bps))))))
        (fee (/ (* amount fee-rate) BPS_DENOM))
        (treasury-share (/ (* fee (var-get fee-split-bps)) BPS_DENOM))
        (protocol-share (- fee treasury-share)))
    (var-set treasury-reserve (+ (var-get treasury-reserve) treasury-share))
    (var-set protocol-reserve (+ (var-get protocol-reserve) protocol-share))
    (var-set total-fees-collected (+ (var-get total-fees-collected) fee))
    (if (is-eq fee-type "performance")
      (var-set total-performance-fees (+ (var-get total-performance-fees) fee))
      (if (is-eq fee-type "flash-loan")
        (var-set total-flash-loan-fees (+ (var-get total-flash-loan-fees) fee))
        (if (is-eq fee-type "liquidation")
          (var-set total-liquidation-fees (+ (var-get total-liquidation-fees) fee))
          true)))
    fee))

;; Calculate performance fee based on yield above benchmark
(define-private (calculate-performance-fee (current-yield uint))
  (let ((benchmark (var-get yield-benchmark))
        (excess-yield (if (> current-yield benchmark) (- current-yield benchmark) u0))
        (total-value (var-get total-balance)))
    (if (> excess-yield u0)
      (/ (* total-value excess-yield (var-get performance-fee-bps)) (* BPS_DENOM BPS_DENOM))
      u0)))

;; Flash loan functionality
(define-public (flash-loan (amount uint) (recipient principal))
  (begin
    (asserts! (not (var-get paused)) (err u103))
    (asserts! (> amount u0) (err u1))
    (asserts! (<= amount (var-get total-balance)) (err u2))
    
    (let ((fee (collect-enhanced-fees amount "flash-loan"))
          (total-owed (+ amount fee)))
      
      ;; Transfer loan amount to recipient
      (unwrap! (as-contract (contract-call? .mock-ft transfer recipient amount)) (err u200))
      
      ;; Update tracking
      (var-set total-flash-loans (+ (var-get total-flash-loans) u1))
      (var-set total-balance (- (var-get total-balance) amount))
      
      ;; Recipient must return amount + fee in same transaction
      ;; This is simplified - in production would use callback pattern
      (unwrap! (contract-call? .mock-ft transfer-from recipient (as-contract tx-sender) total-owed) (err u201))
      
      (var-set total-balance (+ (var-get total-balance) amount))
      
      (print {
        event: "flash-loan",
        recipient: recipient,
        amount: amount,
        fee: fee,
        block: block-height
      })
      (ok fee)
    )
  )
)

;; Automated yield optimization and compound strategies
(define-public (execute-compound-strategy)
  (begin
    (asserts! (not (var-get paused)) (err u103))
    (asserts! (is-authorized-admin) (err u100))
    
    (let ((current-block block-height)
          (last-compound (var-get last-compound-time))
          (compound-interval u144)) ;; 24 hours in blocks
      
      ;; Only compound once per day
      (asserts! (>= (- current-block last-compound) compound-interval) (err u301))
      
      (let ((treasury-balance (var-get treasury-reserve))
            (compound-amount (/ treasury-balance u4))) ;; Compound 25% of treasury
        
        ;; Execute compound strategy
        (if (> compound-amount u1000) ;; Minimum threshold
          (begin
            ;; Simulate yield generation through automated treasury allocation
            (var-set total-balance (+ (var-get total-balance) compound-amount))
            (var-set treasury-reserve (- treasury-balance compound-amount))
            (var-set last-compound-time current-block)
            (var-set total-compounded (+ (var-get total-compounded) compound-amount))
            
            (print {
              event: "compound-executed",
              amount: compound-amount,
              new-balance: (var-get total-balance),
              block: block-height
            })
            (ok compound-amount)
          )
          (ok u0)
        )
      )
    )
  )
)

;; Liquidation functions for undercollateralized positions
(define-public (liquidate-position (user principal) (amount uint))
  (begin
    (asserts! (not (var-get paused)) (err u103))
    (asserts! (> amount u0) (err u1))
    
    (let ((user-balance (default-to u0 (get balance (map-get? user-balances { user: user }))))
          (liquidation-threshold (/ (* user-balance u8) u10)) ;; 80% threshold
          (penalty-fee (collect-enhanced-fees amount "liquidation")))
      
      ;; Check if position is undercollateralized (simplified)
      (asserts! (< user-balance liquidation-threshold) (err u302))
      
      ;; Execute liquidation
      (map-set user-balances { user: user } { balance: (if (> user-balance amount) (- user-balance amount) u0) })
      (var-set total-balance (if (> (var-get total-balance) amount) (- (var-get total-balance) amount) u0))
      
      ;; Transfer liquidated amount minus penalty to liquidator
      (let ((liquidator-reward (- amount penalty-fee)))
        (unwrap! (as-contract (contract-call? .mock-ft transfer tx-sender liquidator-reward)) (err u200))
        
        (print {
          event: "liquidation",
          user: user,
          liquidator: tx-sender,
          amount: amount,
          penalty: penalty-fee,
          reward: liquidator-reward,
          block: block-height
        })
        (ok liquidator-reward)
      )
    )
  )
)

(define-public (transfer-revenue (recipient principal) (amount uint))
  (begin
    (asserts! (is-authorized-admin) (err u100))
    (asserts! (<= amount (var-get treasury-reserve)) (err u105))
    (var-set treasury-reserve (- (var-get treasury-reserve) amount))
    (unwrap! (as-contract (stx-transfer? amount tx-sender recipient)) (err u200))
    (ok true)))

;; Calculate shares for a given amount (used by multi-token strategies)
(define-read-only (calculate-shares (amount uint))
  (let ((ts (var-get total-shares)) 
        (tb (var-get total-balance)))
    (if (or (is-eq ts u0) (is-eq tb u0))
      (ok amount)  ;; Bootstrap case: 1:1 ratio
      (ok (mul-div-floor amount ts tb))  ;; Proportional shares
    )
  )
)

;; u200: token-transfer-failed
;; u201: invalid-token
