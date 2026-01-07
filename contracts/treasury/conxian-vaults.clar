;; conxian-vaults.clar
;; Core Vault Implementation
;; Manages asset custody and yield strategies
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait vault-trait .vault-trait.vault-trait)
(define-constant ERR_UNAUTHORIZED (err u1000))

;; Data
(define-map vault-balances
  {
    user: principal,
    token: principal,
  }
  uint
)

(define-map total-holdings
  principal
  uint
)

;; Public Functions
(define-public (deposit
    (token <sip-010-trait>)
    (amount uint)
  )
  (let (
      (sender tx-sender)
      (token-contract (contract-of token))
    )
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role sender u4))
      ERR_UNAUTHORIZED
    )
    (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))
    (map-set vault-balances {
      user: sender,
      token: token-contract,
    }
      (+
        (default-to u0
          (map-get? vault-balances {
            user: sender,
            token: token-contract,
          })
        )
        amount
      ))
    (map-set total-holdings token-contract
      (+ (default-to u0 (map-get? total-holdings token-contract)) amount)
    )
    (ok true)
  )
)

(define-public (withdraw
    (token <sip-010-trait>)
    (amount uint)
  )
  (let (
      (sender tx-sender)
      (token-contract (contract-of token))
      (user-balance (default-to u0
        (map-get? vault-balances {
          user: sender,
          token: token-contract,
        })
      ))
    )
    (asserts! (>= user-balance amount) (err u1001))
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role sender u4))
      ERR_UNAUTHORIZED
    )

    (try! (as-contract (contract-call? token transfer amount tx-sender sender none)))

    (map-set vault-balances {
      user: sender,
      token: token-contract,
    }
      (- user-balance amount)
    )
    (map-set total-holdings token-contract
      (- (default-to u0 (map-get? total-holdings token-contract)) amount)
    )
    (ok true)
  )
)

(define-read-only (get-balance
    (user principal)
    (token principal)
  )
  (default-to u0
    (map-get? vault-balances {
      user: user,
      token: token,
    })
  )
)

(define-read-only (get-total-assets (token principal))
  (default-to u0 (map-get? total-holdings token))
)
