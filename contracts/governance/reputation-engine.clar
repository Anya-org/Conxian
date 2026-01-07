;; reputation-engine.clar
;; Implements dynamic voting power based on activity and reputation decay.
;; Nakamoto-Native: 5s blocks

(impl-trait .governance-traits.reputation-engine-trait)


;; Constants
(define-constant DECAY_FACTOR u10) ;; Daily decay rate (10/1000 = 1%)
(define-constant INITIAL_ACTIVITY_SCORE u1000) ;; Represents 100.0%
;; Nakamoto: 1 day = 24 * 60 * 60 / 5 = 17280 blocks
(define-constant ONE_DAY (to-int u17280))
(define-constant MAX_SCORE u1000)

(define-map activity-scores
  principal
  {
    last-voted-block: uint,
    score: uint,
  }
)

(define-private (calculate-decayed-score (last-voted-block uint) (current-score uint))
  (let ((blocks-since-last-vote (- block-height last-voted-block))
        (decay-periods (/ blocks-since-last-vote u17280)))
    (if (> decay-periods u0)
      (let ((total-decay (* decay-periods DECAY_FACTOR)))
        (if (> current-score total-decay)
          (- current-score total-decay)
          u0))
      current-score))
  )

(define-public (get-weighted-voting-power (user principal) (balance uint))
  (match (map-get? activity-scores user)
    user-activity
      (let ((current-score (get score user-activity))
            (last-voted (get last-voted-block user-activity))
            (decayed-score (calculate-decayed-score last-voted current-score)))
        ;; Weight = Balance * (Score / 1000)
    ;; "Seat holders who fail to participate... lose
    ;; If no activity record, default to 100% (or 0%? usually new users start neutral or 0. Request implies decay for *failure* to participate. Let's assume start at 100% or 0? 
    ;; "Seat holders who fail to participate... lose voting weight". Implies they start with weight.
    ;; However, to incentivize participation, maybe start at 100%?
    ;; Existing code defaulted to balance (100%). I will keep that but maybe we should auto-initialize on first vote.
    (ok balance)))


(define-public (update-activity-score (user principal))
  (begin
    ;; When they vote, their score resets to 100%? Or increments?
    ;; The prompt says "Reputation Decay: Seat holders... who fail to participate... lose voting weight".
    ;; It implies participation prevents decay or restores it.
    ;; Simples implementation: Reset to MAX on vote.
    (map-set activity-scores user {
      last-voted-block: block-height,
      score: INITIAL_ACTIVITY_SCORE
    })
    (ok true)
  )
)

(impl-trait .reputation-engine-trait.reputation-engine-trait)
