# AIP Implementation: Time-Weighted Voting Power

## Implementation for AIP-2: Implement Time-Weighted Voting Power

### Add to dao-governance.clar

```clarity
;; Time-weighted voting configuration
(define-constant MINIMUM_HOLDING_PERIOD u288) ;; 48 hours in blocks
(define-constant SNAPSHOT_VALIDITY_PERIOD u4320) ;; 30 days in blocks

;; Snapshot data
(define-map voting-snapshots
  { proposal-id: uint, voter: principal }
  { 
    voting-power: uint,
    snapshot-block: uint,
    token-held-since: uint
  }
)

;; Token holding history for time-weighting
(define-map token-holding-history
  { holder: principal, block-height: uint }
  { balance: uint, held-since: uint }
)

;; Create voting snapshot for proposal
(define-public (create-voting-snapshot (proposal-id uint))
  (let (
    (current-balance (get-voting-power tx-sender))
    (held-since (get-token-held-since tx-sender))
    (snapshot-block block-height)
  )
    ;; Verify tokens held for minimum period
    (asserts! (>= (- block-height held-since) MINIMUM_HOLDING_PERIOD) (err u409))
    
    ;; Create snapshot
    (map-set voting-snapshots 
      { proposal-id: proposal-id, voter: tx-sender }
      {
        voting-power: current-balance,
        snapshot-block: snapshot-block,
        token-held-since: held-since
      })
    
    (print { 
      event: "snapshot-created", 
      proposal-id: proposal-id, 
      voter: tx-sender, 
      voting-power: current-balance 
    })
    (ok true)))

;; Update token holding history (called on transfers)
(define-public (update-holding-history (holder principal) (new-balance uint))
  (begin
    (map-set token-holding-history
      { holder: holder, block-height: block-height }
      { balance: new-balance, held-since: block-height })
    (ok true)))

;; Get time-weighted voting power
(define-read-only (get-time-weighted-power (proposal-id uint) (voter principal))
  (match (map-get? voting-snapshots { proposal-id: proposal-id, voter: voter })
    snapshot (let (
      (base-power (get voting-power snapshot))
      (holding-duration (- block-height (get token-held-since snapshot)))
      (weight-multiplier (calculate-time-weight holding-duration))
    )
    (* base-power weight-multiplier))
    u0))

;; Calculate time weight multiplier (longer holding = higher weight)
(define-read-only (calculate-time-weight (holding-duration uint))
  (if (>= holding-duration (* MINIMUM_HOLDING_PERIOD u30)) ;; 30x minimum (60 days)
    u150 ;; 1.5x multiplier for long-term holders
    (if (>= holding-duration (* MINIMUM_HOLDING_PERIOD u7)) ;; 7x minimum (14 days)
      u125 ;; 1.25x multiplier
      u100))) ;; 1.0x base multiplier

;; Get token held since block for user
(define-read-only (get-token-held-since (holder principal))
  (match (map-get? token-holding-history { holder: holder, block-height: block-height })
    history (get held-since history)
    block-height)) ;; Default to current block if no history

;; Enhanced delegation with time requirements
(define-public (delegate-time-weighted (delegate principal))
  (let ((delegator-held-since (get-token-held-since tx-sender)))
    ;; Verify delegator has held tokens for minimum period
    (asserts! (>= (- block-height delegator-held-since) MINIMUM_HOLDING_PERIOD) (err u409))
    
    ;; Set delegation
    (map-set vote-delegations 
      { delegator: tx-sender }
      { delegate: delegate })
    
    (print { event: "delegation-set", delegator: tx-sender, delegate: delegate })
    (ok true)))

;; Revoke delegation
(define-public (revoke-delegation)
  (begin
    (map-delete vote-delegations { delegator: tx-sender })
    (print { event: "delegation-revoked", delegator: tx-sender })
    (ok true)))

;; Vote with time-weighted power
(define-public (vote-time-weighted (proposal-id uint) (support bool))
  (let (
    (weighted-power (get-time-weighted-power proposal-id tx-sender))
    (proposal (unwrap! (map-get? proposals { id: proposal-id }) (err u404)))
  )
    ;; Verify snapshot exists and is valid
    (asserts! (> weighted-power u0) (err u410))
    (asserts! (is-eq (get status proposal) PROPOSAL_STATUS_ACTIVE) (err u405))
    
    ;; Record vote with weighted power
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      { support: support, voting-power: weighted-power })
    
    ;; Update vote tallies
    (if support
      (map-set proposals { id: proposal-id }
        (merge proposal { 
          votes-for: (+ (get votes-for proposal) weighted-power)
        }))
      (map-set proposals { id: proposal-id }
        (merge proposal { 
          votes-against: (+ (get votes-against proposal) weighted-power)
        })))
    
    (print { 
      event: "vote-cast", 
      proposal-id: proposal-id, 
      voter: tx-sender, 
      support: support, 
      weighted-power: weighted-power 
    })
    (ok true)))

;; Error codes for time-weighted voting
;; u409: insufficient-holding-period
;; u410: no-snapshot-found
```
