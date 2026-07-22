;; mock-pox-adapter.clar
;; Deterministic injected PoX adapter for staking lifecycle tests.

(impl-trait .stacking-traits.pox-adapter-trait)

(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_FORCED_FAILURE (err u9001))

(define-data-var admin principal tx-sender)
(define-data-var cycle-id uint u0)
(define-data-var cycle-start uint u0)
(define-data-var cycle-length uint u10)
(define-data-var unlock-base uint u0)
(define-data-var next-external-commit-id uint u1)
(define-data-var fail-calls bool false)

(define-map delegations principal uint)
(define-map commits (buff 32) {
  user: principal,
  amount: uint,
  cycle-id: uint,
  lock-period: uint,
  external-id: uint
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

(define-public (set-cycle
    (new-cycle-id uint)
    (new-cycle-start uint)
    (new-cycle-length uint)
    (new-unlock-base uint)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (> new-cycle-length u0) (err u9002))
    (var-set cycle-id new-cycle-id)
    (var-set cycle-start new-cycle-start)
    (var-set cycle-length new-cycle-length)
    (var-set unlock-base new-unlock-base)
    (ok true)
  )
)

(define-public (set-failing (should-fail bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set fail-calls should-fail)
    (ok true)
  )
)

(define-read-only (get-cycle-info)
  (ok {
    cycle-id: (var-get cycle-id),
    cycle-start: (var-get cycle-start),
    cycle-length: (var-get cycle-length)
  })
)

(define-read-only (get-unlock-height (requested-cycle-id uint) (lock-period uint))
  (if (is-eq requested-cycle-id (var-get cycle-id))
    (ok (+ (var-get unlock-base) lock-period))
    (err u9003)
  )
)

(define-public (delegate-stx (user principal) (amount uint))
  (begin
    (asserts! (not (var-get fail-calls)) ERR_FORCED_FAILURE)
    (asserts! (> amount u0) (err u9004))
    (map-set delegations user amount)
    (ok true)
  )
)

(define-public (revoke-delegation (user principal))
  (begin
    (asserts! (not (var-get fail-calls)) ERR_FORCED_FAILURE)
    (map-delete delegations user)
    (ok true)
  )
)

(define-public (commit-stx
    (user principal)
    (amount uint)
    (requested-cycle-id uint)
    (lock-period uint)
    (auth-id (buff 32))
  )
  (begin
    (asserts! (not (var-get fail-calls)) ERR_FORCED_FAILURE)
    (asserts! (is-eq requested-cycle-id (var-get cycle-id)) (err u9005))
    (asserts! (> amount u0) (err u9006))
    (let ((external-id (var-get next-external-commit-id)))
      (begin
        (asserts! (< external-id u340282366920938463463374607431768211455) (err u9007))
        (map-set commits auth-id {
          user: user,
          amount: amount,
          cycle-id: requested-cycle-id,
          lock-period: lock-period,
          external-id: external-id
        })
        (var-set next-external-commit-id (+ external-id u1))
        (ok external-id)
      )
    )
  )
)

(define-read-only (get-delegation (user principal))
  (map-get? delegations user)
)

(define-read-only (get-commit (auth-id (buff 32)))
  (map-get? commits auth-id)
)
