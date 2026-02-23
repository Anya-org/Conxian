;; reputation-engine.clar
;; Conxian Protocol Standard Contract

;; reputation-engine.clar
;; Implements dynamic voting power based on activity and reputation decay.

(use-trait reputation-engine-trait .governance-traits.reputation-engine-trait)
(impl-trait .governance-traits.reputation-engine-trait)

;; Constants
(define-constant DECAY_FACTOR u10) ;; Daily decay rate (10/1000 = 1%)
(define-constant MAX_SCORE u1000)
(define-constant INITIAL_ACTIVITY_SCORE MAX_SCORE)
(define-constant ONE_DAY u17280) ;; 24h * 60m * 60s / 5s (Stacks block time)

(define-map activity-scores
  principal
  {
    last-voted-block: uint,
    score: uint
  }
)

(define-private (calculate-decayed-score (last-voted-block uint) (current-score uint))
  (let (
    (blocks-since-last-vote (- burn-block-height last-voted-block))
    (decay-periods (/ blocks-since-last-vote ONE_DAY))
  )
    (if (> decay-periods u0)
      (let ((total-decay (* decay-periods DECAY_FACTOR)))
        (if (> current-score total-decay)
          (- current-score total-decay)
          u0))
      current-score)
  )
)


;; @desc Get weighted voting power
;; @returns (response bool uint)
(define-public (get-weighted-voting-power (user principal) (balance uint))
  (let (
    (activity-data (map-get? activity-scores user))
    (effective-score
      (match activity-data
        user-activity
          (let (
            (current-score (get score user-activity))
            (last-voted (get last-voted-block user-activity))
          )
            (calculate-decayed-score last-voted current-score)
          )
        MAX_SCORE
      )
    )
   )
    (ok (/ (* balance effective-score) MAX_SCORE))
  )
)


;; @desc Update activity score
;; @returns (response bool uint)
(define-public (update-activity-score (user principal))
  (begin
    (map-set activity-scores user {
      last-voted-block: burn-block-height,
      score: INITIAL_ACTIVITY_SCORE
    })
    (ok true)
  )
)
