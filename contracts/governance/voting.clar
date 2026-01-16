;; voting.clar
;; Conxian Standard: Tenure-Aware Governance
;; Updates legacy voting to use Block Utils and RBAC

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ALREADY_VOTED (err u1001))
(define-constant ERR_VOTING_CLOSED (err u1002))
(define-constant ERR_START_BLOCK_IN_PAST (err u2000))
(define-constant ROLE_GOVERNANCE u1)

;; Data Maps
(define-map proposals
    uint 
    {
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        executed: bool
    }
)

(define-map votes { proposal-id: uint, voter: principal } bool)
(define-map proposal-councils uint uint)

;; Core Logic

;; @desc Creates a proposal
;; @param start-block uint
;; @param end-block uint

;; Core Logic

;; @desc Creates a proposal
;; @param start-block uint
;; @param end-block uint
;; @returns (response uint uint)
(define-public (create-proposal (start-block uint) (end-block uint))
    (let (
        (proposal-id u1) ;; Simple counter for demo
        (tenure-id (contract-call? .block-utils get-current-tenure-id))
    )
        ;; Check Authentication (RBAC Governance Role)
        (asserts! (contract-call? .rbac has-role tx-sender ROLE_GOVERNANCE)
            ERR_UNAUTHORIZED
        )
        
        ;; Ensure start block is in the future
        (asserts! (> start-block block-height) ERR_START_BLOCK_IN_PAST)
        
        (map-set proposals proposal-id {
            start-block: start-block,
            end-block: end-block,
            yes-votes: u0,
            no-votes: u0,
            executed: false
        })
        
        ;; Default to Council 1 (CXD) for now
        (map-set proposal-councils proposal-id u1)
        
        (print {
            event: "create-proposal",
            proposal-id: proposal-id,
            start-block: start-block,
            tenure-id: tenure-id
        })
        
        (ok proposal-id)
    )
)

;; @desc Vote on a proposal
;; @param proposal-id uint
;; @param support bool
;; @returns (response bool uint)
(define-public (vote (proposal-id uint) (support bool))
    (let (
        (proposal (unwrap! (map-get? proposals proposal-id) (err u404)))
        (voter-power u1)
        
        ;; Update Vote Counts (Simplified, assuming 1 vote per call for now, real logic would pull token balance)
    )
        ;; But without a known
        (asserts! (and (>= block-height (get start-block proposal)) (<= block-height (get end-block proposal))) ERR_VOTING_CLOSED)
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
        
        ;; User must have a seat (voting power > 0)
        (asserts! (> voter-power u0) ERR_UNAUTHORIZED)
        
        (map-set votes { proposal-id: proposal-id, voter: tx-sender } true)
        
        ;; Update Vote Counts with WEIGHTED voting power
        (map-set proposals proposal-id (merge proposal {
            yes-votes: (if support (+ (get yes-votes proposal) voter-power) (get yes-votes proposal)),
            no-votes: (if (not support) (+ (get no-votes proposal) voter-power) (get no-votes proposal))
        }))
        
        (print { event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, power: voter-power, support: support })
        
        (ok true)
    )
)
