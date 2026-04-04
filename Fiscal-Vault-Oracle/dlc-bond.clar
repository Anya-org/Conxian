;; dlc-bond.clar
;; Bitcoin-native DLC Bond Lifecycle (sBTC-backed)
;;
;; Implements:
;; - Initialization (issuer + parameters)
;; - Principal subscription (sBTC in, bond FT out)
;; - Coupon funding + distribution (pro-rata via cumulative index)
;; - Redemption (burn bond FT, return sBTC principal; optionally early on default)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(impl-trait .sip-standards.sip-010-ft-trait)

;; Errors
(define-constant ERR_UNAUTHORIZED u20000)
(define-constant ERR_ALREADY_INITIALIZED u20001)
(define-constant ERR_NOT_INITIALIZED u20002)
(define-constant ERR_INACTIVE u20003)
(define-constant ERR_ZERO_AMOUNT u20004)
(define-constant ERR_NOT_MATURED u20005)
(define-constant ERR_COUPON_NOT_DUE u20006)
(define-constant ERR_INVALID_COUPON_AMOUNT u20007)
(define-constant ERR_INVALID_DEFAULT_FLAG u20008)
(define-constant ERR_SUBSCRIPTION_CLOSED u20009)
(define-constant ERR_PRINCIPAL_DRAWDOWN_DISABLED u20010)
(define-constant ERR_NO_LIQUIDITY u20011)
(define-constant ERR_INVALID_SBTC_TOKEN u20012)
(define-constant ERR_ALREADY_ISSUED u20013)
(define-constant ERR_COUPONS_DISABLED_IN_RECOVERY u20014)
(define-constant ERR_PRINCIPAL_DRAWDOWN_EXCEEDED u20015)
(define-constant ERR_PRINCIPAL_DRAWDOWN_ALREADY_ENABLED u20016)
(define-constant ERR_DEFAULTED u20017)
(define-constant ERR_NOT_PAUSED u20018)
(define-constant ERR_PRINCIPAL_DRAWDOWN_WINDOW_CLOSED u20019)

;; Fixed point constants
(define-constant PPM_DENOM u1000000)          ;; 1.0 = 1,000,000 ppm
(define-constant INDEX_PRECISION u1000000000) ;; Coupon index precision

;; Defaults (per `BITCOIN_BOND_DLC.json`)
(define-constant DEFAULT_COUPON_INTERVAL_BLOCKS u1440)
(define-constant DEFAULT_APR_PPM u45000)       ;; 4.5% APR
(define-constant DEFAULT_COUPON_PPM u3750)     ;; 4.5% / 12 = 0.375% monthly
(define-constant DEFAULT_BLOCKS_PER_YEAR (* DEFAULT_COUPON_INTERVAL_BLOCKS u12))

;; State
(define-data-var initialized bool false)
(define-data-var active bool false)
(define-data-var issuer principal tx-sender)
(define-data-var dlc-oracle principal tx-sender)
(define-data-var sbtc-token principal tx-sender)

(define-data-var maturity-height uint u0)
(define-data-var coupon-interval-blocks uint DEFAULT_COUPON_INTERVAL_BLOCKS)
(define-data-var coupon-ppm uint DEFAULT_COUPON_PPM)
(define-data-var next-coupon-height uint u0)

(define-data-var defaulted bool false)
(define-data-var defaulted-at (optional uint) none)
(define-data-var principal-drawdown-enabled bool false)
;; Cumulative drawdown total (capped at dlc-bond total supply).
(define-data-var principal-drawdown-used uint u0)

;; Global coupon index (scaled by INDEX_PRECISION)
(define-data-var coupon-index uint u0)
;; Remainder carried forward when converting funded coupon amounts into index increments.
(define-data-var coupon-index-remainder uint u0)

;; Bond token (1:1 with principal units deposited)
(define-fungible-token dlc-bond)

;; Per-holder coupon accounting
(define-map holder-coupons { holder: principal } {
  index: uint,
  accrued: uint
})

(define-private (bond-contract)
  (as-contract tx-sender)
)

(define-private (assert-issuer)
  (asserts! (is-eq tx-sender (var-get issuer)) (err ERR_UNAUTHORIZED))
)

(define-private (assert-oracle)
  (asserts! (is-eq tx-sender (var-get dlc-oracle)) (err ERR_UNAUTHORIZED))
)

(define-private (assert-active)
  (asserts! (var-get active) (err ERR_INACTIVE))
)

