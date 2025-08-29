;; reputation-token.clar
;;
;; A non-transferable (soulbound) token to reward high-signal contributors.

(impl-trait .sip-010-trait.sip-010-trait)

;; Constants
(define-constant TOKEN_NAME "Conxian Reputation")
(define-constant TOKEN_SYMBOL "AVR")
(define-constant TOKEN_DECIMALS u0)
(define-constant MAX_SUPPLY u1000000)

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var dao-governance principal .dao-governance)

;; Maps
(define-map balances { owner: principal } { amount: uint })

;; SIP-010 Implementation
(define-read-only (get-name) (ok TOKEN_NAME))
(define-read-only (get-symbol) (ok TOKEN_SYMBOL))
(define-read-only (get-decimals) (ok TOKEN_DECIMALS))
(define-read-only (get-total-supply) (ok (var-get total-supply)))

(define-read-only (get-balance-of (owner principal))
  (ok (default-to u0 (get amount (map-get? balances { owner: owner }))))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok u0) ;; Allowances are not supported for non-transferable tokens
)

(define-public (transfer (recipient principal) (amount uint))
  (err u100) ;; Transfers are not allowed
)

(define-public (transfer-from (sender principal) (recipient principal) (amount uint))
  (err u100) ;; Transfers are not allowed
)

(define-public (approve (spender principal) (amount uint))
  (err u100) ;; Approvals are not allowed
)

;; Minting function (only callable by DAO)
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u101))
    (let ((recipient-balance (unwrap! (get-balance-of recipient) (err u0))))
      (asserts! (<= (+ (var-get total-supply) amount) MAX_SUPPLY) (err u102))
      (map-set balances { owner: recipient } { amount: (+ recipient-balance amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      (print { event: "mint", recipient: recipient, amount: amount })
      (ok true)
    )
  )
)

;; Burn function (callable by anyone to burn their own tokens)
(define-public (burn (amount uint))
  (begin
    (let ((sender-balance (unwrap! (get-balance-of tx-sender) (err u0))))
      (asserts! (>= sender-balance amount) (err u103))
      (map-set balances { owner: tx-sender } { amount: (- sender-balance amount) })
      (var-set total-supply (- (var-get total-supply) amount))
      (print { event: "burn", owner: tx-sender, amount: amount })
      (ok true)
    )
  )
)

;; Errors
;; u100: not-supported
;; u101: unauthorized
;; u102: supply-exceeded
;; u103: insufficient-balance
