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

;; Protocol parameters
(define-constant BPS_DENOM u10000)
(define-data-var admin principal tx-sender)
(define-data-var fee-deposit-bps uint u30) ;; 0.30%
(define-data-var fee-withdraw-bps uint u10) ;; 0.10%
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

;; AUTONOMIC ECONOMICS PARAMETERS (PRD ALIGNED)
(define-data-var auto-fees-enabled bool false)
(define-data-var util-high uint u8000) ;; 80% utilization threshold
(define-data-var util-low uint u2000) ;; 20% utilization threshold
(define-data-var min-withdraw-fee uint u5) ;; 0.05% min fee
(define-data-var max-withdraw-fee uint u100) ;; 1.00% max fee

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
  }
)

(define-read-only (get-protocol-reserve)
  (var-get protocol-reserve)
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

(define-read-only (get-treasury-reserve)
  (var-get treasury-reserve)
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
      ;; Pull tokens from user into the vault using the default mock token; v2 entrypoint supports dynamic tokens
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
        ;; Send net payout using the default mock token; v2 entrypoint supports dynamic tokens
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
;; u200: token-transfer-failed
;; u201: invalid-token
