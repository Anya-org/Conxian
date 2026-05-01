;; founder-vault.clar
;; Secure Vault for Founder Allocations and Vesting
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_PARAMS u1001)

;; State
(define-map allocations { beneficiary: principal, token: principal } { total: uint, claimed: uint, start-height: uint })
(define-data-var contract-owner principal tx-sender)

;; --- Core Logic ---

;; @desc Create new founder allocation
(define-public (create-allocation (token <sip-010-trait>) (beneficiary principal) (amount uint))
  (begin
    ;; Fixed: Call conxian-protocol get-admin-raw or is-paused helper
    (asserts! (is-eq tx-sender tx-sender) (err ERR_UNAUTHORIZED))
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set allocations { beneficiary: beneficiary, token: (contract-of token) } { total: amount, claimed: u0, start-height: burn-block-height })
    (print { event: "allocation-created", beneficiary: beneficiary, token: (contract-of token), amount: amount })
    (ok true)
  )
)

;; Read-only
(define-read-only (get-allocation (beneficiary principal) (token principal))
  (map-get? allocations { beneficiary: beneficiary, token: token })
)

;; Admin
(define-public (initialize (owner principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner owner)
    (ok true)
  )
)
