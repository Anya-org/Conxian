;; sab-election.clar
;; Autonomous, burn-block-height based election cycles for SAB governance.
;;
;; This contract records an escrowed, token-weighted election result. It does
;; not mint or install a governance NFT seat; downstream governance code can
;; consume the finalized result if a successful election has a winner.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant BPS u10000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_BLOCK_WINDOW u1000000)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_TOKEN u1001)
(define-constant ERR_ACTIVE_CYCLE u1002)
(define-constant ERR_NO_ACTIVE_CYCLE u1003)
(define-constant ERR_CYCLE_NOT_FOUND u1004)
(define-constant ERR_INVALID_DURATION u1005)
(define-constant ERR_INVALID_BPS u1006)
(define-constant ERR_ZERO_SUPPLY u1007)
(define-constant ERR_NOT_NOMINATION_PHASE u1008)
(define-constant ERR_NOT_VOTING_PHASE u1009)
(define-constant ERR_CANDIDATE_EXISTS u1010)
(define-constant ERR_CANDIDATE_NOT_FOUND u1011)
(define-constant ERR_ZERO_AMOUNT u1012)
(define-constant ERR_ALREADY_VOTED u1013)
(define-constant ERR_NOT_FINALIZABLE u1014)
(define-constant ERR_ALREADY_FINALIZED u1015)
(define-constant ERR_NOT_FINALIZED u1016)
(define-constant ERR_ALREADY_CLAIMED u1017)
(define-constant ERR_ARITHMETIC_OVERFLOW u1018)

(define-data-var admin principal tx-sender)
(define-data-var voting-token principal tx-sender)
(define-data-var nomination-duration uint u10)
(define-data-var voting-duration uint u20)
(define-data-var quorum-bps uint u5000)
(define-data-var approval-bps uint u5000)
(define-data-var next-cycle-id uint u1)
(define-data-var active-cycle (optional uint) none)

(define-map cycles uint {
  nomination-start: uint,
  nomination-end: uint,
  voting-start: uint,
  voting-end: uint,
  voting-token: principal,
  supply-snapshot: uint,
  quorum-bps: uint,
  approval-bps: uint,
  total-votes: uint,
  leading-candidate: (optional principal),
  leading-votes: uint,
  tie: bool,
  finalized: bool,
  winner: (optional principal),
  succeeded: bool
})

(define-map candidates { cycle-id: uint, candidate: principal } {
  metadata-hash: (buff 32),
  votes: uint
})

(define-map votes { cycle-id: uint, voter: principal } {
  candidate: principal,
  amount: uint,
  claimed: bool
})

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (is-active-cycle (cycle-id uint))
  (is-eq (var-get active-cycle) (some cycle-id))
)

(define-private (is-token-configured (token <sip-010-ft-trait>))
  (is-eq (contract-of token) (var-get voting-token))
)

(define-private (safe-add-blocks (base uint) (window uint))
  (if (> window (- MAX_UINT base))
    none
    (some (+ base window))
  )
)

;; Compute ceil(amount * bps / 10,000) without multiplying the full amount by
;; bps. With bps bounded to BPS, each intermediate product and the final sum
;; remain within uint bounds.
(define-private (ceil-bps-threshold (amount uint) (bps uint))
  (let (
      (whole-part (* (/ amount BPS) bps))
      (remainder-part (* (mod amount BPS) bps))
    )
    (+ whole-part
      (if (is-eq remainder-part u0)
        u0
        (if (is-eq (mod remainder-part BPS) u0)
          (/ remainder-part BPS)
          (+ (/ remainder-part BPS) u1)
        )
      )
    )
  )
)

;; @desc Update the administrator. The current administrator only may do so.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Configure the principal that must back election token trait calls.
(define-public (set-voting-token (token principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set voting-token token)
    (print { event: "sab-election-token-configured", token: token })
    (ok true)
  )
)

