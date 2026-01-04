;; reputation-engine.clar
;; Implements dynamic voting power based on activity and reputation decay.

(use-trait reputation-trait .reputation-engine-trait.reputation-engine-trait)

(define-constant DECAY_FACTOR u10) ;; Daily decay rate (e.g., 10 = 1% decay, so 10/1000)
(define-constant INITIAL_ACTIVITY_SCORE u1000) ;; Represents 100.0%
(define-constant ONE_DAY (to-int u144))
(define-constant MAX_SCORE u1000)

(define-map activity-scores principal { last-voted-block: int, score: uint })

(define-private (calculate-decayed-score (last-voted-block int) (current-score uint))
  (let ((blocks-since-last-vote (- (to-int block-height) last-voted-block))
        (decay-periods (/ blocks-since-last-vote ONE_DAY)))
    (if (> decay-periods u0)
      (let ((total-decay (* decay-periods DECAY_FACTOR)))
        (if (> current-score total-decay)
          (- current-score total-decay)
          u0))
      current-score)))

(define-public (get-weighted-voting-power (user principal) (balance uint))
  (match (map-get? activity-scores user)
    (user-activity
      (let ((current-score (get score user-activity))
            (last-voted (get last-voted-block user-activity))
            (decayed-score (calculate-decayed-score last-voted current-score)))
        (ok (/ (* balance decayed-score) MAX_SCORE))))
    (ok balance)))


(define-public (update-activity-score (user principal))
  (begin
    (map-set activity-scores user {
      last-voted-block: (to-int block-height),
      score: INITIAL_ACTIVITY_SCORE
    })
    (ok true)))

(impl-trait .reputation-engine-trait.reputation-engine-trait)
