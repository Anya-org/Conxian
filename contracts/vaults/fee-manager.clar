;; fee-manager.clar
;; Conxian Finance: Fee Manager
;; Calculates and collects protocol fees.

;; Constants
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant MAX_FEE u500) ;; 5% max fee

;; State
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var default-fee-bps uint u30) ;; 0.3%

;; Authorization
(define-private (is-admin) (is-eq tx-sender (var-get admin)))

;; Public Functions

(define-public (set-default-fee (new-rate uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-rate MAX_FEE) (err ERR_UNAUTHORIZED))
    (var-set default-fee-bps new-rate)
    (ok true)
  )
)

;; @desc Calculate fee for a given amount
(define-read-only (calculate-fee (amount uint))
  (ok (/ (* amount (var-get default-fee-bps)) u10000))
)

;; @desc Calculate fee for a specific tier
(define-read-only (calculate-tiered-fee (amount uint) (tier uint))
  (let (
    (rate (if (is-eq tier u2) u20 (if (is-eq tier u3) u10 (var-get default-fee-bps))))
  )
    (ok (/ (* amount rate) u10000))
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
