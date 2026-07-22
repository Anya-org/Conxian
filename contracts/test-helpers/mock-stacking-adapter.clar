;; mock-stacking-adapter.clar
;; Deterministic generic stacking adapter for orchestrator tests.

(impl-trait .stacking-traits.stacking-adapter-trait)

(define-constant ERR_UNAUTHORIZED (err u9100))
(define-constant ERR_FORCED_FAILURE (err u9101))

(define-data-var admin principal tx-sender)
(define-data-var active bool true)
(define-data-var risk-bps uint u5000)
(define-data-var max-exposure uint u1000000)
(define-data-var fail-prepare bool false)
(define-data-var fail-request bool false)
(define-data-var fail-finalize bool false)

(define-map positions uint {
  amount: uint,
  owner: principal,
  status: uint
})

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-config
    (new-active bool)
    (new-risk-bps uint)
    (new-max-exposure uint)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (<= new-risk-bps u10000) (err u9102))
    (asserts! (> new-max-exposure u0) (err u9103))
    (var-set active new-active)
    (var-set risk-bps new-risk-bps)
    (var-set max-exposure new-max-exposure)
    (ok true)
  )
)

(define-public (set-failures
    (new-fail-prepare bool)
    (new-fail-request bool)
    (new-fail-finalize bool)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set fail-prepare new-fail-prepare)
    (var-set fail-request new-fail-request)
    (var-set fail-finalize new-fail-finalize)
    (ok true)
  )
)

(define-read-only (is-active)
  (ok (var-get active))
)

(define-read-only (get-risk-bps)
  (ok (var-get risk-bps))
)

(define-read-only (get-max-exposure)
  (ok (var-get max-exposure))
)

(define-public (prepare-stake (position-id uint) (amount uint) (owner principal))
  (begin
    (asserts! (not (var-get fail-prepare)) ERR_FORCED_FAILURE)
    (asserts! (var-get active) (err u9104))
    (map-set positions position-id { amount: amount, owner: owner, status: u1 })
    (ok true)
  )
)

(define-public (request-unstake (position-id uint) (amount uint) (owner principal))
  (begin
    (asserts! (not (var-get fail-request)) ERR_FORCED_FAILURE)
    (map-set positions position-id { amount: amount, owner: owner, status: u2 })
    (ok true)
  )
)

(define-public (finalize-unstake (position-id uint) (amount uint) (owner principal))
  (begin
    (asserts! (not (var-get fail-finalize)) ERR_FORCED_FAILURE)
    (map-set positions position-id { amount: amount, owner: owner, status: u3 })
    (ok amount)
  )
)

(define-read-only (get-position (position-id uint))
  (map-get? positions position-id)
)
