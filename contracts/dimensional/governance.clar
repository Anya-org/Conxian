;; governance.clar
;; Conxian SAB: Dimensional Governance
;; Governance system for dimensional asset management

(use-trait rbac-trait .core-traits.rbac-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u30010))
(define-constant ERR_NOT_ENOUGH_VOTES (err u30011))
(define-constant VOTING_PERIOD u1000)

;; Data Vars
(define-data-var admin principal tx-sender)

;; Governance storage
(define-map proposals
  uint
  {
    proposer: principal,
    description: (string-ascii 256),
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool,
  }
)

(define-map votes
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

;; Proposal counter
(define-data-var proposal-counter uint u1)

;; Public functions
(define-public (create-proposal (description (string-ascii 32)))
  (begin
    (let ((proposal-id (+ (var-get proposal-counter) u1)))
      (map-set proposals proposal-id {
        proposer: tx-sender,
        description: description,
        votes-for: u0,
        votes-against: u0,
        start-block: block-height,
        end-block: (+ block-height VOTING_PERIOD),
        executed: false,
      })
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (begin
    (match (map-get? proposals proposal-id)
      proposal (begin
        (asserts! (<= block-height (get end-block proposal)) (err u30012))
        (asserts! (not (get executed proposal)) (err u30013))
        (map-set votes {
          proposal-id: proposal-id,
          voter: tx-sender,
        }
          support
        )
        (let ((new-proposal (if support
            (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
            (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
          )))
          (map-set proposals proposal-id new-proposal)
        )
        (ok true)
      )
      (err u0)
    )
  )
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (ok proposal)
    (err u0)
  )
)

(define-read-only (has-voted
    (proposal-id uint)
    (voter principal)
  )
  (match (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  })
    voted (ok voted)
    (ok false)
  )
)