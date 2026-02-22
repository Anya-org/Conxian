;; mock-proposal.clar
;; A simple mock proposal contract for testing governance

(use-trait proposal-trait .governance-traits.proposal-trait)

(impl-trait .governance-traits.proposal-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ALREADY_EXECUTED u1001)

(define-data-var executed bool false)
(define-data-var proposer principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; SIP-010 proposal trait implementation
(define-read-only (get-proposer)
  (ok (var-get proposer))
)

(define-read-only (get-title)
  (ok "Mock Proposal")
)

(define-read-only (get-description)
  (ok "A proposal for testing purposes")
)

(define-read-only (get-is-executable)
  (ok true)
)

(define-public (execute (caller principal))
  (begin
    (asserts! (not (var-get executed)) (err ERR_ALREADY_EXECUTED))
    ;; In a real proposal, this would contain the actual execution logic
    ;; For mock purposes, we just mark it as executed
    (var-set executed true)
    (print { event: "proposal-executed", proposer: (var-get proposer), executor: caller })
    (ok true)
  )
)

(define-read-only (get-executed)
  (ok (var-get executed))
)

;; Reset function for testing (allows re-execution in tests)
(define-public (reset)
  (begin
    (var-set executed false)
    (ok true)
  )
)
