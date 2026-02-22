;; founder-vault.clar
;; Vesting Vault for Founder Allocations
;; Enforces lockup periods defined in Nakamoto constants

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_LOCKED u1001)
(define-constant ERR_NO_ALLOCATION u1002)

;; Vesting Schedule (using block height)
(define-constant VESTING_START burn-block-height)
(define-data-var conxian-protocol-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var nakamoto-constants-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-read-only (get-vesting-duration)
  (contract-call? .nakamoto-constants get-blocks-per-year)
)

(define-map allocations
  {
    beneficiary: principal,
    token: principal,
  }
  {
    total: uint,
    claimed: uint,
  }
)

(define-public (create-allocation
    (token <sip-010-trait>)
    (beneficiary principal)
    (amount uint)
  )
  (begin
    (asserts! (is-eq tx-sender (unwrap-panic (contract-call? .conxian-protocol get-admin)))
      (err ERR_UNAUTHORIZED)
    )
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set allocations {
      beneficiary: beneficiary,
      token: (contract-of token),
    } {
      total: amount,
      claimed: u0,
    })
    (ok true)
  )
)

(define-public (claim (token <sip-010-trait>))
  (let (
      (sender tx-sender)
      (allocation (unwrap!
        (map-get? allocations {
          beneficiary: sender,
          token: (contract-of token),
        })
        (err ERR_NO_ALLOCATION)
      ))
      (vested-amount (calculate-vested (get total allocation)))
      (claimable (- vested-amount (get claimed allocation)))
    )
    (asserts! (> claimable u0) (err ERR_LOCKED))
    (try! (as-contract (contract-call? token transfer claimable tx-sender sender none)))
    (map-set allocations {
      beneficiary: sender,
      token: (contract-of token),
    } {
      total: (get total allocation),
      claimed: vested-amount,
    })
    (ok claimable)
  )
)

(define-read-only (calculate-vested (total uint))
  (let ((vesting-duration (unwrap-panic (get-vesting-duration))))
    (if (>= burn-block-height (+ VESTING_START vesting-duration))
      total
      (/ (* total (- burn-block-height VESTING_START)) vesting-duration)
    ))
)
