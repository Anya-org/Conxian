;; position-manager.clar
;; Conxian Protocol Standard Contract
;; Manages the lifecycle of trading positions

(impl-trait .core-traits.position-orchestrator-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_NOT_AUTHORIZED u1000)
(define-constant ERR_POSITION_NOT_FOUND u3000)

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var dimensional-engine principal tx-sender)

(define-map positions
  uint
  {
    owner: principal, token: principal, size: uint, collateral: uint, leverage: uint, entry-price: uint, is-long: bool, open: bool
  }
)

(define-data-var next-position-id uint u1)

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-engine)
  (is-eq tx-sender (var-get dimensional-engine))
)

(define-public (set-dimensional-engine (engine principal))
  (begin
    (asserts! (is-standard? engine) (err ERR_UNAUTHORIZED))
    (asserts! (is-owner) (err ERR_NOT_AUTHORIZED))
    (var-set dimensional-engine engine)
    (ok true)
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-standard? new-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-owner) (err ERR_NOT_AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (open-position (user principal) (token principal) (amount uint) (leverage uint) (long bool))
  (let ((pos-id (var-get next-position-id)))
    (begin
      (asserts! (is-engine) (err ERR_NOT_AUTHORIZED))
      (map-set positions pos-id {
        owner: user, token: token, size: (* amount leverage), collateral: amount, leverage: leverage, entry-price: u0, is-long: long, open: true
      })
      (var-set next-position-id (+ pos-id u1))
      (ok pos-id)
    )
  )
)

(define-public (close-position (user principal) (position-id uint))
  (begin
    (let ((pos (unwrap! (map-get? positions position-id) (err ERR_POSITION_NOT_FOUND))))
      (begin
        (asserts! (is-eq (get owner pos) user) (err ERR_NOT_AUTHORIZED))
        (map-set positions position-id (merge pos { open: false }))
        (ok true)
      )
    )
  )
)

(define-public (force-close-position (position-id uint))
  (begin
    (asserts! (is-engine) (err ERR_NOT_AUTHORIZED))
    (let ((pos (unwrap! (map-get? positions position-id) (err ERR_POSITION_NOT_FOUND))))
      (begin
        (map-set positions position-id (merge pos { open: false }))
        (ok true)
      )
    )
  )
)

(define-public (liquidate-position (liquidator principal) (position-id uint))
  (begin
    (asserts! (is-engine) (err ERR_NOT_AUTHORIZED))
    (let ((pos (unwrap! (map-get? positions position-id) (err ERR_POSITION_NOT_FOUND))))
      (begin
        (map-set positions position-id (merge pos { open: false }))
        (ok true)
      )
    )
  )
)

(define-read-only (get-position (position-id uint))
  (match (map-get? positions position-id)
    pos (ok pos)
    (err u3000)
  )
)
