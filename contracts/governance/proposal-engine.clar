;;
;; @title Proposal Engine (Logic-Rich Facade)
;; @author Conxian Protocol
;; @desc This contract is the primary controller for the governance module. It
;; provides a unified interface for creating proposals, casting votes, and
;; executing the outcomes. It enforces the core business logic of the
;; governance process (e.g., timing, state checks) and delegates specialized
;; tasks like data storage (`proposal-registry`) and vote counting (`voting`)
;; to manager contracts.
;;

(use-trait voting-trait .governance-traits.voting-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant PROPOSAL_DELAY u17280)
(define-constant VOTING_PERIOD u120960)
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_INVALID_VOTING_PERIOD (err u109))
(define-constant ERR_PROTOCOL_PAUSED (err u5001))
(define-constant MIN_QUORUM u1000)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-registry principal .proposal-registry)
(define-data-var voting principal .governance-voting)
(define-data-var proposal-executor principal .proposal-executor)
(define-data-var voting-period-blocks uint u172800)
(define-data-var quorum-percentage uint u5000)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (match (contract-call? .conxian-protocol is-protocol-paused)
    response (unwrap-or response true)
    true
  )
)

(define-private (is-contract-owner) (is-eq tx-sender (var-get contract-owner)))

;; --- Public Functions ---
(define-public (propose (description (string-ascii 256)) (targets (list 10 principal)) (values (list 10 uint)) (signatures (list 10 (string-ascii 64))) (calldatas (list 10 (buff 1024))) (start-block uint) (end-block uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((proposal-id (try! (contract-call? .proposal-registry create-proposal tx-sender description start-block end-block))))
      (print { event: "proposal-created", proposal-id: proposal-id, proposer: tx-sender, start-block: start-block, end-block: end-block })
      (ok proposal-id)
    )
  )
)

(define-public (vote (proposal-id uint) (support bool) (voting-contract <voting-trait>))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
      (match maybe-proposal
        proposal (begin
          (asserts! (is-eq (get executed proposal) false) ERR_VOTING_CLOSED)
          (asserts! (is-eq (get canceled proposal) false) ERR_VOTING_CLOSED)
          (asserts! (>= burn-block-height (get start-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
          (asserts! (<= burn-block-height (get end-block proposal)) ERR_VOTING_CLOSED)
          (asserts! (is-eq (contract-of voting-contract) (var-get voting)) ERR_UNAUTHORIZED)
          (try! (contract-call? voting-contract vote proposal-id support tx-sender))
          (print { event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, support: support })
          (ok true)
        )
        ERR_PROPOSAL_NOT_FOUND
      )
    )
  )
)

(define-public (execute (proposal-id uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? .proposal-executor execute proposal-id (var-get quorum-percentage))
  )
)

(define-public (cancel (proposal-id uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
      (match maybe-proposal
        proposal (begin
          (asserts! (or (is-eq tx-sender (get proposer proposal)) (is-contract-owner)) ERR_UNAUTHORIZED)
          (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
          (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
          (try! (contract-call? .proposal-registry set-canceled proposal-id))
          (print { event: "proposal-canceled", proposal-id: proposal-id, canceled-by: tx-sender })
          (ok true)
        )
        ERR_PROPOSAL_NOT_FOUND
      )
    )
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-proposal (proposal-id uint))
  (contract-call? .proposal-registry get-proposal proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal) (voting-contract <voting-trait>))
  (contract-call? voting-contract get-vote proposal-id voter)
)

(define-read-only (get-quorum-percentage)
    (ok (var-get quorum-percentage))
)

;; --- Admin Functions ---
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_VOTING_PERIOD)
    (var-set voting-period-blocks new-period)
    (print { event: "set-voting-period", new-period: new-period, sender: tx-sender })
    (ok true)
  )
)

(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (and (>= new-quorum MIN_QUORUM) (<= new-quorum u10000)) ERR_UNAUTHORIZED)
    (var-set quorum-percentage new-quorum)
    (print { event: "set-quorum-percentage", new-quorum: new-quorum, sender: tx-sender })
    (ok true)
  )
)

(define-public (set-proposal-executor (executor-address principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set proposal-executor executor-address)
    (print { event: "set-proposal-executor", executor-address: executor-address, sender: tx-sender })
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (print { event: "transfer-ownership", new-owner: new-owner, sender: tx-sender })
    (ok true)
  )
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (print { event: "set-protocol-coordinator", new-coordinator: new-coordinator, sender: tx-sender })
    (ok true)
  )
)
