;; mock-pox-adapter-2.clar
;; Independent deterministic adapter used to test historical adapter binding.

(impl-trait .stacking-traits.pox-adapter-trait)

(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_FORCED_FAILURE (err u9001))
(define-constant ERR_INVALID_STATE (err u9002))
(define-constant ERR_MISSING_DELEGATION (err u9003))
(define-constant ERR_AMOUNT_MISMATCH (err u9004))
(define-constant ERR_NOT_MATURED (err u9005))

(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant EXTERNAL_ACTIVE u0)
(define-constant EXTERNAL_MATURED u1)

(define-data-var admin principal tx-sender)
(define-data-var cycle-id uint u1)
(define-data-var cycle-start uint u0)
(define-data-var cycle-length uint u10)
(define-data-var unlock-base uint u0)
(define-data-var next-external-commit-id uint u1)
(define-data-var fail-delegate bool false)
(define-data-var fail-revoke bool false)
(define-data-var fail-commit bool false)
(define-data-var fail-finalize bool false)

(define-map delegations principal {
  amount: uint,
  active: bool
})

(define-map commits (buff 32) {
  user: principal,
  amount: uint,
  cycle-id: uint,
  lock-period: uint,
  unlock-height: uint,
  external-id: uint,
  state: uint
})

(define-map external-commits uint (buff 32))

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
    (asserts! (> new-cycle-length u0) (err u9006))
    (var-set cycle-id new-cycle-id)
    (var-set cycle-start new-cycle-start)
    (var-set cycle-length new-cycle-length)
    (var-set unlock-base new-unlock-base)
    (ok true)
  )
)

(define-public (set-failures
    (new-fail-delegate bool)
    (new-fail-revoke bool)
    (new-fail-commit bool)
    (new-fail-finalize bool)
  )
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set fail-delegate new-fail-delegate)
    (var-set fail-revoke new-fail-revoke)
    (var-set fail-commit new-fail-commit)
    (var-set fail-finalize new-fail-finalize)
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
    (err u9007)
  )
)

(define-public (delegate-stx (user principal) (amount uint))
  (begin
    (asserts! (not (var-get fail-delegate)) ERR_FORCED_FAILURE)
    (asserts! (> amount u0) (err u9008))
    (asserts!
      (match (map-get? delegations user)
        existing (not (get active existing))
        true)
      (err u9009))
    (map-set delegations user { amount: amount, active: true })
    (ok true)
  )
)

(define-public (revoke-delegation (user principal))
  (let ((delegation (unwrap! (map-get? delegations user) ERR_MISSING_DELEGATION)))
    (begin
      (asserts! (not (var-get fail-revoke)) ERR_FORCED_FAILURE)
      (asserts! (get active delegation) (err u9010))
      (map-set delegations user (merge delegation { active: false }))
      (ok true)
    )
  )
)

(define-public (commit-stx
    (user principal)
    (amount uint)
    (requested-cycle-id uint)
    (lock-period uint)
    (auth-id (buff 32))
  )
  (let ((delegation (unwrap! (map-get? delegations user) ERR_MISSING_DELEGATION)))
    (begin
      (asserts! (not (var-get fail-commit)) ERR_FORCED_FAILURE)
      (asserts! (get active delegation) (err u9011))
      (asserts! (is-eq requested-cycle-id (var-get cycle-id)) (err u9012))
      (asserts! (> amount u0) (err u9013))
      (asserts! (<= amount (get amount delegation)) ERR_AMOUNT_MISMATCH)
      (asserts! (is-none (map-get? commits auth-id)) (err u9014))
      (let (
          (external-id (var-get next-external-commit-id))
          (unlock-height (+ (var-get unlock-base) lock-period))
        )
        (begin
          (asserts! (< external-id MAX_UINT) (err u9015))
          (map-set commits auth-id {
            user: user,
            amount: amount,
            cycle-id: requested-cycle-id,
            lock-period: lock-period,
            unlock-height: unlock-height,
            external-id: external-id,
            state: EXTERNAL_ACTIVE
          })
          (map-set external-commits external-id auth-id)
          (var-set next-external-commit-id (+ external-id u1))
          (ok external-id)
        )
      )
    )
  )
)

(define-public (finalize-commit (external-id uint))
  (let ((auth-id (unwrap! (map-get? external-commits external-id) (err u9016))))
    (let ((commit (unwrap! (map-get? commits auth-id) (err u9017))))
      (begin
        (asserts! (not (var-get fail-finalize)) ERR_FORCED_FAILURE)
        (asserts! (is-eq (get state commit) EXTERNAL_ACTIVE) ERR_INVALID_STATE)
        (asserts! (>= burn-block-height (get unlock-height commit)) ERR_NOT_MATURED)
        (map-set commits auth-id (merge commit { state: EXTERNAL_MATURED }))
        (ok true)
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

(define-read-only (get-external-commit (external-id uint))
  (match (map-get? external-commits external-id)
    auth-id (map-get? commits auth-id)
    none)
)

(define-read-only (get-next-external-commit-id)
  (var-get next-external-commit-id)
)
