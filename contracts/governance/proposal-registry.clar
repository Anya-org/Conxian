;; proposal-registry.clar
;; Registry for Conxian Governance Proposals

(define-constant ERR_UNAUTHORIZED u4000)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_VOTED u4001)

(define-map proposals
  uint
  {
    proposer: principal,
    proposal-contract: principal,
    council-id: uint,
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    executed: bool,
    canceled: bool
  }
)

;; Track if a user has voted on a proposal
(define-map vote-receipts
  {
    proposal-id: uint,
    voter: principal
  }
  bool
)

(define-data-var proposal-count uint u0)

;; Access Control
(define-data-var access-control principal tx-sender)

;; @desc Returns proposal details for a given ID.
;; @param proposal-id: The ID of the proposal.
;; @return (optional {proposer: principal, proposal-contract: principal, council-id: uint, ...})
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; @desc Checks if a voter has already cast a vote on a proposal.
;; @param proposal-id: The ID of the proposal.
;; @param voter: The principal of the voter.
;; @return bool
(define-read-only (has-voted
    (proposal-id uint)
    (voter principal)
  )
  (default-to false
    (map-get? vote-receipts {
      proposal-id: proposal-id,
      voter: voter
    })
  )
)


;; @desc Registers a new proposal in the registry.
;; @param proposal-contract: The contract principal of the proposal logic.
;; @param council-id: The council ID responsible for the proposal.
;; @param start: The starting block height.
;; @param end: The ending block height.
;; @return (response uint uint) - Returns the new proposal ID.
(define-public (add-proposal
    (proposal-contract principal)
    (council-id uint)
    (start uint)
    (end uint)
  )
  (let ((proposal-id (+ (var-get proposal-count) u1)))
    (begin
      (asserts! (or (is-eq contract-caller .proposal-engine)
                    (is-eq tx-sender (var-get access-control)))
                (err ERR_UNAUTHORIZED))
      (map-set proposals proposal-id {
        proposer: tx-sender,
        proposal-contract: proposal-contract,
        council-id: council-id,
        start-block: start,
        end-block: end,
        for-votes: u0,
        against-votes: u0,
        executed: false,
        canceled: false
      })
      (var-set proposal-count proposal-id)
      (ok proposal-id)
    )
  )
)


;; @desc Marks a proposal as executed.
;; @param proposal-id: The ID of the proposal.
;; @return (response bool uint)
(define-public (set-executed (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_NOT_FOUND))))
    (begin
      (asserts! (or (is-eq contract-caller .proposal-executor)
                    (is-eq tx-sender (var-get access-control)))
                (err ERR_UNAUTHORIZED))
      (map-set proposals proposal-id (merge proposal { executed: true }))
      (ok true)
    )
  )
)


;; @desc Records a vote for a proposal.
;; @param proposal-id: The ID of the proposal.
;; @param support: Vote direction (true for yes).
;; @param weight: The voting weight/power.
;; @return (response bool uint)
(define-public (vote-proposal
    (proposal-id uint)
    (support bool)
    (weight uint)
  )
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_NOT_FOUND))))
    (begin
      (asserts! (or (is-eq contract-caller .proposal-engine)
                    (is-eq tx-sender (var-get access-control)))
                (err ERR_UNAUTHORIZED))
      (asserts! (not (has-voted proposal-id tx-sender)) (err ERR_ALREADY_VOTED))

      ;; Record receipt
      (map-set vote-receipts {
        proposal-id: proposal-id,
        voter: tx-sender
      }
        true
      )

      ;; Update count
      (map-set proposals proposal-id
        (merge proposal {
          for-votes: (if support
            (+ (get for-votes proposal) weight)
            (get for-votes proposal)
          ),
          against-votes: (if (not support)
            (+ (get against-votes proposal) weight)
            (get against-votes proposal)
          )
        })
      )
      (ok true)
    )
  )
)