(define-private (do-declare-default)
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-oracle)
    (if (var-get defaulted)
      (ok false)
      (begin
        (var-set defaulted true)
        (var-set defaulted-at (some burn-block-height))
        (print { event: "dlc-bond-defaulted", defaulted: true, oracle: tx-sender, at: burn-block-height })
        (ok true)
      )
    )
  )
)

(define-private (get-sbtc-balance)
  (contract-call? (var-get sbtc-token) get-balance (bond-contract))
)

(define-private (get-holder-state (holder principal))
  (default-to { index: (var-get coupon-index), accrued: u0 }
    (map-get? holder-coupons { holder: holder }))
)

(define-private (compute-claimable (holder principal))
  (let (
    (state (get-holder-state holder))
    (balance (ft-get-balance dlc-bond holder))
    (global-index (var-get coupon-index))
    (holder-index (get index state))
  )
    (+ (get accrued state)
      (/ (* balance (- global-index holder-index)) INDEX_PRECISION))
  )
)

(define-private (sync-holder (holder principal))
  (let (
    (state (get-holder-state holder))
    (claimable (compute-claimable holder))
  )
    (map-set holder-coupons { holder: holder } {
      index: (var-get coupon-index),
      accrued: claimable
    })
  )
)

(define-read-only (get-config)
  (ok {
    initialized: (var-get initialized),
    active: (var-get active),
    issuer: (var-get issuer),
    dlc-oracle: (var-get dlc-oracle),
    sbtc-token: (var-get sbtc-token),
    maturity-height: (var-get maturity-height),
    coupon-interval-blocks: (var-get coupon-interval-blocks),
    coupon-ppm: (var-get coupon-ppm),
    next-coupon-height: (var-get next-coupon-height),
    defaulted: (var-get defaulted),
    defaulted-at: (var-get defaulted-at),
    principal-drawdown-enabled: (var-get principal-drawdown-enabled),
    principal-drawdown-used: (var-get principal-drawdown-used)
  })
)

(define-read-only (get-principal-drawdown-used)
  (ok (var-get principal-drawdown-used))
)

(define-read-only (get-principal-drawdown-capacity)
  (let (
    (supply (ft-get-supply dlc-bond))
    (used (var-get principal-drawdown-used))
  )
    (ok (if (<= used supply) (- supply used) u0))
  )
)

(define-read-only (get-bond-total-supply)
  (ok (ft-get-supply dlc-bond))
)

(define-read-only (get-bond-balance (holder principal))
  (ok (ft-get-balance dlc-bond holder))
)

(define-read-only (get-claimable-coupon (holder principal))
  (ok (compute-claimable holder))
)

;; Initialization
(define-public (initialize (token <sip-010-ft-trait>) (maturity uint) (oracle principal))
  (begin
    (assert-issuer)
    (asserts! (not (var-get initialized)) (err ERR_ALREADY_INITIALIZED))
    (asserts! (> maturity burn-block-height) (err ERR_NOT_MATURED))
    (var-set initialized true)
    (var-set active true)
    (var-set dlc-oracle oracle)
    (var-set sbtc-token (contract-of token))
    (var-set maturity-height maturity)
    (var-set coupon-interval-blocks DEFAULT_COUPON_INTERVAL_BLOCKS)
    (var-set coupon-ppm DEFAULT_COUPON_PPM)
    (var-set next-coupon-height (+ burn-block-height DEFAULT_COUPON_INTERVAL_BLOCKS))
    (print { event: "dlc-bond-initialized", issuer: (var-get issuer), sbtc: (contract-of token), maturity: maturity, oracle: oracle })
    (ok true)
  )
)

(define-public (set-active (is-active bool))
  (begin
    (assert-issuer)
    (var-set active is-active)
    (ok true)
  )
)

(define-public (set-defaulted (is-defaulted bool))
  (begin
    (asserts! is-defaulted (err ERR_INVALID_DEFAULT_FLAG))
    (do-declare-default)
  )
)

(define-public (declare-default)
  (do-declare-default)
)

(define-public (enable-principal-drawdown)
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-issuer)
    (asserts! (is-eq (ft-get-supply dlc-bond) u0) (err ERR_ALREADY_ISSUED))
    (asserts! (not (var-get principal-drawdown-enabled)) (err ERR_PRINCIPAL_DRAWDOWN_ALREADY_ENABLED))
    (var-set principal-drawdown-enabled true)
    (print { event: "dlc-bond-principal-drawdown-enabled", issuer: (var-get issuer) })
    (ok true)
  )
)

