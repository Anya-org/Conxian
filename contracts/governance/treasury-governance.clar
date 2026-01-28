;; treasury-governance.clar
;; CXTR Use Case: Treasury & Capital Allocation Governance
;; Specialized controller for Operational Treasury disbursements.

(impl-trait .governance-traits.proposal-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))

;; Data Vars
(define-data-var active-budget uint u0)

;; Core Logic

(define-public (execute (proposer principal))
  (begin
    ;; Called by proposal-executor after a successful CXTR vote
    (asserts! (is-eq tx-sender .proposal-executor) ERR_UNAUTHORIZED)

    ;; Logic to trigger a withdrawal from operational-treasury
    ;; (contract-call? .operational-treasury withdraw-stx u1000000 proposer)

    (print { event: "treasury-allocation-executed", proposer: proposer })
    (ok true)
  )
)

;; Specialized Voting Power check for CXTR
(define-read-only (get-cxtr-voting-power (user principal))
  (contract-call? .cxtr-token get-balance user)
)
