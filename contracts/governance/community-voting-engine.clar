;; community-voting-engine.clar
;; Conxian Enterprise Standard: Community Voting Engine (Tier 0 Compliance)
;; Manages community proposals and voting via CXVG token.
;; Integrates with Reputation Engine for weight adjustment.
;; Enforces "Clean-Hands" Compliance.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait reputation-trait .governance-traits.reputation-engine-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ALREADY_VOTED u1001)
(define-constant ERR_VOTING_CLOSED u1002)
(define-constant ERR_START_BLOCK_IN_PAST u2000)
(define-constant ERR_NON_COMPLIANT u2001)

;; Data Vars
(define-data-var voting-delay uint u144) ;; ~1 day (144 blocks @ 10m)
(define-data-var voting-period uint u52560) ;; ~1 year (AGM Interval)

;; Data Maps
(define-map proposals
  uint
  {
    start-time: uint,
    end-time: uint,
    yes-votes: uint,
    no-votes: uint,
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

;; Compliance Check
(define-private (check-compliance (user principal))
  (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
    (if (is-ok compliance-status)
      true
      false
    )
  )
)

;; Core Logic

;; @desc Creates a proposal
(define-public (create-proposal
    (start-time uint)
    (end-time uint)
  )
  (let (
      (proposal-id u1) ;; Use Proposal Registry in full implementation
      (current-time burn-block-height)
    )
    ;; Compliance Check
    (asserts! (check-compliance tx-sender) (err ERR_NON_COMPLIANT))

    ;; Ensure start time is in the future
    (asserts! (> start-time current-time) (err ERR_START_BLOCK_IN_PAST))

    (map-set proposals proposal-id {
      start-time: start-time,
      end-time: end-time,
      yes-votes: u0,
      no-votes: u0,
      executed: false,
    })

    (print {
      event: "create-proposal",
      proposal-id: proposal-id,
      start-time: start-time,
      end-time: end-time,
      proposer: tx-sender,
    })

    (ok proposal-id)
  )
)

;; @desc Vote on a proposal
(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
      (voter tx-sender)
      ;; Get Raw Balance
      (raw-balance (unwrap-panic (contract-call? .cxvg-token get-balance voter)))
      ;; Apply Reputation Weighting
      (weighted-balance (unwrap-panic (contract-call? .reputation-engine get-weighted-voting-power voter
        raw-balance
      )))
    )
    ;; Compliance Check
    (asserts! (check-compliance voter) (err ERR_NON_COMPLIANT))

    ;; Validation
    (asserts!
      (and (>= burn-block-height (get start-time proposal)) (<= burn-block-height (get end-time proposal)))
      (err ERR_VOTING_CLOSED)
    )
    (asserts!
      (is-none (map-get? votes {
        proposal-id: proposal-id,
        voter: voter,
      }))
      (err ERR_ALREADY_VOTED)
    )

    (map-set votes {
      proposal-id: proposal-id,
      voter: voter,
    }
      true
    )

    ;; Update Vote Counts
    (map-set proposals proposal-id
      (merge proposal {
        yes-votes: (if support
          (+ (get yes-votes proposal) weighted-balance)
          (get yes-votes proposal)
        ),
        no-votes: (if (not support)
          (+ (get no-votes proposal) weighted-balance)
          (get no-votes proposal)
        ),
      })
    )

    ;; Update Reputation Activity
    (let ((rep-update (contract-call? .reputation-engine update-activity-score voter)))
      (print {
      event: "vote",
      id: proposal-id,
      voter: voter,
      support: support,
      weight: weighted-balance,
      timestamp: burn-block-height
      })
    )
    (ok true)
  )
)