;; @desc Configure positive nomination/voting durations and quorum/approval BPS.
(define-public (set-parameters
    (new-nomination-duration uint)
    (new-voting-duration uint)
    (new-quorum-bps uint)
    (new-approval-bps uint)
  )
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> new-nomination-duration u0) (err ERR_INVALID_DURATION))
    (asserts! (> new-voting-duration u0) (err ERR_INVALID_DURATION))
    (asserts! (<= new-nomination-duration MAX_BLOCK_WINDOW) (err ERR_INVALID_DURATION))
    (asserts! (<= new-voting-duration MAX_BLOCK_WINDOW) (err ERR_INVALID_DURATION))
    (asserts! (<= new-quorum-bps BPS) (err ERR_INVALID_BPS))
    (asserts! (<= new-approval-bps BPS) (err ERR_INVALID_BPS))
    (var-set nomination-duration new-nomination-duration)
    (var-set voting-duration new-voting-duration)
    (var-set quorum-bps new-quorum-bps)
    (var-set approval-bps new-approval-bps)
    (print {
      event: "sab-election-parameters-updated",
      nomination-duration: new-nomination-duration,
      voting-duration: new-voting-duration,
      quorum-bps: new-quorum-bps,
      approval-bps: new-approval-bps
    })
    (ok true)
  )
)

;; @desc Open one election cycle and snapshot the configured token supply.
;; Anyone may open a cycle; only one cycle can be active at a time.
(define-public (open-cycle (token <sip-010-ft-trait>))
  (begin
    (asserts! (is-token-configured token) (err ERR_INVALID_TOKEN))
    (asserts! (is-none (var-get active-cycle)) (err ERR_ACTIVE_CYCLE))
    (let (
        (cycle-id (var-get next-cycle-id))
        (start burn-block-height)
        (nomination-duration-snapshot (var-get nomination-duration))
        (voting-duration-snapshot (var-get voting-duration))
        (nomination-end
          (unwrap!
            (safe-add-blocks burn-block-height nomination-duration-snapshot)
            (err ERR_INVALID_DURATION)
          )
        )
        (voting-end
          (unwrap!
            (safe-add-blocks nomination-end voting-duration-snapshot)
            (err ERR_INVALID_DURATION)
          )
        )
        (supply (try! (contract-call? token get-total-supply)))
      )
      (begin
        (asserts! (> supply u0) (err ERR_ZERO_SUPPLY))
        ;; The cycle identifier is monotonic; reject the terminal value before
        ;; advancing it so the next identifier cannot wrap.
        (asserts! (< cycle-id MAX_UINT) (err ERR_ARITHMETIC_OVERFLOW))
        (map-set cycles cycle-id {
          nomination-start: start,
          nomination-end: nomination-end,
          voting-start: nomination-end,
          voting-end: voting-end,
          voting-token: (contract-of token),
          supply-snapshot: supply,
          quorum-bps: (var-get quorum-bps),
          approval-bps: (var-get approval-bps),
          total-votes: u0,
          leading-candidate: none,
          leading-votes: u0,
          tie: false,
          finalized: false,
          winner: none,
          succeeded: false
        })
        (var-set active-cycle (some cycle-id))
        (var-set next-cycle-id (+ cycle-id u1))
        (print {
          event: "sab-election-cycle-opened",
          cycle-id: cycle-id,
          nomination-start: start,
          nomination-end: nomination-end,
          voting-end: voting-end,
          supply-snapshot: supply
        })
        (ok cycle-id)
      )
    )
  )
)

;; @desc Self-nominate during the nomination window with a metadata hash.
(define-public (nominate (cycle-id uint) (metadata-hash (buff 32)))
  (let ((cycle (unwrap! (map-get? cycles cycle-id) (err ERR_CYCLE_NOT_FOUND))))
    (begin
      (asserts! (is-active-cycle cycle-id) (err ERR_NO_ACTIVE_CYCLE))
      (asserts! (not (get finalized cycle)) (err ERR_ALREADY_FINALIZED))
      (asserts! (>= burn-block-height (get nomination-start cycle)) (err ERR_NOT_NOMINATION_PHASE))
      (asserts! (< burn-block-height (get nomination-end cycle)) (err ERR_NOT_NOMINATION_PHASE))
      (asserts!
        (is-none (map-get? candidates { cycle-id: cycle-id, candidate: tx-sender }))
        (err ERR_CANDIDATE_EXISTS)
      )
      (map-set candidates { cycle-id: cycle-id, candidate: tx-sender } {
        metadata-hash: metadata-hash,
        votes: u0
      })
      (print {
        event: "sab-election-candidate-nominated",
        cycle-id: cycle-id,
        candidate: tx-sender,
        metadata-hash: metadata-hash
      })
      (ok true)
    )
  )
)

