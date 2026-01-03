;; collateral-manager.clar
;; Conxian Standard: Collateral Management
;; Replaces old prototype with RBAC and Trait-driven logic

;; Traits
(use-trait compliance-trait .compliance-trait.compliance-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2000))
(define-constant ROLE_PROTOCOL u2)

;; Map: User -> Token -> Amount
(define-map user-collateral
    {
        user: principal,
        token: principal,
    }
    uint
)

;; @desc Deposits collateral (Signature aligned with tests)
(define-public (deposit-funds
        (amount uint)
        (token <sip-010-trait>)
    )
    (let (
            (token-principal (contract-of token))
            (current-balance (default-to u0
                (map-get? user-collateral {
                    user: tx-sender,
                    token: token-principal,
                })
            ))
            (tenure-id (contract-call? .block-utils get-current-tenure-id))
        )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))

        ;; Transfer tokens to this contract
        ;; Transfer tokens to this contract

        (map-set user-collateral {
            user: tx-sender,
            token: token-principal,
        }
            (+ current-balance amount)
        )

        (print {
            event: "deposit",
            user: tx-sender,
            token: token-principal,
            amount: amount,
            tenure-id: tenure-id,
        })

        (ok true)
    )
)

;; @desc Withdraws collateral (Signature aligned with tests)
(define-public (withdraw-funds
        (amount uint)
;; @desc Withdraws collateral
    )
    (let (
            (token-principal (contract-of token))
            (current-balance (default-to u0
                (map-get? user-collateral {
                    user: tx-sender,
                    token: token-principal,
                })
            ))
        )
        (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)

        ;; Transfer tokens back
        (try! (as-contract (contract-call? token transfer amount tx-sender tx-sender none)))

        (map-set user-collateral {
            user: tx-sender,
            token: token-principal,
        }
            (- current-balance amount)
        )

        (print {
            event: "withdraw",
            user: tx-sender,
            token: token-principal,
            amount: amount,
            tenure-id: (contract-call? .block-utils get-current-tenure-id),
        })

        (ok true)
    )
)

;; @desc Admin/Risk Manager seizure of collateral (Liquidation)
(define-public (seize-collateral
        (user principal)
        (token principal)
        (amount uint)
    )
    (begin
        (asserts!
            (or
                (contract-call? .conxian-protocol is-contract-owner)
                (contract-call? .rbac has-role tx-sender ROLE_PROTOCOL)
            )
            ERR_UNAUTHORIZED
        )
        (let ((current-balance (default-to u0
                (map-get? user-collateral {
                    user: user,
                    token: token,
                })
            )))
            (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
            (map-set user-collateral {
                user: user,
                token: token,
            }
                (- current-balance amount)
            )
        )
        (ok true)
    )
)

;; Read Only
(define-read-only (get-collateral-balance
        (user principal)
        (token principal)
    )
    (ok (default-to u0
        (map-get? user-collateral {
            user: user,
            token: token,
        })
    ))
)