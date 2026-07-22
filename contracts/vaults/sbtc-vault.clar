;; sbtc-vault.clar
;;
;; Phase 2A sBTC custody and share-accounting core.
;;
;; This contract accepts already-issued canonical sBTC only after the admin
;; injects its contract principal through set-approved-token. It does not mint
;; or burn sBTC, bridge BTC, verify a peg, or allocate funds to a strategy.

(impl-trait .vault-traits.vault-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; --- Errors ---------------------------------------------------------------
(define-constant ERR_UNAUTHORIZED u5100)
(define-constant ERR_TOKEN_NOT_CONFIGURED u5101)
(define-constant ERR_TOKEN_MISMATCH u5102)
(define-constant ERR_ZERO_AMOUNT u5103)
(define-constant ERR_NON_COMPLIANT u5104)
(define-constant ERR_COMPLIANCE_CALL u5105)
(define-constant ERR_PAUSED u5106)
(define-constant ERR_CAP_NOT_SET u5107)
(define-constant ERR_CAP_EXCEEDED u5108)
(define-constant ERR_INVALID_CAP u5109)
(define-constant ERR_CAP_BELOW_ASSETS u5110)
(define-constant ERR_INSUFFICIENT_ASSETS u5111)
(define-constant ERR_INSUFFICIENT_SHARES u5112)
(define-constant ERR_ZERO_SHARES u5113)
(define-constant ERR_TOKEN_CALL u5114)
(define-constant ERR_ARITHMETIC u5115)
(define-constant ERR_ACTIVE_VAULT u5116)
(define-constant ERR_STRATEGY_DISABLED u5117)

;; --- Bounds and state -----------------------------------------------------
(define-constant MAX_UINT u340282366920938463463374607431768211455)

(define-data-var admin principal tx-sender)
(define-data-var vault-principal principal (as-contract tx-sender))
(define-data-var approved-token (optional principal) none)
(define-data-var deposit-cap uint u0)
(define-data-var paused bool false)
(define-data-var total-assets uint u0)
(define-data-var total-shares uint u0)

(define-map user-shares principal uint)

;; --- Defensive helpers ---------------------------------------------------

(define-private (is-admin)
  ;; Use the immediate caller so an admin cannot accidentally delegate config
  ;; authority through an untrusted forwarding contract.
  (is-eq contract-caller (var-get admin))
)

(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    (err ERR_ARITHMETIC)
    (ok (+ left right))
  )
)

(define-private (safe-multiply (left uint) (right uint))
  (if (or (is-eq left u0) (is-eq right u0))
    (ok u0)
    (if (> left (/ MAX_UINT right))
      (err ERR_ARITHMETIC)
      (ok (* left right))
    )
  )
)

(define-private (ceil-div (numerator uint) (denominator uint))
  (let (
    (quotient (/ numerator denominator))
    (remainder (mod numerator denominator))
  )
    (if (> remainder u0)
      (safe-add quotient u1)
      (ok quotient)
    )
  )
)

(define-private (assert-approved-token (token <sip-010-ft-trait>))
  (match (var-get approved-token)
    configured
      (if (is-eq configured (contract-of token))
        (ok true)
        (err ERR_TOKEN_MISMATCH)
      )
    (err ERR_TOKEN_NOT_CONFIGURED)
  )
)

(define-private (check-compliance
    (adapter <regulatory-adapter-trait>)
    (user principal)
  )
  ;; Convert both adapter failures and an explicit false into a stable local
  ;; error. External compliance responses are handled without panic paths.
  (match (contract-call? adapter check-clean-hands-compliance user)
    compliant
      (if compliant
        (ok true)
        (err ERR_NON_COMPLIANT)
      )
    adapter-error (err ERR_COMPLIANCE_CALL)
  )
)

(define-private (transfer-token
    (token <sip-010-ft-trait>)
    (amount uint)
    (sender principal)
    (recipient principal)
  )
  (match (contract-call? token transfer amount sender recipient none)
    transferred
      (if transferred
        (ok true)
        (err ERR_TOKEN_CALL)
      )
    token-error (err ERR_TOKEN_CALL)
  )
)

