;; community-dao.clar
;; Conxian PaaS Standard: Community DAO Governance
;; Compliant DAO structure for sub-DAOs spawned via PaaS Factory.
;; Tier 0: "Hands-Off" Governance with Clean-Hands Enforcement.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1001))
(define-constant ERR_PROPOSAL_ACTIVE (err u1002))
(define-constant ERR_PROPOSAL_EXPIRED (err u1003))
(define-constant ERR_QUORUM_NOT_REACHED (err u1004))
(define-constant ERR_NON_COMPLIANT (err u1005))

;; Data Vars
(define-data-var dao-name (string-ascii 64) "Community DAO")
(define-data-var governance-token principal .community-governance-token) ;; Default, updateable
(define-data-var proposal-count uint u0)
(define-data-var voting-delay uint u144) ;; ~1 day
(define-data-var voting-period uint u51840) ;; ~3 days

(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
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

;; Authorization
(define-private (check-compliance (user principal))
  (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
    (if (is-ok compliance-status)
      true
      false
    )
  )
)

;; Admin (DAO Bootstrap)
(define-public (set-governance-token (new-token principal))
  (begin
    ;; Only allowing this if no proposals exist yet to prevent takeover, 
    ;; OR restrict to specific deployer role. 
    ;; For simplicity/template: allow if proposal-count is 0 (initialization phase)
    (asserts! (is-eq (var-get proposal-count) u0) ERR_UNAUTHORIZED)
    (var-set governance-token new-token)
    (ok true)
  )
)

;; Core Logic

(define-public (create-proposal
    (title (string-ascii 64))
    (description (string-ascii 256))
  )
  (let (
      (proposal-id (+ (var-get proposal-count) u1))
      (start (+ block-height (var-get voting-delay)))
      (end (+ start (var-get voting-period)))
      (token (var-get governance-token))
    )
    ;; Compliance Check
    (asserts! (check-compliance tx-sender) ERR_NON_COMPLIANT)

    ;; Token Balance Check (Prevent spam)
    ;; Dynamic contract call to the configured token
    (let ((balance (unwrap-panic (contract-call? token get-balance tx-sender))))
      (asserts! (> balance u0) ERR_UNAUTHORIZED)
    )

    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      start-block: start,
      end-block: end,
      for-votes: u0,
      against-votes: u0,
      executed: false,
    })

    (var-set proposal-count proposal-id)
    (print {
      event: "create-proposal",
      id: proposal-id,
      proposer: tx-sender,
    })
    (ok proposal-id)
  )
)

(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
      (voter tx-sender)
      (token (var-get governance-token))
      (balance (unwrap-panic (contract-call? token get-balance voter)))
    )
    ;; Compliance Check
    (asserts! (check-compliance voter) ERR_NON_COMPLIANT)

    ;; Validation
    (asserts! (>= block-height (get start-block proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (<= block-height (get end-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts!
      (is-none (map-get? votes {
        proposal-id: proposal-id,
        voter: voter,
      }))
      ERR_UNAUTHORIZED
    )
    (asserts! (> balance u0) ERR_UNAUTHORIZED)

    ;; Record Vote
    (map-set votes {
      proposal-id: proposal-id,
      voter: voter,
    }
      true
    )

    (map-set proposals proposal-id
      (merge proposal {
        for-votes: (if support
          (+ (get for-votes proposal) balance)
          (get for-votes proposal)
        ),
        against-votes: (if (not support)
          (+ (get against-votes proposal) balance)
          (get against-votes proposal)
        ),
      })
    )

    (print {
      event: "vote",
      id: proposal-id,
      voter: voter,
      support: support,
      weight: balance,
    })
    (ok true)
  )
)

;; Execution (Simplified for Tier 0)
(define-public (execute (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (> block-height (get end-block proposal)) ERR_PROPOSAL_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (> (get for-votes proposal) (get against-votes proposal))
      ERR_QUORUM_NOT_REACHED
    )

    ;; Only compliant users can trigger execution
    (asserts! (check-compliance tx-sender) ERR_NON_COMPLIANT)

    (map-set proposals proposal-id (merge proposal { executed: true }))
    (print {
      event: "execute",
      id: proposal-id,
    })
    (ok true)
  )
)
