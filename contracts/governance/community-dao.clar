;; community-dao.clar

(define-constant ERR_NON_COMPLIANT u1005)

;; @desc Creates a new proposal within the community DAO.
;; @param title: Short title for the proposal (string-ascii 64).
;; @param description: Detailed description of the proposal (string-ascii 256).
;; @param token: The governance token associated with this proposal.
;; @return (response uint uint) - Returns the proposal ID on success.
(define-public (create-proposal (title (string-ascii 64)) (description (string-ascii 256)) (token principal))
  (begin
    (asserts! (unwrap-panic (contract-call? .regulatory-adapter check-clean-hands-compliance tx-sender)) (err ERR_NON_COMPLIANT))
    (ok u1)
  )
)
