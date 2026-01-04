;; proposal-engine.clar
;; Conxian Governance: Logic-Rich Facade (Controller)
;; Routing and orchestration for Multi-Council Governance

(use-trait proposal-trait .governance-traits.proposal-trait)
(use-trait nft-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_FOUND (err u1001))
(define-constant ERR_PROPOSAL_ACTIVE (err u1002))
(define-constant ERR_PROPOSAL_ENDED (err u1003))
(define-constant ERR_INSUFFICIENT_POWER (err u1004))

;; Access Control
(define-data-var access-control principal .conxian-access)

;; Routes
(define-data-var registry principal .proposal-registry)
(define-data-var seat-token principal .enhanced-governance-nft)

;; @desc Submit a new proposal to a specific council
(define-public (submit-proposal 
        (proposal-contract <proposal-trait>) 
        (council-id uint) 
        (start-block uint) 
        (end-block uint)
    )
    (let (
        (contract-principal (contract-of proposal-contract))
    )
        ;; Check if sender holds a seat on this council (or is admin)
        (asserts!
            (>
                (unwrap-panic (try! (contract-call? .enhanced-governance-nft get-seat-power tx-sender
                    council-id
                )))
                u0
            )
            ERR_UNAUTHORIZED
        )
        
        ;; Register proposal
        (contract-call? .proposal-registry add-proposal contract-principal council-id start-block end-block)
    )
)

;; @desc Vote on a proposal
(define-public (vote (proposal-id uint) (support bool))
    (let (
        (proposal (unwrap! (contract-call? .proposal-registry get-proposal proposal-id) ERR_NOT_FOUND))
        (council-id (get council-id proposal))
        (voter-power (unwrap-panic (try! (contract-call? .enhanced-governance-nft get-seat-power tx-sender
            council-id
        ))))
    )
        ;; Assert Voting Period
        (asserts! (>= block-height (get start-block proposal)) ERR_NOT_FOUND) ;; Should be ERR_NOT_STARTED but reusing
        (asserts! (< block-height (get end-block proposal)) ERR_PROPOSAL_ENDED)
        
        ;; Assert Voter Power
        (asserts! (> voter-power u0) ERR_UNAUTHORIZED)

        ;; Record Vote
(contract-call? .proposal-registry vote-proposal proposal-id support
            voter-power
        )
    )
)

;; @desc Execute a proposal
(define-public (execute-proposal (proposal-id uint) (proposal-contract <proposal-trait>))
    (contract-call? .proposal-executor execute proposal-id proposal-contract u5000) ;; 50% quorum hardcoded for now
)

