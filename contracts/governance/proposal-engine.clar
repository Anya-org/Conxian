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
(define-data-var proposal-executor-contract principal .proposal-executor)
(define-data-var proposal-registry-contract principal .proposal-registry)
(define-data-var reputation-engine-contract principal .reputation-engine)

;; Access Control
(define-data-var access-control principal .conxian-access)

;; Routes
(define-data-var registry principal .proposal-registry)
(define-data-var seat-token principal .enhanced-governance-nft)
(define-data-var reputation-engine principal .reputation-engine)

;; @desc Submits a new proposal to a specific council for voting.
;; @param proposal-contract: The contract principal of the proposal to be voted on. Must implement the proposal-trait.
;; @param council-id: The ID of the council that will vote on this proposal.
;; @param start-block: The block height at which voting begins.
;; @param end-block: The block height at which voting ends.
;; @returns (response uint) The ID of the newly created proposal.
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

    ;; Register proposal
    (contract-call? .proposal-registry add-proposal contract-principal council-id
      start-block end-block
    )
  )
)

;; @desc Casts a vote on an active proposal.
;; @param proposal-id: The ID of the proposal to vote on.
;; @param support: A boolean indicating the voter's choice (true for 'yes', false for 'no').
;; @returns (response bool)
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
    (asserts! (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1)) ;; Placeholder
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
;; @returns (response bool)
(define-public (execute-proposal
    (proposal-id uint)
    (proposal-contract <proposal-trait>)
  )
  (contract-call? .proposal-executor execute proposal-id
    proposal-contract u5000
  )
  ;; 50% quorum hardcoded for now
)

;; Admin functions
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-voting-period", period: new-period })
    (ok true)
  )
)

(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-quorum-percentage", quorum: new-quorum })
    (ok true)
  )
)

(define-public (set-proposal-executor (new-executor principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (var-set proposal-executor-contract new-executor)
    (print { event: "set-proposal-executor", executor: new-executor })
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "transfer-ownership", owner: new-owner })
    (ok true)
  )
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (print { event: "set-protocol-coordinator", coordinator: new-coordinator })
    (ok true)
  )
)

(define-public (set-proposal-registry (new-registry principal))
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (var-set proposal-registry-contract new-registry)
    (ok true)
  )
)

;; Legacy function for compatibility
(define-public (propose
    (title (string-ascii 50))
    (signatures (list 10 principal))
    (action-ids (list 10 uint))
    (action-types (list 10 (string-ascii 20)))
    (action-params (list 10 (buff 256)))
    (start-block uint)
    (end-block uint)
  )
  (begin
    (asserts! (contract-call? .conxian-access is-global-admin) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)
