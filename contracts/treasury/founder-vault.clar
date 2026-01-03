;; founder-vault.clar
;; Vesting Vault for Founder Allocations
;; Enforces lockup periods defined in Nakamoto constants

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_LOCKED (err u1001))
(define-constant ERR_NO_ALLOCATION (err u1002))

;; Vesting Schedule (using block height)
(define-constant VESTING_START block-height)
(define-constant VESTING_DURATION (contract-call? .nakamoto-constants get-blocks-per-year)) ;; 1 Year Linear

(define-map allocations 
    { beneficiary: principal, token: principal } 
    { total: uint, claimed: uint }
)

(define-public (create-allocation (token <sip-010-trait>) (beneficiary principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-admin)) ERR_UNAUTHORIZED)
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (map-set allocations { beneficiary: beneficiary, token: (contract-of token) }
            { total: amount, claimed: u0 }
        )
        (ok true)
    )
)

(define-public (claim (token <sip-010-trait>))
    (let (
        (sender tx-sender)
        (allocation (unwrap! (map-get? allocations { beneficiary: sender, token: (contract-of token) }) ERR_NO_ALLOCATION))
        (vested-amount (calculate-vested (get total allocation)))
        (claimable (- vested-amount (get claimed allocation)))
    )
        (asserts! (> claimable u0) ERR_LOCKED)
        (try! (as-contract (contract-call? token transfer claimable sender none)))
        (map-set allocations { beneficiary: sender, token: (contract-of token) }
            { total: (get total allocation), claimed: vested-amount }
        )
        (ok claimable)
    )
)

(define-read-only (calculate-vested (total uint))
    (if (>= block-height (+ VESTING_START VESTING_DURATION))
        total
        (/ (* total (- block-height VESTING_START)) VESTING_DURATION)
    )
)
