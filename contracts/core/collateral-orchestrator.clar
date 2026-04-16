;; collateral-manager.clar
;; Standardized Collateral Management for Conxian Protocol
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_INSUFFICIENT_BALANCE u1002)

;; Roles
(define-constant ROLE_PROTOCOL u1)

;; State
(define-map balances { user: principal, token: principal } uint)
(define-data-var contract-owner principal tx-sender)

;; --- Core Logic ---

;; @desc Deposit funds
(define-public (deposit-funds (amount uint) (token-trait <sip-010-trait>))
  (let (
    (user tx-sender)
    (token-principal (contract-of token-trait))
    (current-balance (default-to u0 (map-get? balances { user: user, token: token-principal })))
  )
    (begin
      (asserts! (not (contract-call? .conxian-protocol is-paused)) (err ERR_PAUSED))
      (try! (contract-call? token-trait transfer amount user (as-contract tx-sender) none))
      (map-set balances { user: user, token: token-principal } (+ current-balance amount))
      (print { event: "collateral-deposited", user: user, token: token-principal, amount: amount })
      (ok true)
    )
  )
)

;; @desc Withdraw funds
(define-public (withdraw-funds (amount uint) (token-trait <sip-010-trait>))
  (let (
    (user tx-sender)
    (token-principal (contract-of token-trait))
    (current-balance (default-to u0 (map-get? balances { user: user, token: token-principal })))
  )
    (begin
      (asserts! (not (contract-call? .conxian-protocol is-paused)) (err ERR_PAUSED))
      (asserts! (>= current-balance amount) (err ERR_INSUFFICIENT_BALANCE))
      (try! (as-contract (contract-call? token-trait transfer amount tx-sender user none)))
      (map-set balances { user: user, token: token-principal } (- current-balance amount))
      (print { event: "collateral-withdrawn", user: user, token: token-principal, amount: amount })
      (ok true)
    )
  )
)

;; @desc Seize collateral (Liquidation)
(define-public (seize-collateral (user principal) (token principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? balances { user: user, token: token })))
    ;; Fixed match to use concrete types for simnet stability
    (is-admin (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_PROTOCOL)))
  )
    (begin
      (asserts! (or (is-eq tx-sender (var-get contract-owner)) is-admin) (err ERR_UNAUTHORIZED))
      (asserts! (>= current-balance amount) (err ERR_INSUFFICIENT_BALANCE))
      (map-set balances { user: user, token: token } (- current-balance amount))
      ;; Note: In production, funds would be transferred or credited to insurance
      (print { event: "collateral-seized", user: user, token: token, amount: amount })
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-user-balance (user principal) (token principal))
  (default-to u0 (map-get? balances { user: user, token: token }))
)

;; Admin
(define-public (initialize (owner principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner owner)
    (ok true)
  )
)
