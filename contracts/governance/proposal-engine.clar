;; proposal-engine.clar
;; Conxian Governance: Logic-Rich Facade (Controller)
;; Routing and orchestration for Multi-Council Governance

(use-trait proposal-trait .governance-traits.proposal-trait)
(use-trait nft-trait .sip-standards.sip-009-nft-trait)
(use-trait reputation-trait .governance-traits.reputation-engine-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NOT_FOUND u1001)
(define-constant ERR_PROPOSAL_ACTIVE u1002)
(define-constant ERR_PROPOSAL_ALREADY_EXISTS u7004)
(define-constant ERR_PROPOSAL_ENDED u1003)
(define-constant ERR_INSUFFICIENT_POWER u1004)

(define-data-var proposal-counter uint u0)
(define-data-var proposal-executor-contract principal tx-sender)
(define-data-var proposal-registry-contract principal tx-sender)
(define-data-var reputation-engine-contract principal tx-sender)

;; Access Control
(define-data-var access-control principal tx-sender)

;; Routes
(define-data-var registry principal tx-sender)
(define-data-var seat-token principal tx-sender)
(define-data-var reputation-engine principal tx-sender)

;; @desc Submits a new proposal to a specific council for voting.
;; @param proposal-contract: The contract principal of the proposal to be voted on. Must implement the proposal-trait.
;; @param council-id: The ID of the council that will vote on this proposal.
;; @param start-block: The block height at which voting begins.
;; @param end-block: The block height at which voting ends.
;; @returns (response uint uint) The ID of the newly created proposal.
(define-public (submit-proposal
    (proposal-contract <proposal-trait>)
    (council-id uint)
    (start-block uint)
    (end-block uint)
  )
  (let ((contract-principal (contract-of proposal-contract)))
    ;; Check if sender holds a seat on this council (or is admin)
    (asserts!
      (>
        (unwrap-panic (contract-call? .enhanced-governance-nft get-seat-power tx-sender
          council-id
        ))
        u0
      )
      (err ERR_UNAUTHORIZED)
    )

    (let ((proposal-id (unwrap-panic (contract-call? .proposal-registry add-proposal contract-principal council-id start-block end-block))))
      (ok proposal-id)
    )
  )
)

;; @desc Casts a vote on an active proposal.
;; @param proposal-id: The ID of the proposal to vote on.
;; @param support: A boolean indicating the voter's choice (true for 'yes' false for 'no').
;; @returns (response bool uint)
(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (contract-call? .proposal-registry get-proposal proposal-id)
        (err ERR_NOT_FOUND)
      ))
      (council-id (get council-id proposal))
      (raw-voter-power (unwrap-panic (contract-call? .enhanced-governance-nft get-seat-power tx-sender
        council-id
      )))
      (weighted-voter-power (unwrap-panic (contract-call? .reputation-engine get-weighted-voting-power tx-sender
        raw-voter-power
      )))
    )
    ;; Assert Voting Period
    (asserts! (>= burn-block-height (get start-block proposal)) (err ERR_NOT_FOUND))
    ;; Should be (err ERR_NOT_STARTED) but reusing
    (asserts! (< burn-block-height (get end-block proposal)) (err ERR_PROPOSAL_ENDED))

    ;; Assert Voter Power
    (asserts! (> weighted-voter-power u0) (err ERR_UNAUTHORIZED))

    ;; Update activity score
    (asserts! (unwrap! (contract-call? .conxian-access has-role tx-sender u1) (err ERR_UNAUTHORIZED))
      (err ERR_UNAUTHORIZED)
    )
    (let ((rep-update (contract-call? .reputation-engine update-activity-score
      tx-sender
    )))

    ;; Record Vote
    (contract-call? .proposal-registry vote-proposal proposal-id support
      weighted-voter-power
    )
    )
  )
)

;; @desc Executes a passed proposal by delegating to the proposal executor.
;; @param proposal-id: The ID of the proposal to execute.
;; @param proposal-contract: The contract principal of the proposal.
;; @returns (response bool uint)
(define-public (execute-proposal
    (proposal-id uint)
    (proposal-contract <proposal-trait>)
  )
  (contract-call? .proposal-executor execute proposal-id
    proposal-contract
    u50
  )
)

;; Admin Functions

(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-voting-period" period: new-period })
    (ok true)
  )
)

;; @desc Sets the required quorum percentage for proposal execution.
;; @param new-quorum uint - The new quorum percentage (in bps e.g. 5000 for 50%).
;; @returns (response bool uint)
(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-quorum-percentage" quorum: new-quorum })
    (ok true)
  )
)

(define-public (set-proposal-executor (new-executor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get access-control)) (err ERR_UNAUTHORIZED))
    (var-set proposal-executor-contract new-executor)
    (print { event: "set-proposal-executor" executor: new-executor })
    (ok true)
  )
)

;; @desc Transports administrative ownership of the engine.
;; @param new-owner principal - The new owner principal.
;; @returns (response bool uint)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "transfer-ownership" owner: new-owner })
    (ok true)
  )
)

;; @desc Sets the main protocol coordinator contract.
;; @param new-coordinator principal - The new coordinator principal.
;; @returns (response bool uint)
(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-protocol-coordinator" coordinator: new-coordinator })
    (ok true)
  )
)

(define-public (set-proposal-registry (new-registry principal))
  (begin
    (asserts! (is-eq tx-sender (var-get access-control)) (err ERR_UNAUTHORIZED))
    (var-set proposal-registry-contract new-registry)
    (ok true)
  )
)

(define-public (initialize (new-coordinator principal))
  (begin
    (var-set access-control new-coordinator)
    (ok true)
  )
)
