;; conxian-protocol.clar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))

(define-data-var paused bool false)
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool true)

(define-map modules (string-ascii 50) { contract: principal, active: bool })

;; @desc Returns the current status of the protocol
(define-read-only (get-protocol-status)
  (ok { compliant: true, paused: (var-get paused), tenure-id: (some (/ stacks-block-height u10)), version: "C4" })
)

(define-read-only (is-paused) (var-get paused))
(define-read-only (get-protocol-admin) (var-get contract-owner))
(define-read-only (get-admin) (var-get contract-owner))

(define-read-only (get-module (name (string-ascii 50)))
  (map-get? modules name)
)

;; @desc Toggles the protocol's global pause state. Admin only.
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused new-paused)
    (ok true)
  )
)

;; @desc Register a module contract
(define-public (register-module (name (string-ascii 50)) (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set modules name { contract: contract, active: true })
    (ok true)
  )
)

;; @desc Sets the owner. Only the current owner can transfer ownership.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-standard? new-owner) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
