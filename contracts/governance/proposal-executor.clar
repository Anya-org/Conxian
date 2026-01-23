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
(define-data-var proposal-registry-contract principal .proposal-registry)
(define-data-var governance-nft-contract principal .enhanced-governance-nft)
(define-data-var cxvg-token-contract principal .cxvg-token)

(define-private (is-ops-engine)
  (is-eq tx-sender (var-get ops-engine))
)

(define-private (get-total-supply-for-proposal (council-id uint))
  (if (> council-id u0)
    ;; Council-scoped proposal: currently use global CXVG supply
    (unwrap-panic
      (contract-call? .cxvg-token get-total-supply)
    )
    ;; Global proposal: also use global CXVG supply
    (unwrap-panic
      (contract-call? .cxvg-token get-total-supply)
    )
  )
)

(define-private (get-safe-supply (raw-supply uint))
  (if (is-eq raw-supply u0) u1 raw-supply)
)

(define-private (calculate-quorum
    (total-votes uint)
    (safe-supply uint)
  )
  (/ (* total-votes u10000) safe-supply)
)

(define-private (is-authorized-executor (proposer principal))
  (or (is-eq tx-sender proposer) (is-ops-engine))
)

(define-public (set-ops-engine (new-engine principal))
  (begin
    (asserts! (is-ops-engine) ERR_UNAUTHORIZED)
    (var-set ops-engine new-engine)
    (ok true)
  )
)

(define-public (execute
    (proposal-id uint)
    (proposal-contract <proposal-trait>)
    (quorum-percentage uint)
  )
  (let (
      (proposal
        (unwrap! (contract-call? (var-get proposal-registry-contract) get-proposal proposal-id)
          ERR_PROPOSAL_NOT_FOUND
        )
      )
      (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
      (council-id (get council-id proposal))
      (total-supply (get-total-supply-for-proposal council-id))
      (safe-supply (get-safe-supply total-supply))
      (quorum (calculate-quorum total-votes safe-supply))
    )
    (begin
      ;; Authorization: Proposer OR Ops Engine
      (asserts! (is-authorized-executor (get proposer proposal)) ERR_UNAUTHORIZED)

      ;; Time/state checks
      (asserts! (>= block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
      (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
      (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)

      ;; Outcome check
      (asserts! (> (get for-votes proposal) (get against-votes proposal))
        ERR_PROPOSAL_FAILED
      )

      ;; Quorum checks
      (asserts! (> total-supply u0) ERR_QUORUM_NOT_REACHED)
      (asserts! (>= quorum quorum-percentage) ERR_QUORUM_NOT_REACHED)

      ;; Verify that the passed contract matches the one in the proposal
      (asserts!
        (is-eq (contract-of proposal-contract) (get proposal-contract proposal))
        ERR_INVALID_PROPOSAL_CONTRACT
      )

      ;; Execute the proposal logic
      (try! (contract-call? proposal-contract execute tx-sender))

      ;; Mark as executed in registry
      (try! (contract-call? (var-get proposal-registry-contract) set-executed
        proposal-id
      ))
      (try! (contract-call? (var-get proposal-registry-contract) set-executed proposal-id))

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
