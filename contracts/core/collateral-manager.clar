;; collateral-manager.clar
;; Conxian Standard: Collateral Management
;; Replaces old prototype with RBAC and Trait-driven logic

(use-trait compliance-trait .compliance-trait.compliance-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

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

;; @desc Deposits collateral
;; @param token <sip-010-trait>
;; @param amount uint
;; @returns (response bool uint)
(define-public (deposit
        (token <sip-010-trait>)
        (amount uint)
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
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)
            none
        ))

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

;; @desc Withdraws collateral
;; @param token <sip-010-trait>
;; @param amount uint
;; @returns (response bool uint)
(define-public (withdraw
        (token <sip-010-trait>)
        (amount uint)
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
        ;; Check Pause
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
;; @param user principal
;; @param token principal
;; @param amount uint
;; @returns (response bool uint)
(define-public (seize-collateral
        (user principal)
        (token principal)
        (amount uint)
    )
    (begin
        ;; Needs Risk Manager Role
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