(define-private (get-live-balance (token <sip-010-ft-trait>))
  (match (contract-call? token get-balance (var-get vault-principal))
    balance (ok balance)
    token-error (err ERR_TOKEN_CALL)
  )
)

(define-private (calculate-deposit-shares
    (amount uint)
    (assets uint)
    (shares uint)
  )
  (if (is-eq shares u0)
    ;; The first depositor establishes a 1:1 asset/share base.
    (ok amount)
    (begin
      (asserts! (> assets u0) (err ERR_ARITHMETIC))
      (let (
        ;; Floor rounding protects existing share holders from dilution.
        (numerator (try! (safe-multiply amount shares)))
        (new-shares (/ numerator assets))
      )
        (if (> new-shares u0)
          (ok new-shares)
          (err ERR_ZERO_SHARES)
        )
      )
    )
  )
)

(define-private (calculate-withdraw-shares
    (amount uint)
    (assets uint)
    (shares uint)
  )
  (begin
    (asserts! (> assets u0) (err ERR_INSUFFICIENT_ASSETS))
    (let ((numerator (try! (safe-multiply amount shares))))
      ;; Ceiling rounding burns enough shares to cover the requested assets.
      (ceil-div numerator assets)
    )
  )
)

;; --- Admin/configuration --------------------------------------------------

;; @desc Return the current vault administrator.
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; @desc Return the configured canonical sBTC contract principal, if set.
(define-read-only (get-approved-token)
  (var-get approved-token)
)

;; @desc Configure the canonical SIP-010 token. Reconfiguration is allowed
;; only while the vault has no accounted assets or outstanding shares.
(define-public (set-approved-token (token <sip-010-ft-trait>))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts!
      (and
        (is-eq (var-get total-assets) u0)
        (is-eq (var-get total-shares) u0)
      )
      (err ERR_ACTIVE_VAULT)
    )
    (var-set approved-token (some (contract-of token)))
    (print {
      event: "sbtc-vault-token-configured",
      token: (contract-of token),
      admin: contract-caller,
      block: burn-block-height
    })
    (ok true)
  )
)

;; @desc Update the maximum accounted sBTC assets accepted by deposits.
(define-public (set-deposit-cap (new-cap uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> new-cap u0) (err ERR_INVALID_CAP))
    (asserts! (>= new-cap (var-get total-assets)) (err ERR_CAP_BELOW_ASSETS))
    (var-set deposit-cap new-cap)
    (print {
      event: "sbtc-vault-cap-updated",
      cap: new-cap,
      admin: contract-caller,
      block: burn-block-height
    })
    (ok true)
  )
)

;; @desc Pause deposits and allocation without blocking safe withdrawals.
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set paused new-paused)
    (print {
      event: "sbtc-vault-pause-updated",
      paused: new-paused,
      admin: contract-caller,
      block: burn-block-height
    })
    (ok true)
  )
)

;; @desc Transfer admin authority to a new principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (print {
      event: "sbtc-vault-admin-updated",
      admin: new-admin,
      block: burn-block-height
    })
    (ok true)
  )
)

;; --- Custody and share accounting ---------------------------------------

;; @desc Deposit approved canonical sBTC and mint pro-rata vault shares.
;;
;; Trait order is (amount, token). The token argument is checked against the
;; admin-configured principal before any transfer or accounting mutation.
(define-public (deposit (amount uint) (token <sip-010-ft-trait>))
  (begin
    (try! (assert-approved-token token))
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
    (asserts! (> (var-get deposit-cap) u0) (err ERR_CAP_NOT_SET))
    (try! (check-compliance .regulatory-adapter tx-sender))
    (let (
      (current-assets (var-get total-assets))
      (current-shares (var-get total-shares))
      (new-assets (try! (safe-add current-assets amount)))
      (new-shares-minted (try! (calculate-deposit-shares amount current-assets current-shares)))
      (current-user-shares (default-to u0 (map-get? user-shares tx-sender)))
      (new-user-shares (try! (safe-add current-user-shares new-shares-minted)))
      (new-total-shares (try! (safe-add current-shares new-shares-minted)))
    )
      (asserts! (<= new-assets (var-get deposit-cap)) (err ERR_CAP_EXCEEDED))
      (try! (transfer-token token amount tx-sender (var-get vault-principal)))
      (map-set user-shares tx-sender new-user-shares)
      (var-set total-assets new-assets)
      (var-set total-shares new-total-shares)
      (print {
        event: "sbtc-vault-deposit",
        user: tx-sender,
        token: (contract-of token),
        assets: amount,
        shares: new-shares-minted,
        total-assets: new-assets,
        total-shares: new-total-shares,
        block: burn-block-height
      })
      (ok true)
    )
  )
)