;; @desc Cast one escrowed token-weighted vote for one registered candidate.
(define-public (vote
    (cycle-id uint)
    (candidate principal)
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (begin
    (let (
        (cycle (unwrap! (map-get? cycles cycle-id) (err ERR_CYCLE_NOT_FOUND)))
        (candidate-key { cycle-id: cycle-id, candidate: candidate })
        (vote-key { cycle-id: cycle-id, voter: tx-sender })
      )
      (begin
        (asserts! (is-eq (contract-of token) (get voting-token cycle)) (err ERR_INVALID_TOKEN))
        (asserts! (is-active-cycle cycle-id) (err ERR_NO_ACTIVE_CYCLE))
        (asserts! (not (get finalized cycle)) (err ERR_ALREADY_FINALIZED))
        (asserts! (>= burn-block-height (get voting-start cycle)) (err ERR_NOT_VOTING_PHASE))
        (asserts! (< burn-block-height (get voting-end cycle)) (err ERR_NOT_VOTING_PHASE))
        (asserts! (> amount u0) (err ERR_ZERO_AMOUNT))
        (asserts! (<= amount (- MAX_UINT (get total-votes cycle))) (err ERR_ARITHMETIC_OVERFLOW))
        (asserts! (is-some (map-get? candidates candidate-key)) (err ERR_CANDIDATE_NOT_FOUND))
        (asserts! (is-none (map-get? votes vote-key)) (err ERR_ALREADY_VOTED))
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        (let (
            (candidate-data (unwrap! (map-get? candidates candidate-key) (err ERR_CANDIDATE_NOT_FOUND)))
            (new-candidate-votes (+ (get votes candidate-data) amount))
            (leading-candidate (get leading-candidate cycle))
            (leading-votes (get leading-votes cycle))
            (new-leading-candidate
              (if (or (is-none leading-candidate) (> new-candidate-votes leading-votes))
                (some candidate)
                leading-candidate
              )
            )
            (new-leading-votes
              (if (or (is-none leading-candidate) (> new-candidate-votes leading-votes))
                new-candidate-votes
                leading-votes
              )
            )
            (new-tie
              (if (is-none leading-candidate)
                false
                (if (> new-candidate-votes leading-votes)
                  false
                  (if (is-eq new-candidate-votes leading-votes)
                    true
                    (get tie cycle)
                  )
                )
              )
            )
          )
          (begin
            (map-set votes vote-key {
              candidate: candidate,
              amount: amount,
              claimed: false
            })
            (map-set candidates candidate-key (merge candidate-data { votes: new-candidate-votes }))
            (map-set cycles cycle-id (merge cycle {
              total-votes: (+ (get total-votes cycle) amount),
              leading-candidate: new-leading-candidate,
              leading-votes: new-leading-votes,
              tie: new-tie
            }))
            (print {
              event: "sab-election-vote-cast",
              cycle-id: cycle-id,
              voter: tx-sender,
              candidate: candidate,
              amount: amount,
              total-votes: (+ (get total-votes cycle) amount)
            })
            (ok true)
          )
        )
      )
    )
  )
)

;; @desc Finalize a cycle permissionlessly after voting ends.
;; A failed result still finalizes and releases the active-cycle lock.
(define-public (finalize-cycle (cycle-id uint))
  (let ((cycle (unwrap! (map-get? cycles cycle-id) (err ERR_CYCLE_NOT_FOUND))))
    (begin
      (asserts! (is-active-cycle cycle-id) (err ERR_NO_ACTIVE_CYCLE))
      (asserts! (not (get finalized cycle)) (err ERR_ALREADY_FINALIZED))
      (asserts! (>= burn-block-height (get voting-end cycle)) (err ERR_NOT_FINALIZABLE))
      (let (
          (total-votes (get total-votes cycle))
          (supply-snapshot (get supply-snapshot cycle))
          (leading-votes (get leading-votes cycle))
          (leading-candidate (get leading-candidate cycle))
          (quorum-met (>= total-votes (ceil-bps-threshold supply-snapshot (get quorum-bps cycle))))
          (approval-met
            (and
              (> total-votes u0)
              (>= leading-votes (ceil-bps-threshold total-votes (get approval-bps cycle)))
            )
          )
          (succeeded
            (and
              quorum-met
              approval-met
              (not (get tie cycle))
              (is-some leading-candidate)
            )
          )
          (winner (if succeeded leading-candidate none))
        )
        (begin
          (map-set cycles cycle-id (merge cycle {
            finalized: true,
            winner: winner,
            succeeded: succeeded
          }))
          (var-set active-cycle none)
          (print {
            event: "sab-election-cycle-finalized",
            cycle-id: cycle-id,
            total-votes: total-votes,
            quorum-met: quorum-met,
            approval-met: approval-met,
            tie: (get tie cycle),
            winner: winner,
            succeeded: succeeded
          })
          (ok succeeded)
        )
      )
    )
  )
)

;; @desc Claim the caller's escrowed stake once after cycle finalization.
(define-public (claim-stake (cycle-id uint) (token <sip-010-ft-trait>))
  (begin
    (let (
        (cycle (unwrap! (map-get? cycles cycle-id) (err ERR_CYCLE_NOT_FOUND)))
        (voter tx-sender)
        (vote-key { cycle-id: cycle-id, voter: tx-sender })
        (vote-data (unwrap! (map-get? votes vote-key) (err ERR_ALREADY_CLAIMED)))
      )
      (begin
        (asserts! (is-eq (contract-of token) (get voting-token cycle)) (err ERR_INVALID_TOKEN))
        (asserts! (get finalized cycle) (err ERR_NOT_FINALIZED))
        (asserts! (not (get claimed vote-data)) (err ERR_ALREADY_CLAIMED))
        (try! (as-contract (contract-call? token transfer (get amount vote-data) tx-sender voter none)))
        (map-set votes vote-key (merge vote-data { claimed: true }))
        (print {
          event: "sab-election-stake-claimed",
          cycle-id: cycle-id,
          voter: voter,
          amount: (get amount vote-data)
        })
        (ok (get amount vote-data))
      )
    )
  )
)

;; @desc Return the election configuration.
(define-read-only (get-config)
  {
    admin: (var-get admin),
    voting-token: (var-get voting-token),
    nomination-duration: (var-get nomination-duration),
    voting-duration: (var-get voting-duration),
    quorum-bps: (var-get quorum-bps),
    approval-bps: (var-get approval-bps),
    next-cycle-id: (var-get next-cycle-id),
    active-cycle: (var-get active-cycle)
  }
)

(define-read-only (get-cycle (cycle-id uint))
  (map-get? cycles cycle-id)
)

(define-read-only (get-candidate (cycle-id uint) (candidate principal))
  (map-get? candidates { cycle-id: cycle-id, candidate: candidate })
)

(define-read-only (get-vote (cycle-id uint) (voter principal))
  (map-get? votes { cycle-id: cycle-id, voter: voter })
)

(define-read-only (is-nomination-open (cycle-id uint))
  (match (map-get? cycles cycle-id)
    cycle (and (is-active-cycle cycle-id) (not (get finalized cycle)) (>= burn-block-height (get nomination-start cycle)) (< burn-block-height (get nomination-end cycle)))
    false
  )
)

(define-read-only (is-voting-open (cycle-id uint))
  (match (map-get? cycles cycle-id)
    cycle (and (is-active-cycle cycle-id) (not (get finalized cycle)) (>= burn-block-height (get voting-start cycle)) (< burn-block-height (get voting-end cycle)))
    false
  )
)
