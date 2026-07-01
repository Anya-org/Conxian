;; conxian-vaults.clar
;; Core Vault Implementation
;; Manages asset custody and yield strategies
;; Decentralized: Uses Unified RBAC via .conxian-access

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait vault-trait .vault-traits.vault-trait)
(define-constant ERR_UNAUTHORIZED u1000)

;; Data
(define-map vault-balances
  {
    user: principal,
    token: principal
  }
  uint
)

(define-map total-holdings
  principal
  uint
)

;; Public Functions

;; @desc Deposits tokens into the vault.
;; @param token: The SIP-010 token to deposit.
;; @param amount: The quantity to deposit.
(define-public (deposit
    (token <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
      (sender tx-sender)
      (token-contract (contract-of token))
    )
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role sender u4))
      (err ERR_UNAUTHORIZED)
    )
    (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))
    (map-set vault-balances {
      user: sender,
      token: token-contract
    }
      (+
        (default-to u0
          (map-get? vault-balances {
            user: sender,
            token: token-contract
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

;; @desc Withdraws tokens from the vault.
;; @param token: The SIP-010 token to withdraw.
;; @param amount: The quantity to withdraw.
(define-public (withdraw
    (token <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
      (sender tx-sender)
      (token-contract (contract-of token))
      (user-balance (default-to u0
        (map-get? vault-balances {
          user: sender,
          token: token-contract
        })
      ))
    )
    (asserts! (>= user-balance amount) (err u1001))
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role sender u4))
      (err ERR_UNAUTHORIZED)
    )

    (try! (as-contract (contract-call? token transfer amount tx-sender sender none)))

    (map-set vault-balances {
      user: sender,
      token: token-contract
    }
      (- user-balance amount)
    )
    (map-set total-holdings token-contract
      (- (default-to u0 (map-get? total-holdings token-contract)) amount)
    )
    (ok true)
  )
)

;; @desc Returns the vault balance for a specific user and token.
;; @param user: The principal to query.
;; @param token: The token principal.
(define-read-only (get-balance
    (user principal)
    (token principal)
  )
  (default-to u0
    (map-get? vault-balances {
      user: user,
      token: token
    })
  )
)

;; @desc Returns the total balance of a specific asset held in the vaults.
;; @param token: The token principal.
(define-read-only (get-total-assets (token principal))
  (default-to u0 (map-get? total-holdings token))
)
