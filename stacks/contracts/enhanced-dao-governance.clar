;; Enhanced DAO Governance with Time-Weighted Voting (AIP-2)
;; This contract extends the base DAO governance with time-weighted voting power

;; Import SIP-010 fungible token trait
(use-trait ft-trait .sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u404))
(define-constant ERR-VOTING-PERIOD-ENDED (err u405))
(define-constant ERR-ALREADY-VOTED (err u406))
(define-constant ERR-INSUFFICIENT-QUORUM (err u407))
(define-constant ERR-PROPOSAL-DEFEATED (err u408))
(define-constant ERR-INSUFFICIENT-HOLDING-PERIOD (err u409))

;; Time-weighted voting constants
(define-constant MINIMUM-HOLDING-PERIOD u48) ;; 48 blocks (~8 hours)
(define-constant TIME-WEIGHT-MULTIPLIER u100) ;; Base 100% weight

;; Data structures for time-weighted voting
(define-map holding-periods principal uint)
(define-map voting-snapshots uint {
    voter: principal,
    balance: uint,
    holding-period: uint,
    timestamp: uint
})

;; Enhanced voting power calculation
(define-private (calculate-time-weighted-power (voter principal) (balance uint))
    (let (
        (holding-period (default-to u0 (map-get? holding-periods voter)))
        (time-multiplier (if (>= holding-period MINIMUM-HOLDING-PERIOD)
            (+ TIME-WEIGHT-MULTIPLIER (/ holding-period u10))
            TIME-WEIGHT-MULTIPLIER))
    )
    (/ (* balance time-multiplier) TIME-WEIGHT-MULTIPLIER)
    )
)

;; Create voting snapshot with time-weighting
(define-public (create-voting-snapshot (proposal-id uint))
    (let (
        (voter tx-sender)
        (balance (unwrap! (contract-call? .gov-token get-balance voter) ERR-INSUFFICIENT-BALANCE))
        (holding-period (default-to u0 (map-get? holding-periods voter)))
    )
    (asserts! (>= holding-period MINIMUM-HOLDING-PERIOD) ERR-INSUFFICIENT-HOLDING-PERIOD)
    
    (map-set voting-snapshots proposal-id {
        voter: voter,
        balance: balance,
        holding-period: holding-period,
        timestamp: block-height
    })
    
    (ok true)
    )
)

;; Update holding period tracking
(define-public (update-holding-period (voter principal))
    (let (
        (current-period (default-to u0 (map-get? holding-periods voter)))
    )
    (map-set holding-periods voter (+ current-period u1))
    (ok true)
    )
)

;; Get time-weighted voting power
(define-read-only (get-time-weighted-power (voter principal))
    (let (
        (balance (unwrap! (contract-call? .gov-token get-balance voter) u0))
    )
    (calculate-time-weighted-power voter balance)
    )
)
