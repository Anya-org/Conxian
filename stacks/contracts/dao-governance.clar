;; Enhanced DAO Governance - Complete Decentralized Management
;; Replaces admin controls with community governance

(use-trait sip010 .sip-010-trait.sip-010-trait)

;; Constants
(define-constant VOTING_PERIOD u1008) ;; ~1 week in blocks
(define-constant EXECUTION_DELAY u144) ;; ~1 day in blocks
(define-constant QUORUM_BPS u2000) ;; 20% of total supply
(define-constant PROPOSAL_THRESHOLD u100000) ;; 100k tokens to propose

;; Data Variables
(define-data-var proposal-count uint u0)
(define-data-var gov-token principal .gov-token)
(define-data-var vault principal .vault)
(define-data-var timelock principal .timelock)
(define-data-var emergency-multisig principal tx-sender)

;; Proposal States
(define-constant PROPOSAL_PENDING u0)
(define-constant PROPOSAL_ACTIVE u1)
(define-constant PROPOSAL_SUCCEEDED u2)
(define-constant PROPOSAL_DEFEATED u3)
(define-constant PROPOSAL_QUEUED u4)
(define-constant PROPOSAL_EXECUTED u5)
(define-constant PROPOSAL_CANCELLED u6)

;; Proposal Types
(define-constant PARAM_CHANGE u0)
(define-constant TREASURY_SPEND u1)
(define-constant EMERGENCY_ACTION u2)
(define-constant BOUNTY_CREATION u3)
(define-constant CONTRACT_UPGRADE u4)

;; Maps
(define-map proposals
  { id: uint }
  {
    proposer: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    proposal-type: uint,
    target-contract: principal,
    function-name: (string-ascii 50),
    parameters: (list 10 uint),
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    abstain-votes: uint,
    state: uint,
    execution-block: uint
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: uint, weight: uint } ;; 0=against, 1=for, 2=abstain
)

(define-map vote-delegations
  { delegator: principal }
  { delegate: principal }
)

;; Events
(define-private (emit-proposal-created (id uint) (proposer principal) (title (string-utf8 100)))
  (print {
    event: "proposal-created",
    proposal-id: id,
    proposer: proposer,
    title: title,
    block: block-height
  })
)

(define-private (emit-vote-cast (id uint) (voter principal) (vote uint) (weight uint))
  (print {
    event: "vote-cast",
    proposal-id: id,
    voter: voter,
    vote: vote,
    weight: weight,
    block: block-height
  })
)

;; Read-only functions
(define-read-only (get-proposal (id uint))
  (map-get? proposals { id: id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-delegation (delegator principal))
  (map-get? vote-delegations { delegator: delegator })
)

(define-read-only (get-voting-power (who principal) (block-height-ref uint))
  ;; Get voting power including delegated votes
  (let ((direct-power (unwrap-panic (contract-call? .gov-token get-balance-of who))))
    ;; TODO: Add delegated voting power calculation
    direct-power
  )
)

(define-read-only (get-proposal-state (id uint))
  (match (get-proposal id)
    proposal (let (
      (current-block block-height)
      (start-block (get start-block proposal))
      (end-block (get end-block proposal))
      (for-votes (get for-votes proposal))
      (against-votes (get against-votes proposal))
      (total-votes (+ for-votes against-votes (get abstain-votes proposal)))
      (total-supply (unwrap-panic (contract-call? .gov-token get-total-supply)))
      (quorum-needed (/ (* total-supply QUORUM_BPS) u10000))
    )
    (if (< current-block start-block)
      PROPOSAL_PENDING
      (if (<= current-block end-block)
        PROPOSAL_ACTIVE
        (if (and (>= total-votes quorum-needed) (> for-votes against-votes))
          PROPOSAL_SUCCEEDED
          PROPOSAL_DEFEATED
        )
      )
    ))
    none
  )
)

;; Governance functions
(define-public (create-proposal 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (proposal-type uint)
  (target-contract principal)
  (function-name (string-ascii 50))
  (parameters (list 10 uint))
)
  (let (
    (proposer-balance (unwrap! (contract-call? .gov-token get-balance-of tx-sender) (err u200)))
    (proposal-id (+ (var-get proposal-count) u1))
  )
    ;; Check proposal threshold
    (asserts! (>= proposer-balance PROPOSAL_THRESHOLD) (err u101))
    
    ;; Create proposal
    (map-set proposals { id: proposal-id } {
      proposer: tx-sender,
      title: title,
      description: description,
      proposal-type: proposal-type,
      target-contract: target-contract,
      function-name: function-name,
      parameters: parameters,
      start-block: (+ block-height u144), ;; Start voting in 1 day
      end-block: (+ block-height (+ u144 VOTING_PERIOD)),
      for-votes: u0,
      against-votes: u0,
      abstain-votes: u0,
      state: PROPOSAL_PENDING,
      execution-block: u0
    })
    
    (var-set proposal-count proposal-id)
    (emit-proposal-created proposal-id tx-sender title)
    (ok proposal-id)
  )
)

(define-public (cast-vote (proposal-id uint) (vote uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) (err u102)))
    (voter-power (get-voting-power tx-sender block-height))
    (current-state (get-proposal-state proposal-id))
  )
    ;; Validate voting period
    (asserts! (is-eq current-state PROPOSAL_ACTIVE) (err u103))
    
    ;; Validate vote value (0=against, 1=for, 2=abstain)
    (asserts! (<= vote u2) (err u104))
    
    ;; Check if already voted
    (asserts! (is-none (get-vote proposal-id tx-sender)) (err u105))
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote, weight: voter-power }
    )
    
    ;; Update proposal vote counts
    (let ((updated-proposal (merge proposal
      (if (is-eq vote u0)
        { against-votes: (+ (get against-votes proposal) voter-power) }
        (if (is-eq vote u1)
          { for-votes: (+ (get for-votes proposal) voter-power) }
          { abstain-votes: (+ (get abstain-votes proposal) voter-power) }
        )
      )
    )))
      (map-set proposals { id: proposal-id } updated-proposal)
    )
    
    (emit-vote-cast proposal-id tx-sender vote voter-power)
    (ok true)
  )
)

