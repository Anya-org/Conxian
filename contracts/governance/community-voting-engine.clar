;; community-voting-engine.clar
;; Time-bound Voting for Strategic Proposals

(define-constant ERR_NON_COMPLIANT u2001)

;; @desc Creates a new voting proposal with specific start and end times.
;; @param start-time: Block height when voting starts.
;; @param end-time: Block height when voting ends.
;; @return (response uint uint) - Returns the proposal ID on success.
(define-public (create-proposal (start-time uint) (end-time uint))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok u1)
  )
)
