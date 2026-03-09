;; conxian-protocol.clar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u1001))

(define-data-var paused bool false)
;; Placeholder that will be overridden by the first caller (deployer in sim)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var initialized bool false)

;; @desc Returns the current status of the protocol
(define-read-only (get-protocol-status)
  (ok { compliant: true, paused: (var-get paused), tenure-id: (some (/ block-height u10)), timestamp: burn-block-height, version: "07" })
)

(define-read-only (is-paused) (var-get paused))
(define-read-only (get-protocol-admin) (var-get contract-owner))

;; @desc Toggles the protocol's global pause state. Admin only.
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused new-paused)
    (ok true)
  )
)

;; @desc Sets the owner. In simulation, allows the first caller to claim ownership if not initialized.
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (not (var-get initialized))) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (var-set initialized true)
    (ok true)
  )
)