(define-public (delegate-vote (delegate principal))
  (begin
    (asserts! (not (is-eq delegate tx-sender)) (err u106))
    (map-set vote-delegations { delegator: tx-sender } { delegate: delegate })
    (print {
      event: "vote-delegated",
      delegator: tx-sender,
      delegate: delegate,
      block: block-height
    })
    (ok true)
  )
)

(define-public (queue-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) (err u102)))
    (state (get-proposal-state proposal-id))
  )
    (asserts! (is-eq state PROPOSAL_SUCCEEDED) (err u107))
    
    ;; Queue in timelock
    (let ((execution-block (+ block-height EXECUTION_DELAY)))
      (map-set proposals { id: proposal-id } 
        (merge proposal { 
          state: PROPOSAL_QUEUED,
          execution-block: execution-block
        })
      )
      
      (print {
        event: "proposal-queued",
        proposal-id: proposal-id,
        execution-block: execution-block
      })
      (ok true)
    )
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) (err u102)))
  )
    (asserts! (is-eq (get state proposal) PROPOSAL_QUEUED) (err u108))
    (asserts! (>= block-height (get execution-block proposal)) (err u109))
    
    ;; Execute based on proposal type
    (match (get proposal-type proposal)
      PARAM_CHANGE (execute-param-change proposal)
      TREASURY_SPEND (execute-treasury-spend proposal)
      BOUNTY_CREATION (execute-bounty-creation proposal)
      (err u110) ;; Unsupported proposal type
    )
    
    ;; Mark as executed
    (map-set proposals { id: proposal-id } 
      (merge proposal { state: PROPOSAL_EXECUTED })
    )
    
    (print {
      event: "proposal-executed",
      proposal-id: proposal-id,
      block: block-height
    })
    (ok true)
  )
)

;; Execution functions
(define-private (execute-param-change (proposal (tuple (proposer principal) (title (string-utf8 100)) (description (string-utf8 500)) (proposal-type uint) (target-contract principal) (function-name (string-ascii 50)) (parameters (list 10 uint)) (start-block uint) (end-block uint) (for-votes uint) (against-votes uint) (abstain-votes uint) (state uint) (execution-block uint))))
  ;; Execute parameter changes on vault contract
  (let ((params (get parameters proposal)))
    (match (get function-name proposal)
      "set-fees" (as-contract (contract-call? .vault set-fees 
        (unwrap-panic (element-at params u0))
        (unwrap-panic (element-at params u1))
      ))
      "set-global-cap" (as-contract (contract-call? .vault set-global-cap
        (unwrap-panic (element-at params u0))
      ))
      (err u111) ;; Unknown function
    )
  )
)

(define-private (execute-treasury-spend (proposal (tuple (proposer principal) (title (string-utf8 100)) (description (string-utf8 500)) (proposal-type uint) (target-contract principal) (function-name (string-ascii 50)) (parameters (list 10 uint)) (start-block uint) (end-block uint) (for-votes uint) (against-votes uint) (abstain-votes uint) (state uint) (execution-block uint))))
  ;; Execute treasury spending
  (let ((params (get parameters proposal)))
    (as-contract (contract-call? .treasury spend
      (get target-contract proposal) ;; recipient
      (unwrap-panic (element-at params u0)) ;; amount
    ))
  )
)

(define-private (execute-bounty-creation (proposal (tuple (proposer principal) (title (string-utf8 100)) (description (string-utf8 500)) (proposal-type uint) (target-contract principal) (function-name (string-ascii 50)) (parameters (list 10 uint)) (start-block uint) (end-block uint) (for-votes uint) (against-votes uint) (abstain-votes uint) (state uint) (execution-block uint))))
  ;; Create bounty
  (let ((params (get parameters proposal)))
    (as-contract (contract-call? .bounty-system create-bounty
      (get title proposal)
      (get description proposal)
      (unwrap-panic (element-at params u0)) ;; reward amount
      (unwrap-panic (element-at params u1)) ;; category
    ))
  )
)

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get emergency-multisig)) (err u100))
    (as-contract (contract-call? .vault set-paused true))
  )
)

;; Admin functions (to be removed after full migration)
(define-public (set-emergency-multisig (new-multisig principal))
  (begin
    (asserts! (is-eq tx-sender (var-get emergency-multisig)) (err u100))
    (var-set emergency-multisig new-multisig)
    (ok true)
  )
)

;; Errors
;; u100: unauthorized
;; u101: insufficient-proposal-threshold
;; u102: proposal-not-found
;; u103: not-in-voting-period
;; u104: invalid-vote-value
;; u105: already-voted
;; u106: cannot-delegate-to-self
;; u107: proposal-not-succeeded
;; u108: proposal-not-queued
;; u109: execution-delay-not-met
;; u110: unsupported-proposal-type
;; u111: unknown-function
;; u200: token-error
