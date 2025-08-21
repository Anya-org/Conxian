;; Minimal DAO skeleton owning Timelock to govern Vault

(define-data-var admin principal tx-sender)
(define-data-var gov-token principal .gov-token)
(define-data-var timelock principal .timelock)
(define-data-var vault principal .vault)
(define-data-var propose-threshold uint u1)

(define-read-only (get-config)
  { admin: (var-get admin),
    gov-token: (var-get gov-token),
    timelock: (var-get timelock),
    vault: (var-get vault),
    threshold: (var-get propose-threshold) }
)

(define-public (set-admin (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin p)
    (ok true)
  )
)

(define-public (set-config (token principal) (tl principal) (v principal) (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set gov-token token)
    (var-set timelock tl)
    (var-set vault v)
    (var-set propose-threshold threshold)
    (ok true)
  )
)

(define-read-only (get-voting-power (who principal))
  (unwrap-panic (contract-call? .gov-token get-balance-of who))
)

(define-private (assert-threshold (who principal))
  (let ((bal (unwrap-panic (contract-call? .gov-token get-balance-of who))))
    (if (>= bal (var-get propose-threshold)) (ok true) (err u101))
  )
)

;; Governance actions: queue via Timelock (DAO must be admin of Timelock)
(define-public (propose-pause (p bool))
  (begin
    (unwrap! (assert-threshold tx-sender) (err u101))
    ;; Will be enabled after timelock deployment
    ;; (as-contract (contract-call? .timelock queue-set-paused p))
    (ok true) 
  )
)

(define-public (propose-set-fee-split-bps (bps uint))
  (begin
    (unwrap! (assert-threshold tx-sender) (err u101))
    ;; (as-contract (contract-call? .timelock queue-set-fee-split-bps bps))
    (ok true) ;; Placeholder
  )
)

(define-public (propose-withdraw-treasury (to principal) (amount uint))
  (begin
    (unwrap! (assert-threshold tx-sender) (err u101))
    ;; (as-contract (contract-call? .timelock queue-withdraw-treasury to amount)) ;; temporarily disabled
    (ok true)
  )
)

;; Errors
;; u100: unauthorized
;; u101: insufficient-voting-power
