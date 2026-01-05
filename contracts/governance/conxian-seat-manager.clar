;; conxian-seat-manager.clar
;;
;; This contract manages the issuance of Conxian Governance Seats, which are
;; represented as SIP-009 Non-Fungible Tokens. A Governance Seat is required,
;; in addition to holding the appropriate governance token (CXVG or CXTR),
;; to participate in vault and treasury governance.

(define-non-fungible-token governance-seat uint)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_SEAT_ALREADY_ISSUED (err u10001))

(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)
(define-map seat-owners uint principal)

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (issue-seat (recipient principal))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (let ((new-seat-id (+ (var-get last-token-id) u1)))
      (try! (nft-mint? governance-seat new-seat-id recipient))
      (var-set last-token-id new-seat-id)
      (map-set seat-owners new-seat-id recipient)
      (ok new-seat-id)
    )
  )
)

(define-read-only (get-owner (seat-id uint))
  (ok (map-get? seat-owners seat-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)
