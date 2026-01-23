;; conxian-insurance-fund.clar
;; Emergency insolvency protection for the protocol
;; Collects fees and covers bad debt
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))

;; Roles from conxian-access
(define-constant ROLE_ADMIN u1)
(define-constant ROLE_EMERGENCY u3)

;; State
(define-map balances
    principal
    uint
)

;; Events
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
            ERR_UNAUTHORIZED
        )
        (let ((current-balance (default-to u0 (map-get? balances (contract-of token)))))
            (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
            (map-set balances (contract-of token) (- current-balance amount))
            (as-contract (contract-call? token transfer amount tx-sender recipient none))
        )
    )
)

(define-read-only (get-balance (token principal))
    (default-to u0 (map-get? balances token))
)