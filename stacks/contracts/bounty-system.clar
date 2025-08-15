;; On-Chain Bounty System - DAO Self-Managed Development Incentives
;; Fully autonomous bounty creation, management, and reward distribution

(use-trait sip010 .sip-010-trait.sip-010-trait)

;; Constants
(define-constant BOUNTY_CATEGORIES_DEV u0)
(define-constant BOUNTY_CATEGORIES_SECURITY u1)
(define-constant BOUNTY_CATEGORIES_DOCS u2)
(define-constant BOUNTY_CATEGORIES_ANALYTICS u3)
(define-constant BOUNTY_CATEGORIES_DESIGN u4)

(define-constant BOUNTY_STATUS_OPEN u0)
(define-constant BOUNTY_STATUS_ASSIGNED u1)
(define-constant BOUNTY_STATUS_IN_PROGRESS u2)
(define-constant BOUNTY_STATUS_SUBMITTED u3)
(define-constant BOUNTY_STATUS_COMPLETED u4)
(define-constant BOUNTY_STATUS_CANCELLED u5)

(define-constant MILESTONE_STATUS_PENDING u0)
(define-constant MILESTONE_STATUS_SUBMITTED u1)
(define-constant MILESTONE_STATUS_APPROVED u2)
(define-constant MILESTONE_STATUS_REJECTED u3)

;; Data Variables
(define-data-var bounty-count uint u0)
(define-data-var milestone-count uint u0)
(define-data-var creator-token principal .creator-token)
(define-data-var treasury principal .treasury)
(define-data-var dao-governance principal .dao-governance)

;; Bounty structure
(define-map bounties
  { id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 500),
    category: uint,
    reward-amount: uint,
    creator-token-reward: uint,
    creator: principal,
    assignee: (optional principal),
    status: uint,
    created-block: uint,
    deadline-block: uint,
    completion-block: uint,
  milestone-count: uint,
  approved-milestones: uint
  }
)

;; Milestone tracking
(define-map milestones
  { bounty-id: uint, milestone-id: uint }
  {
    description: (string-utf8 200),
    reward-percentage: uint, ;; Percentage of total bounty reward
    status: uint,
    submission-data: (optional (string-utf8 500)),
    submitted-block: uint,
    reviewer: (optional principal),
    review-block: uint
  }
)

;; Contributor tracking
(define-map contributors
  { contributor: principal }
  {
    total-bounties-completed: uint,
    total-rewards-earned: uint,
    creator-tokens-earned: uint,
    reputation-score: uint,
    first-contribution-block: uint,
    last-activity-block: uint
  }
)

;; Bounty applications
(define-map applications
  { bounty-id: uint, applicant: principal }
  {
    proposal: (string-utf8 300),
    estimated-blocks: uint,
    applied-block: uint,
    status: uint ;; 0=pending, 1=accepted, 2=rejected
  }
)

;; Events
(define-private (emit-bounty-created (id uint) (creator principal) (reward uint))
  (print {
    event: "bounty-created",
    bounty-id: id,
    creator: creator,
    reward: reward,
    block: block-height
  })
)

(define-private (emit-bounty-assigned (id uint) (assignee principal))
  (print {
    event: "bounty-assigned",
    bounty-id: id,
    assignee: assignee,
    block: block-height
  })
)

(define-private (emit-milestone-completed (bounty-id uint) (milestone-id uint) (contributor principal))
  (print {
    event: "milestone-completed",
    bounty-id: bounty-id,
    milestone-id: milestone-id,
    contributor: contributor,
    block: block-height
  })
)

(define-private (emit-bounty-completed (id uint) (contributor principal) (reward uint))
  (print {
    event: "bounty-completed",
    bounty-id: id,
    contributor: contributor,
    reward: reward,
    creator-tokens: (calculate-creator-token-reward reward),
    block: block-height
  })
)

;; Read-only functions
(define-read-only (get-bounty (id uint))
  (map-get? bounties { id: id })
)

(define-read-only (get-milestone (bounty-id uint) (milestone-id uint))
  (map-get? milestones { bounty-id: bounty-id, milestone-id: milestone-id })
)

(define-read-only (get-contributor (contributor principal))
  (map-get? contributors { contributor: contributor })
)

(define-read-only (get-application (bounty-id uint) (applicant principal))
  (map-get? applications { bounty-id: bounty-id, applicant: applicant })
)

(define-read-only (calculate-creator-token-reward (bounty-reward uint))
  ;; Creator tokens = 10% of bounty reward value
  (/ bounty-reward u10)
)

(define-read-only (calculate-reputation-increase (bounty-reward uint))
  ;; Reputation increase based on bounty size
  (if (> bounty-reward u1000000) ;; 1M+ reward
    u100
    (if (> bounty-reward u100000) ;; 100K+ reward
      u50
      u25
    )
  )
)