;; @desc Withdraw an amount of underlying sBTC and burn the required shares.
;;
;; The amount is denominated in underlying sBTC units, not shares. Required
;; shares use ceiling rounding so a withdrawal never under-burns a user's
;; liability. Paused state is intentionally not checked here.
(define-public (withdraw (amount uint) (token <sip-010-ft-trait>))
  (begin
    (try! (assert-approved-token token))
    (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
    (try! (check-compliance .regulatory-adapter tx-sender))
    (let (
      (current-assets (var-get total-assets))
      (current-shares (var-get total-shares))
      (current-user-shares (default-to u0 (map-get? user-shares tx-sender)))
    )
      (asserts! (>= current-assets amount) (err ERR_INSUFFICIENT_ASSETS))
      (asserts! (> current-shares u0) (err ERR_INSUFFICIENT_SHARES))
      (let (
        (shares-to-burn (try! (calculate-withdraw-shares amount current-assets current-shares)))
        (live-assets (try! (get-live-balance token)))
      )
        (asserts! (>= current-user-shares shares-to-burn) (err ERR_INSUFFICIENT_SHARES))
        (asserts! (>= live-assets amount) (err ERR_INSUFFICIENT_ASSETS))
        (let (
          (new-total-assets (- current-assets amount))
          (new-total-shares (- current-shares shares-to-burn))
          (new-user-shares (- current-user-shares shares-to-burn))
          (recipient tx-sender)
        )
          (try! (as-contract
            (transfer-token token amount (var-get vault-principal) recipient)
          ))
          (map-set user-shares recipient new-user-shares)
          (var-set total-assets new-total-assets)
          (var-set total-shares new-total-shares)
          (print {
            event: "sbtc-vault-withdraw",
            user: recipient,
            token: (contract-of token),
            assets: amount,
            shares-burned: shares-to-burn,
            total-assets: new-total-assets,
            total-shares: new-total-shares,
            block: burn-block-height
          })
          (ok true)
        )
      )
    )
  )
)

;; @desc Strategy allocation is deliberately disabled until a separate,
;; approved strategy phase defines the custody and loss-accounting boundary.
(define-public (allocate-to-strategy (strategy principal) (amount uint))
  (err ERR_STRATEGY_DISABLED)
)

;; --- Reconciliation getters ---------------------------------------------

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-deposit-cap)
  (var-get deposit-cap)
)

(define-read-only (get-total-assets)
  (var-get total-assets)
)

(define-read-only (get-total-shares)
  (var-get total-shares)
)

(define-read-only (get-user-shares (user principal))
  (default-to u0 (map-get? user-shares user))
)

(define-read-only (get-user-asset-value (user principal))
  (let (
    (shares (default-to u0 (map-get? user-shares user)))
    (assets (var-get total-assets))
    (total (var-get total-shares))
  )
    (if (or (is-eq shares u0) (is-eq total u0))
      (ok u0)
      (let ((numerator (try! (safe-multiply shares assets))))
        (ok (/ numerator total))
      )
    )
  )
)

(define-read-only (get-accounting (user principal))
  (ok {
    vault: (var-get vault-principal),
    admin: (var-get admin),
    approved-token: (var-get approved-token),
    paused: (var-get paused),
    deposit-cap: (var-get deposit-cap),
    total-assets: (var-get total-assets),
    total-shares: (var-get total-shares),
    user-shares: (default-to u0 (map-get? user-shares user))
  })
)
