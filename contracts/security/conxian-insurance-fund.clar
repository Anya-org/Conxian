;; conxian-insurance-fund.clar
;; Emergency insolvency protection for the protocol
;; Collects fees and covers bad debt
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INSUFFICIENT_BALANCE u1001)

;; Roles from conxian-access
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_EMERGENCY u3)

;; State
(define-map balances
    principal
    uint
)

;; @desc Deposits tokens into the protocol insurance fund.
;; @param token: The trait of the token to deposit.
;; @param amount: The quantity of tokens to deposit.
(define-public (deposit
        (token <sip-010-trait>)
        (amount uint)
    )
    (begin
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)
            none
        ))
        (map-set balances (contract-of token)
            (+ (default-to u0 (map-get? balances (contract-of token))) amount)
        )
        (ok true)
    )
)

;; @desc Disburses funds from the insurance fund to cover bad debt or protocol losses. Admin/Emergency only.
;; @param token: The trait of the token to disburse.
;; @param recipient: The principal receiving the coverage.
;; @param amount: The quantity of tokens to disburse.
(define-public (cover-loss
        (token <sip-010-trait>)
        (recipient principal)
        (amount uint)
    )
    (begin
        ;; Access Control: Must be Admin or Emergency role
        (asserts!
            (or
                (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_ADMIN))
                (unwrap-panic (contract-call? .conxian-access has-role tx-sender ROLE_EMERGENCY))
            )
            (err ERR_UNAUTHORIZED)
        )
        (let ((current-balance (default-to u0 (map-get? balances (contract-of token)))))
            (asserts! (>= current-balance amount) (err ERR_INSUFFICIENT_BALANCE))
            (map-set balances (contract-of token) (- current-balance amount))
            (as-contract (contract-call? token transfer amount tx-sender recipient none))
        )
    )
)

;; @desc Retrieves the insurance fund balance for a specific token.
;; @param token: The principal of the token to check.
(define-read-only (get-balance (token principal))
    (default-to u0 (map-get? balances token))
)
