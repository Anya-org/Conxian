;; conxian-protocol.clar
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)

(define-data-var paused bool false)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; @desc Returns the current status of the protocol, including compliance, pause state, tenure ID, and version.
(define-read-only (get-protocol-status)
  (ok { compliant: true, paused: (var-get paused), tenure-id: (some (/ block-height u10)), timestamp: burn-block-height, version: "07" })
)

;; @desc Returns whether the protocol is currently in a paused state.
(define-read-only (is-paused) (var-get paused))

;; @desc Returns the principal that is currently the owner/administrator of the protocol registry.
(define-read-only (get-protocol-admin) (var-get contract-owner))

;; @desc Toggles the protocol's global pause state. Admin only.
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set paused new-paused)
    (ok true)
  )
)
