;; reputation-engine.clar
;; Sovereign Reputation & Voting Boost Engine
;; Aligned with Chappies Ethos: Reputation-Driven Bitcoin-Anchored

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant BNS_BOOST_BPS u5000) ;; 50% boost for having a .btc name

(define-data-var admin principal tx-sender)

;; --- Read-Only Functions ---

;; @desc Calculate voting weight boost based on BNS identity
(define-read-only (get-voter-boost (voter principal))
  (let (
    (has-bns (is-some (contract-call? .bns-stub resolve-principal voter)))
  )
    (if has-bns
      (+ u10000 BNS_BOOST_BPS) ;; 1.5x multiplier in basis points
      u10000                   ;; 1.0x multiplier
    )
  )
)

;; @desc Calculate final weight for a base token balance
;; @returns (response uint uint)
(define-public (get-weighted-voting-power (voter principal) (base-balance uint))
  (let (
    (boost (get-voter-boost voter))
  )
    (ok (/ (* base-balance boost) u10000))
  )
)

;; @desc Update activity score for a voter (Sovereign Reputation)
(define-public (update-activity-score (voter principal))
  (begin
    ;; In production this would increment a map-based score
    (print { event: "reputation-updated" voter: voter })
    (ok true)
  )
)

;; --- Admin Functions ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