(define-public (drawdown-principal (amount uint) (recipient principal))
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-issuer)
    (asserts! (var-get principal-drawdown-enabled) (err ERR_PRINCIPAL_DRAWDOWN_DISABLED))
    (asserts! (not (var-get defaulted)) (err ERR_DEFAULTED))
    (asserts! (not (var-get active)) (err ERR_NOT_PAUSED))
    (asserts! (is-eq (var-get coupon-index) u0) (err ERR_PRINCIPAL_DRAWDOWN_WINDOW_CLOSED))
    (asserts! (< burn-block-height (var-get next-coupon-height)) (err ERR_PRINCIPAL_DRAWDOWN_WINDOW_CLOSED))
    (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
    (let (
      (supply (ft-get-supply dlc-bond))
      (used (var-get principal-drawdown-used))
    )
      (asserts! (<= used supply) (err ERR_PRINCIPAL_DRAWDOWN_EXCEEDED))
      (asserts! (<= amount (- supply used)) (err ERR_PRINCIPAL_DRAWDOWN_EXCEEDED))
      (let ((available (unwrap! (get-sbtc-balance) (err ERR_INVALID_SBTC_TOKEN))))
        (asserts! (> available u0) (err ERR_NO_LIQUIDITY))
        (asserts! (<= amount available) (err ERR_NO_LIQUIDITY))
      )
      (var-set principal-drawdown-used (+ used amount))
      (try!
        (as-contract (contract-call? (var-get sbtc-token) transfer amount tx-sender recipient none))
      )
    )
    (print { event: "dlc-bond-principal-drawdown", issuer: (var-get issuer), recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-private (is-recovery)
  (and (var-get defaulted) (var-get principal-drawdown-enabled))
)

;; Bond token (SIP-010 style)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    memo
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (sync-holder sender)
    (sync-holder recipient)
    (try! (ft-transfer? dlc-bond amount sender recipient))
    (ok true)
  )
)

(define-read-only (get-name) (ok "Conxian Bitcoin DLC Bond"))
(define-read-only (get-symbol) (ok "CXBD"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-total-supply) (ok (ft-get-supply dlc-bond)))
(define-read-only (get-token-uri) (ok none))
(define-read-only (get-balance (owner principal)) (ok (ft-get-balance dlc-bond owner)))

;; Lifecycle
(define-public (subscribe (amount uint))
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-active)
    (asserts! (not (var-get defaulted)) (err ERR_INACTIVE))
    (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
    (asserts! (< burn-block-height (var-get maturity-height)) (err ERR_NOT_MATURED))

    ;; Bond-style issuance window: subscriptions are only allowed before the first
    ;; coupon distribution, and never once the next coupon is due.
    (asserts! (is-eq (var-get coupon-index) u0) (err ERR_SUBSCRIPTION_CLOSED))
    (asserts! (< burn-block-height (var-get next-coupon-height)) (err ERR_SUBSCRIPTION_CLOSED))

    ;; Move principal (sBTC) into the bond contract
    (try! (contract-call? (var-get sbtc-token) transfer amount tx-sender (bond-contract) none))

    ;; Mint bond tokens 1:1 with deposited principal
    (sync-holder tx-sender)
    (try! (ft-mint? dlc-bond amount tx-sender))
    (print { event: "dlc-bond-subscribed", holder: tx-sender, amount: amount })
    (ok true)
  )
)

(define-read-only (get-coupon-due)
  (let ((supply (ft-get-supply dlc-bond)))
    (ok (/ (* supply (var-get coupon-ppm)) PPM_DENOM))
  )
)

(define-public (fund-and-distribute-coupon)
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-active)
    (assert-issuer)
    (asserts! (not (var-get defaulted)) (err ERR_INACTIVE))
    (asserts! (>= burn-block-height (var-get next-coupon-height)) (err ERR_COUPON_NOT_DUE))

    (let (
      (supply (ft-get-supply dlc-bond))
      (coupon-amount (unwrap-panic (get-coupon-due)))
    )
      (asserts! (> supply u0) (err ERR_ZERO_AMOUNT))
      (asserts! (> coupon-amount u0) (err ERR_ZERO_AMOUNT))

      ;; Issuer funds coupon payment in sBTC
      (try! (contract-call? (var-get sbtc-token) transfer coupon-amount tx-sender (bond-contract) none))

      ;; Update global coupon index
      ;; Carry forward remainder to reduce permanently unallocated coupon dust.
      (let (
        (numerator (+ (* coupon-amount INDEX_PRECISION) (var-get coupon-index-remainder)))
        (inc (/ numerator supply))
        (rem (- numerator (* inc supply)))
      )
        (var-set coupon-index (+ (var-get coupon-index) inc))
        (var-set coupon-index-remainder rem)
      )
      (var-set next-coupon-height (+ (var-get next-coupon-height) (var-get coupon-interval-blocks)))

      (print { event: "dlc-bond-coupon-distributed", amount: coupon-amount, supply: supply, next: (var-get next-coupon-height) })
      (ok coupon-amount)
    )
  )
)