;; Public functions
(define-public (create-bounty 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (category uint)
  (reward-amount uint)
  (deadline-blocks uint)
)
  (let (
    (bounty-id (+ (var-get bounty-count) u1))
    (creator-reward (calculate-creator-token-reward reward-amount))
  )
    ;; Validate category
    (asserts! (<= category BOUNTY_CATEGORIES_DESIGN) (err u101))
    
    ;; Validate reward amount
    (asserts! (> reward-amount u0) (err u102))
    
    ;; Create bounty
    (map-set bounties { id: bounty-id } {
      title: title,
      description: description,
      category: category,
      reward-amount: reward-amount,
      creator-token-reward: creator-reward,
      creator: tx-sender,
      assignee: none,
      status: BOUNTY_STATUS_OPEN,
      created-block: block-height,
      deadline-block: (+ block-height deadline-blocks),
      completion-block: u0,
  milestone-count: u0,
  approved-milestones: u0
    })
    
    (var-set bounty-count bounty-id)
    (emit-bounty-created bounty-id tx-sender reward-amount)
    (ok bounty-id)
  )
)

(define-public (add-milestone 
  (bounty-id uint)
  (description (string-utf8 200))
  (reward-percentage uint)
)
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
    (milestone-id (+ (get milestone-count bounty) u1))
  )
    ;; Only bounty creator can add milestones
    (asserts! (is-eq tx-sender (get creator bounty)) (err u100))
    
    ;; Bounty must be open
    (asserts! (is-eq (get status bounty) BOUNTY_STATUS_OPEN) (err u104))
    
    ;; Validate percentage
    (asserts! (and (> reward-percentage u0) (<= reward-percentage u100)) (err u105))
    
    ;; Add milestone
    (map-set milestones 
      { bounty-id: bounty-id, milestone-id: milestone-id }
      {
        description: description,
        reward-percentage: reward-percentage,
        status: MILESTONE_STATUS_PENDING,
        submission-data: none,
        submitted-block: u0,
        reviewer: none,
        review-block: u0
      }
    )
    
    ;; Update bounty milestone count
    (map-set bounties { id: bounty-id }
      (merge bounty { milestone-count: milestone-id })
    )
    
    (print {
      event: "milestone-added",
      bounty-id: bounty-id,
      milestone-id: milestone-id,
      reward-percentage: reward-percentage
    })
    (ok milestone-id)
  )
)

(define-public (apply-for-bounty 
  (bounty-id uint)
  (proposal (string-utf8 300))
  (estimated-blocks uint)
)
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
  )
    ;; Bounty must be open
    (asserts! (is-eq (get status bounty) BOUNTY_STATUS_OPEN) (err u104))
    
    ;; Cannot apply for own bounty
    (asserts! (not (is-eq tx-sender (get creator bounty))) (err u106))
    
    ;; Check if already applied
    (asserts! (is-none (get-application bounty-id tx-sender)) (err u107))
    
    ;; Create application
    (map-set applications 
      { bounty-id: bounty-id, applicant: tx-sender }
      {
        proposal: proposal,
        estimated-blocks: estimated-blocks,
        applied-block: block-height,
        status: u0
      }
    )
    
    (print {
      event: "bounty-application",
      bounty-id: bounty-id,
      applicant: tx-sender,
      estimated-blocks: estimated-blocks
    })
    (ok true)
  )
)

(define-public (assign-bounty (bounty-id uint) (assignee principal))
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
    (application (unwrap! (get-application bounty-id assignee) (err u108)))
  )
    ;; Only bounty creator can assign
    (asserts! (is-eq tx-sender (get creator bounty)) (err u100))
    
    ;; Bounty must be open
    (asserts! (is-eq (get status bounty) BOUNTY_STATUS_OPEN) (err u104))
    
    ;; Update bounty status
    (map-set bounties { id: bounty-id }
      (merge bounty { 
        assignee: (some assignee),
        status: BOUNTY_STATUS_ASSIGNED
      })
    )
    
    ;; Update application status
    (map-set applications 
      { bounty-id: bounty-id, applicant: assignee }
      (merge application { status: u1 })
    )
    
    (emit-bounty-assigned bounty-id assignee)
    (ok true)
  )
)

(define-public (submit-milestone 
  (bounty-id uint)
  (milestone-id uint)
  (submission-data (string-utf8 500))
)
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
    (milestone (unwrap! (get-milestone bounty-id milestone-id) (err u109)))
  )
    ;; Only assignee can submit
    (asserts! (is-eq (some tx-sender) (get assignee bounty)) (err u110))
    
    ;; Milestone must be pending
    (asserts! (is-eq (get status milestone) MILESTONE_STATUS_PENDING) (err u111))
    
    ;; Update milestone
    (map-set milestones 
      { bounty-id: bounty-id, milestone-id: milestone-id }
      (merge milestone {
        status: MILESTONE_STATUS_SUBMITTED,
        submission-data: (some submission-data),
        submitted-block: block-height
      })
    )
    
    (print {
      event: "milestone-submitted",
      bounty-id: bounty-id,
      milestone-id: milestone-id,
      contributor: tx-sender
    })
    (ok true)
  )
)

