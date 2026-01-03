;; proposal-registry.clar
;; Registry for Conxian Governance Proposals

(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_NOT_FOUND (err u404))

(define-map proposals
    uint
    {
        proposer: principal,
        proposal-contract: principal,
        start-block: uint,
        end-block: uint,
        for-votes: uint,
        against-votes: uint,
        executed: bool,
        canceled: bool,
    }
)

(define-data-var proposal-count uint u0)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-public (add-proposal
        (proposal-contract principal)
        (start uint)
        (end uint)
    )
    (let ((proposal-id (+ (var-get proposal-count) u1)))
        (begin
            (map-set proposals proposal-id {
                proposer: tx-sender,
                proposal-contract: proposal-contract,
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

(define-public (set-executed (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_NOT_FOUND)))
        (begin
            ;; In a real scenario, this would check if the caller is the proposal-executor
            (map-set proposals proposal-id (merge proposal { executed: true }))
            (ok true)
        )
    )
)