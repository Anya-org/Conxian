;; governance-metrics.clar
;;
;; This contract tracks governance metrics like participation, quorum, and latency.
;; This version is designed to avoid on-chain recursion.

;; Data variables
(define-data-var dao-governance principal .dao-governance)

;; A map to identify founders.
(define-map founders principal bool)

;; A map to store the number of votes per founder per epoch.
(define-map founder-votes-per-epoch {founder: principal, epoch: uint} uint)

;; A map to store the total number of proposals per epoch.
(define-map proposals-per-epoch uint uint)

(define-public (add-founder (founder principal))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (map-set founders founder true)
    (ok true)
  )
)

(define-public (increment-proposal-count (epoch uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (let ((current-count (default-to u0 (map-get? proposals-per-epoch epoch))))
      (map-set proposals-per-epoch epoch (+ current-count u1))
      (ok true)
    )
  )
)

(define-public (increment-vote-count (founder principal) (epoch uint))
  (begin
    (asserts! (is-eq tx-sender (var-get dao-governance)) (err u100))
    (asserts! (is-founder founder) (err u101))
    (let ((current-count (default-to u0 (map-get? founder-votes-per-epoch {founder: founder, epoch: epoch}))))
      (map-set founder-votes-per-epoch {founder: founder, epoch: epoch} (+ current-count u1))
      (ok true)
    )
  )
)

(define-read-only (is-founder (principal principal))
  (default-to false (map-get? founders principal))
)

(define-read-only (get-participation-rate (founder principal) (epoch uint))
  (let ((total-proposals (default-to u0 (map-get? proposals-per-epoch epoch)))
        (founder-votes (default-to u0 (map-get? founder-votes-per-epoch {founder: founder, epoch: epoch}))))
    (if (is-eq total-proposals u0)
      (ok u0)
      (ok (/ (* founder-votes u100) total-proposals))
    )
  )
)

;; Errors
;; u100: unauthorized
;; u101: not a founder
