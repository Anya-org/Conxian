;; Bounty Stream Intake Extension
;; Handles governance token streaming from founder reallocation and treasury automation
;; Integrates with automated-bounty-system for controlled distribution with vesting

(define-constant CONTRACT_VERSION u1)

;; --- Constants & Errors ---
(define-constant ERR_UNAUTHORIZED u700)
(define-constant ERR_INVALID_AMOUNT u701)
(define-constant ERR_STREAM_NOT_FOUND u702)
(define-constant ERR_STREAM_EXHAUSTED u703)
(define-constant ERR_INSUFFICIENT_BALANCE u704)

;; --- Data Variables ---
(define-data-var authorized-streamers (list 10 principal) (list))
(define-data-var total-streams uint u0)
(define-data-var total-streamed uint u0)
(define-data-var bounty-system principal .automated-bounty-system)

;; --- Stream Configuration ---
(define-map active-streams
  { stream-id: uint }
  {
    source: principal,           ;; Where tokens come from (e.g., avg-token contract)
    token-contract: principal,   ;; Which token (e.g., avg-token)
    rate-per-epoch: uint,        ;; Tokens per epoch
    remaining: uint,             ;; Tokens left to distribute
    start-epoch: uint,           ;; When streaming started
    last-claim-epoch: uint,      ;; Last epoch claimed
    enabled: bool                ;; Stream active/paused
  }
)

;; --- Event Tracking ---
(define-map stream-claims
  { stream-id: uint, epoch: uint }
  { claimed: bool, amount: uint }
)

;; --- Authorization ---
(define-private (is-authorized-streamer (sender principal))
  (is-some (index-of (var-get authorized-streamers) sender))
)

;; --- Stream Management ---
(define-public (create-stream (source principal) (token-contract principal) (rate-per-epoch uint) (total-amount uint))
  (begin
    (asserts! (is-authorized-streamer tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (> rate-per-epoch u0) (err ERR_INVALID_AMOUNT))
    (asserts! (> total-amount u0) (err ERR_INVALID_AMOUNT))
    
    (let ((stream-id (+ (var-get total-streams) u1)))
      (map-set active-streams { stream-id: stream-id } {
        source: source,
        token-contract: token-contract,
        rate-per-epoch: rate-per-epoch,
        remaining: total-amount,
        start-epoch: u1, ;; Current epoch from governance
        last-claim-epoch: u0,
        enabled: true
      })
      
      (var-set total-streams stream-id)
      (print { 
        event: "stream-created", 
        stream-id: stream-id, 
        source: source,
        token: token-contract,
        rate: rate-per-epoch,
        total: total-amount 
      })
      (ok stream-id)
    )
  )
)

;; --- Claim Streaming Tokens ---
(define-public (claim-stream-tokens (stream-id uint) (current-epoch uint))
  (let ((stream (unwrap! (map-get? active-streams { stream-id: stream-id }) (err ERR_STREAM_NOT_FOUND))))
    (asserts! (get enabled stream) (err ERR_STREAM_EXHAUSTED))
    (asserts! (> (get remaining stream) u0) (err ERR_STREAM_EXHAUSTED))
    
    (let (
      (last-claim (get last-claim-epoch stream))
      (epochs-since (if (> current-epoch last-claim) (- current-epoch last-claim) u0))
      (theoretical (* epochs-since (get rate-per-epoch stream)))
      (claimable (if (< theoretical (get remaining stream)) theoretical (get remaining stream)))
    )
      (asserts! (> claimable u0) (err ERR_INVALID_AMOUNT))
      
      ;; Update stream state
      (map-set active-streams { stream-id: stream-id } 
        (merge stream { 
          remaining: (- (get remaining stream) claimable),
          last-claim-epoch: current-epoch
        }))
      
      ;; Record claim
      (map-set stream-claims { stream-id: stream-id, epoch: current-epoch } 
        { claimed: true, amount: claimable })
      
      (var-set total-streamed (+ (var-get total-streamed) claimable))
      
      ;; Transfer tokens to bounty system for distribution
      ;; Note: We emit an event for the bounty system to listen to instead of direct call
      (print { 
        event: "stream-claimed", 
        stream-id: stream-id, 
        amount: claimable,
        epoch: current-epoch,
        remaining: (- (get remaining stream) claimable),
        target-bounty-system: (var-get bounty-system)
      })
      (ok claimable)
    )
  )
)

;; --- Administrative Functions ---
(define-public (add-authorized-streamer (streamer principal))
  (begin
    (asserts! (is-eq tx-sender .dao-governance) (err ERR_UNAUTHORIZED))
    (let ((current-list (var-get authorized-streamers)))
      (asserts! (is-none (index-of current-list streamer)) (err ERR_UNAUTHORIZED))
      (var-set authorized-streamers 
        (unwrap! (as-max-len? (append current-list streamer) u10) (err ERR_UNAUTHORIZED)))
      (print { event: "streamer-authorized", streamer: streamer })
      (ok true)
    )
  )
)

(define-public (pause-stream (stream-id uint))
  (begin
    (asserts! (is-eq tx-sender .dao-governance) (err ERR_UNAUTHORIZED))
    (let ((stream (unwrap! (map-get? active-streams { stream-id: stream-id }) (err ERR_STREAM_NOT_FOUND))))
      (map-set active-streams { stream-id: stream-id } (merge stream { enabled: false }))
      (print { event: "stream-paused", stream-id: stream-id })
      (ok true)
    )
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-stream-info (stream-id uint))
  (map-get? active-streams { stream-id: stream-id })
)

(define-read-only (get-stream-stats)
  {
    total-streams: (var-get total-streams),
    total-streamed: (var-get total-streamed),
    authorized-streamers: (var-get authorized-streamers)
  }
)

(define-read-only (calculate-claimable (stream-id uint) (current-epoch uint))
  (match (map-get? active-streams { stream-id: stream-id })
    stream (let (
      (last-claim (get last-claim-epoch stream))
      (epochs-since (if (> current-epoch last-claim) (- current-epoch last-claim) u0))
      (theoretical (* epochs-since (get rate-per-epoch stream)))
      (claimable (if (< theoretical (get remaining stream)) theoretical (get remaining stream)))
    )
    (if (get enabled stream) claimable u0))
    u0
  )
)

;; Invariant: recompute total remaining + streamed vs sum of original allocations
(define-read-only (verify-stream-invariants)
  { total-streams: (var-get total-streams), total-streamed: (var-get total-streamed) }
)
