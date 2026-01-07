;; proposal-executor.clar
;;
;; This contract is responsible for the execution of governance proposals.
;; It contains the logic for validating quorums and checking proposal states.
;;

(use-trait proposal-trait .governance-traits.proposal-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u3001))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u3003))
(define-constant ERR_VOTING_CLOSED (err u3004))
(define-constant ERR_QUORUM_NOT_REACHED (err u3006))
(define-constant ERR_PROPOSAL_FAILED (err u3007))
(define-constant ERR_INVALID_PROPOSAL_CONTRACT (err u3008))

(define-data-var ops-engine principal tx-sender)

(define-public (set-ops-engine (new-engine principal))
  (begin
    ;; Simple admin check (in production, use RBAC)
    ;; For now, we assume initial deployer sets this up
    (asserts! (is-eq tx-sender (var-get ops-engine)) ERR_UNAUTHORIZED)
    (var-set ops-engine new-engine)
    (ok true)
  )
)

(define-public (execute
    (proposal-id uint)
    (proposal-contract <proposal-trait>)
    (quorum-percentage uint)
  )
  (let ((proposal (unwrap! (contract-call? .proposal-registry get-proposal proposal-id)
      ERR_PROPOSAL_NOT_FOUND
    )))
    (let (
        (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
        (council-id (get council-id proposal))
        ;; Determine Total Supply based on Context (Council vs Global)
        (total-supply (if (> council-id u0)
          (unwrap-panic (contract-call? .enhanced-governance-nft get-total-council-power
            council-id
          ))
          (unwrap-panic (contract-call? .cxvg-token get-total-supply))
        ))
        ;; Avoid division by zero
        (safe-supply (if (is-eq total-supply u0)
          u1
          total-supply
        ))
        (quorum (/ (* total-votes u10000) safe-supply))
      )
      (begin
        ;; Authorization: Proposer OR Ops Engine
        (asserts!
          (or (is-eq tx-sender (get proposer proposal)) (is-eq tx-sender (var-get ops-engine)))
          ERR_UNAUTHORIZED
        )
        (asserts! (>= block-height (get end-block proposal))
          ERR_PROPOSAL_NOT_ACTIVE
        )
        (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
        (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
        (asserts! (> (get for-votes proposal) (get against-votes proposal))
          ERR_PROPOSAL_FAILED
        )

        ;; Verify Quorum (If supply is 0, we can't pass)
        (asserts! (> total-supply u0) ERR_QUORUM_NOT_REACHED)
        (asserts! (>= quorum quorum-percentage) ERR_QUORUM_NOT_REACHED)

        ;; Verify that the passed contract matches the one in the proposal
        (asserts!
          (is-eq (contract-of proposal-contract) (get proposal-contract proposal))
          ERR_INVALID_PROPOSAL_CONTRACT
        )

        ;; Execute the proposal logic
        (try! (contract-call? proposal-contract execute tx-sender))

        (try! (contract-call? .proposal-registry set-executed proposal-id))
        (print {
          event: "proposal-executed",
          proposal-id: proposal-id,
          votes-for: (get for-votes proposal),
          votes-against: (get against-votes proposal),
          contract: (contract-of proposal-contract),
          council-id: council-id,
        })
        (ok true)
      )
    )
  )
)