(define-public (claim-coupon)
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (asserts! (not (is-recovery)) (err ERR_COUPONS_DISABLED_IN_RECOVERY))
    (sync-holder tx-sender)
    (let (
      (state (get-holder-state tx-sender))
      (amount (get accrued state))
      (recipient tx-sender)
    )
      (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
      (map-set holder-coupons { holder: recipient } { index: (get index state), accrued: u0 })
      (try!
        (as-contract (contract-call? (var-get sbtc-token) transfer amount tx-sender recipient none))
      )
      (print { event: "dlc-bond-coupon-claimed", holder: recipient, amount: amount })
      (ok amount)
    )
  )
)

(define-public (redeem (amount uint))
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))

    (let (
      (is-matured (>= burn-block-height (var-get maturity-height)))
      (is-defaulted (var-get defaulted))
    )
      (asserts! (or is-matured is-defaulted) (err ERR_NOT_MATURED))
    )

    (sync-holder tx-sender)
    (let (
      (state (get-holder-state tx-sender))
      (coupon-amount (get accrued state))
      (recipient tx-sender)
    )
      (if (is-recovery)
        (let (
          (supply (ft-get-supply dlc-bond))
          (available (unwrap! (get-sbtc-balance) (err ERR_INVALID_SBTC_TOKEN)))
        )
          (asserts! (> supply u0) (err ERR_ZERO_AMOUNT))
          (asserts! (> available u0) (err ERR_NO_LIQUIDITY))
          (let ((principal-paid (if (is-eq amount supply) available (/ (* available amount) supply))))
            (asserts! (> principal-paid u0) (err ERR_NO_LIQUIDITY))
            (try! (ft-burn? dlc-bond amount recipient))
            (map-set holder-coupons { holder: recipient } { index: (get index state), accrued: u0 })
            (try! (as-contract (contract-call? (var-get sbtc-token) transfer principal-paid tx-sender recipient none)))
            (print { event: "dlc-bond-redeemed", holder: recipient, principal: principal-paid, coupon: u0 })
            (ok { principal: principal-paid, coupon: u0 })
          )
        )
        (begin
          (try! (ft-burn? dlc-bond amount recipient))
          (map-set holder-coupons { holder: recipient } { index: (get index state), accrued: u0 })

          ;; Pay any unclaimed coupon first, then principal
          (if (> coupon-amount u0)
            (try! (as-contract (contract-call? (var-get sbtc-token) transfer coupon-amount tx-sender recipient none)))
            true
          )
          (try! (as-contract (contract-call? (var-get sbtc-token) transfer amount tx-sender recipient none)))
          (print { event: "dlc-bond-redeemed", holder: recipient, principal: amount, coupon: coupon-amount })
          (ok { principal: amount, coupon: coupon-amount })
        )
      )
    )
  )
)

(define-public (set-coupon-params (interval-blocks uint) (new-coupon-ppm uint))
  (begin
    (asserts! (var-get initialized) (err ERR_NOT_INITIALIZED))
    (assert-issuer)
    (asserts! (> interval-blocks u0) (err ERR_ZERO_AMOUNT))
    (let ((periods-per-year (/ (+ DEFAULT_BLOCKS_PER_YEAR (- interval-blocks u1)) interval-blocks)))
      (asserts!
        (<= (* new-coupon-ppm periods-per-year) DEFAULT_APR_PPM)
        (err ERR_INVALID_COUPON_AMOUNT)
      )
    )
    (var-set coupon-interval-blocks interval-blocks)
    (var-set coupon-ppm new-coupon-ppm)
    (let (
      (candidate-next (+ burn-block-height interval-blocks))
      (current-next (var-get next-coupon-height))
    )
      ;; Prevent postponing an already-scheduled coupon by increasing the interval.
      (var-set next-coupon-height (if (< candidate-next current-next) candidate-next current-next))
    )
    (ok true)
  )
)
