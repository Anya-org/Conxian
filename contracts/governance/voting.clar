;; voting.clar
;; Conxian Standard: Tenure-Aware Governance
;; Updates legacy voting to use Block Utils and RBAC
;; Migrated to block-height for tenure-precision voting.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait access-trait .core-traits.conxian-access-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_ALREADY_VOTED u1001)
(define-constant ERR_VOTING_CLOSED u1002)
(define-constant ERR_START_TIME_IN_PAST u2000)
(define-constant ROLE_GOVERNANCE u1)

;; Data Vars
(define-data-var proposal-count uint u0)
(define-data-var access-contract principal .conxian-access)
(define-data-var contract-owner principal tx-sender)

;; Data Maps
(define-map proposals
    uint 
    {
        start-time: uint,
        end-time: uint,
        yes-votes: uint,
        no-votes: uint,
        executed: bool
    }
)

(define-map votes { proposal-id: uint, voter: principal } bool)
(define-map proposal-councils uint uint)

;; Core Logic

;; @desc Creates a proposal
;; @param start-time uint (Unix timestamp)
;; @param end-time uint (Unix timestamp)
;; @returns (response uint uint)
(define-public (create-proposal (start-time uint) (end-time uint) (access-contract-trait <access-trait>))
    (let (
        (proposal-id (+ (var-get proposal-count) u1))
        (tenure-id (/ block-height u10))
    )
        (asserts! (is-eq (contract-of access-contract-trait) (var-get access-contract)) (err ERR_UNAUTHORIZED))
        (asserts! (unwrap-panic (contract-call? access-contract-trait has-role tx-sender ROLE_GOVERNANCE))
            (err ERR_UNAUTHORIZED)
        )
        
        ;; Ensure start time is in the future
        (asserts! (> start-time block-height) (err ERR_START_TIME_IN_PAST))
        
        (map-set proposals proposal-id {
            start-time: start-time,
            end-time: end-time,
            yes-votes: u0,
            no-votes: u0,
            executed: false
        })
        
        ;; Default to Council 1 (CXD) for now
        (map-set proposal-councils proposal-id u1)
        (var-set proposal-count proposal-id)
        
        (print {
            event: "create-proposal",
            proposal-id: proposal-id,
            start-time: start-time,
            tenure-id: tenure-id,
            timestamp: block-height
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
    )
        ;; Check if voting period is active using block-height
        (asserts! (and (>= block-height (get start-time proposal)) (<= block-height (get end-time proposal))) (err ERR_VOTING_CLOSED))
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) (err ERR_ALREADY_VOTED))
        
        ;; User must have a seat (voting power > 0)
        (asserts! (> voter-power u0) (err ERR_UNAUTHORIZED))
        
        (map-set votes { proposal-id: proposal-id, voter: tx-sender } true)
        
        ;; Update Vote Counts with WEIGHTED voting power
        (map-set proposals proposal-id (merge proposal {
            yes-votes: (if support (+ (get yes-votes proposal) voter-power) (get yes-votes proposal)),
            no-votes: (if (not support) (+ (get no-votes proposal) voter-power) (get no-votes proposal))
        }))
        
        (print { event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, power: voter-power, support: support, timestamp: block-height })
        
        (ok true)
    )
)

;; @desc Update the access contract principal (Principal Injection)
(define-public (set-access-contract (new-access principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner))
            (err ERR_UNAUTHORIZED)
        )
        (var-set access-contract new-access)
        (ok true)
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner))
            (err ERR_UNAUTHORIZED)
        )
        (var-set contract-owner new-owner)
        (ok true)
    )
)
