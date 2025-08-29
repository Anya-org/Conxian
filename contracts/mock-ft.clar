;; Mock SIP-010 Fungible Token for local testing
(impl-trait .sip-010-trait.sip-010-trait)

(define-data-var admin principal tx-sender)
(define-data-var total-supply uint u0)
(define-map balances { owner: principal } { amount: uint })
(define-map allowances { owner: principal, spender: principal } { amount: uint })

;; metadata
(define-read-only (get-name)
  (ok "Conxian")
)
(define-read-only (get-symbol)
  (ok "AV")
)
(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-balance-of (owner principal))
  (ok (default-to u0 (get amount (map-get? balances { owner: owner }))))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (get amount (map-get? allowances { owner: owner, spender: spender }))))
)

;; admin mint (testing only)
(define-public (mint (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((bal (default-to u0 (get amount (map-get? balances { owner: to })))) )
      (map-set balances { owner: to } { amount: (+ bal amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true)
    )
  )
)

(define-public (approve (spender principal) (amount uint))
  (begin
    (map-set allowances { owner: tx-sender, spender: spender } { amount: amount })
    (ok true)
  )
)

(define-public (transfer (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((from-bal (default-to u0 (get amount (map-get? balances { owner: tx-sender }))))
          (to-bal (default-to u0 (get amount (map-get? balances { owner: recipient })))) )
      (asserts! (>= from-bal amount) (err u2))
      (map-set balances { owner: tx-sender } { amount: (- from-bal amount) })
      (map-set balances { owner: recipient } { amount: (+ to-bal amount) })
      (ok true)
    )
  )
)

(define-public (transfer-from (sender principal) (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (let ((from-bal (default-to u0 (get amount (map-get? balances { owner: sender }))))
          (to-bal (default-to u0 (get amount (map-get? balances { owner: recipient }))))
          (allow (default-to u0 (get amount (map-get? allowances { owner: sender, spender: tx-sender })))) )
      (asserts! (>= from-bal amount) (err u2))
      (asserts! (>= allow amount) (err u3))
      (map-set allowances { owner: sender, spender: tx-sender } { amount: (- allow amount) })
      (map-set balances { owner: sender } { amount: (- from-bal amount) })
      (map-set balances { owner: recipient } { amount: (+ to-bal amount) })
      (ok true)
    )
  )
)

;; Errors
;; u1: invalid-amount
;; u2: insufficient-balance
;; u3: insufficient-allowance
;; u100: unauthorized
