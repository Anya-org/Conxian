;; sbtc-vault.clar
;; sBTC Vault for Conxian Protocol
;; Manages sBTC deposits and integrates with the Regulatory Adapter

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait vault-trait .vault-traits.vault-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NON_COMPLIANT u2003)

;; Data Vars
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var sbtc-token principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Maps
(define-map user-balances principal uint)

;; Compliance Helper
(define-private (check-compliance (user principal))
    (let (
        (compliance-status (contract-call? .regulatory-adapter
          check-clean-hands-compliance
          user
        ))
      )
        compliance-status
    )
)

;; Public Functions

(define-public (deposit (token <sip-010-trait>) (amount uint))
    (let ((sender tx-sender))
        (asserts! (check-compliance sender) (err ERR_NON_COMPLIANT))
        (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))
        (let ((current-balance (default-to u0 (map-get? user-balances sender))))
            (map-set user-balances sender (+ current-balance amount))
        )
        (ok true)
    )
)

(define-public (withdraw (token <sip-010-trait>) (amount uint))
    (let ((sender tx-sender))
        (asserts! (check-compliance sender) (err ERR_NON_COMPLIANT))
        (let ((current-balance (default-to u0 (map-get? user-balances sender))))
            (asserts! (>= current-balance amount) (err u1001))
            (map-set user-balances sender (- current-balance amount))
            (try! (as-contract (contract-call? token transfer amount (as-contract tx-sender) sender none)))
        )
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? user-balances user)))
)