(define-public (review-milestone 
  (bounty-id uint)
  (milestone-id uint)
  (approved bool)
)
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
    (milestone (unwrap! (get-milestone bounty-id milestone-id) (err u109)))
  )
    ;; Only bounty creator can review
    (asserts! (is-eq tx-sender (get creator bounty)) (err u100))
    
    ;; Milestone must be submitted
    (asserts! (is-eq (get status milestone) MILESTONE_STATUS_SUBMITTED) (err u112))
    
    (let ((new-status (if approved MILESTONE_STATUS_APPROVED MILESTONE_STATUS_REJECTED)))
      ;; Update milestone
      (map-set milestones 
        { bounty-id: bounty-id, milestone-id: milestone-id }
        (merge milestone {
          status: new-status,
          reviewer: (some tx-sender),
          review-block: block-height
        })
      )
      
      ;; If approved, pay milestone reward
      (if approved
        (let (
          (milestone-reward (/ (* (get reward-amount bounty) (get reward-percentage milestone)) u100))
          (assignee (unwrap-panic (get assignee bounty)))
        )
          ;; Transfer milestone payment - will be enabled after treasury deployment
          ;; (unwrap! (as-contract (contract-call? .treasury pay-milestone 
          ;;   assignee milestone-reward)) (err u200))

          ;; Increment approved milestones counter on bounty
          (map-set bounties { id: bounty-id }
            (merge bounty { approved-milestones: (+ (get approved-milestones bounty) u1) }))
          
          (emit-milestone-completed bounty-id milestone-id assignee)
          (ok true)
        )
        (ok true)
      )
    )
  )
)

(define-public (complete-bounty (bounty-id uint))
  (let ((bounty (unwrap! (get-bounty bounty-id) (err u103)))
        (assignee (unwrap! (get assignee bounty) (err u113))))
    (asserts! (is-eq tx-sender (get creator bounty)) (err u100))
    (asserts! (is-eq (get status bounty) BOUNTY_STATUS_ASSIGNED) (err u114))
  ;; All milestones approved iff approved-milestones == milestone-count
  (asserts! (is-eq (get approved-milestones bounty) (get milestone-count bounty)) (err u115))
    (let ((reward (get reward-amount bounty))
          (creator-tokens (get creator-token-reward bounty)))
      (map-set bounties { id: bounty-id }
        (merge bounty { status: BOUNTY_STATUS_COMPLETED, completion-block: block-height }))
      (update-contributor-stats assignee reward creator-tokens)
      (unwrap! (as-contract (contract-call? .creator-token mint assignee creator-tokens)) (err u201))
      (emit-bounty-completed bounty-id assignee reward)
      (ok true))))

(define-private (update-contributor-stats (contributor principal) (reward uint) (creator-tokens uint))
  (let (
    (existing-stats (get-contributor contributor))
    (reputation-increase (calculate-reputation-increase reward))
  )
    (match existing-stats
      stats (map-set contributors { contributor: contributor }
        {
          total-bounties-completed: (+ (get total-bounties-completed stats) u1),
          total-rewards-earned: (+ (get total-rewards-earned stats) reward),
          creator-tokens-earned: (+ (get creator-tokens-earned stats) creator-tokens),
          reputation-score: (+ (get reputation-score stats) reputation-increase),
          first-contribution-block: (get first-contribution-block stats),
          last-activity-block: block-height
        }
      )
      ;; First contribution
      (map-set contributors { contributor: contributor }
        {
          total-bounties-completed: u1,
          total-rewards-earned: reward,
          creator-tokens-earned: creator-tokens,
          reputation-score: reputation-increase,
          first-contribution-block: block-height,
          last-activity-block: block-height
        }
      )
    )
  )
)

;; Admin functions (DAO controlled)
(define-public (set-creator-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (var-set creator-token token)
    (ok true)
  )
)

(define-public (cancel-bounty (bounty-id uint))
  (let (
    (bounty (unwrap! (get-bounty bounty-id) (err u103)))
  )
    ;; Only creator or DAO can cancel
    (asserts! (or 
      (is-eq tx-sender (get creator bounty))
      (is-eq tx-sender (var-get dao-governance))
    ) (err u100))
    
    ;; Cannot cancel completed bounties
    (asserts! (not (is-eq (get status bounty) BOUNTY_STATUS_COMPLETED)) (err u116))
    
    (map-set bounties { id: bounty-id }
      (merge bounty { status: BOUNTY_STATUS_CANCELLED })
    )
    
    (print {
      event: "bounty-cancelled",
      bounty-id: bounty-id,
      cancelled-by: tx-sender
    })
    (ok true)
  )
)

;; Errors
;; u100: unauthorized
;; u101: invalid-category
;; u102: invalid-reward-amount
;; u103: bounty-not-found
;; u104: bounty-not-open
;; u105: invalid-percentage
;; u106: cannot-apply-to-own-bounty
;; u107: already-applied
;; u108: application-not-found
;; u109: milestone-not-found
;; u110: not-assignee
;; u111: milestone-not-pending
;; u112: milestone-not-submitted
;; u113: bounty-not-assigned
;; u114: bounty-wrong-status
;; u115: milestones-not-complete
;; u116: cannot-cancel-completed
;; u200: treasury-error
;; u201: token-mint-error
