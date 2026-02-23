;; proposal-registry.clar
;; Conxian Protocol Standard Contract

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
    canceled: bool,
  }
)

;; Track if a user has voted on a proposal
(define-map vote-receipts
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

(define-data-var proposal-count uint u0)

;; Access Control
(define-data-var access-control principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (has-voted
    (proposal-id uint)
    (voter principal)
  )
  (default-to false
    (map-get? vote-receipts {
      proposal-id: proposal-id,
      voter: voter,
    })
  )
)


;; @desc Add proposal
;; @returns (response bool uint)
(define-public (add-proposal
    (proposal-contract principal)
    (council-id uint)
    (start uint)
    (end uint)
  )
  (let ((proposal-id (+ (var-get proposal-count) u1)))
    (begin
      ;; In production, this should check if caller is proposal-engine
      (map-set proposals proposal-id {
        proposer: tx-sender,
        proposal-contract: proposal-contract,
        council-id: council-id,
        start-block: start,
        end-block: end,
        for-votes: u0,
        against-votes: u0,
        executed: false,
        canceled: false,
      })
      (var-set proposal-count proposal-id)
      (ok proposal-id)
    )
  )
)


;; @desc Set executed
;; @returns (response bool uint)
(define-public (set-executed (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_NOT_FOUND))))
    (begin
      ;; In a real scenario, this would check if the caller is the proposal-executor
      (map-set proposals proposal-id (merge proposal { executed: true }))
      (ok true)
    )
  )
)


;; @desc Vote proposal
;; @returns (response bool uint)
(define-public (vote-proposal
    (proposal-id uint)
    (support bool)
    (weight uint)
  )
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_NOT_FOUND))))
    (begin
      ;; In production, check if caller is proposal-engine
      (asserts! (not (has-voted proposal-id tx-sender)) (err ERR_ALREADY_VOTED))

      ;; Record receipt
      (map-set vote-receipts {
        proposal-id: proposal-id,
        voter: tx-sender,
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
          ),
        })
      )
      (ok true)
    )
  )
)
