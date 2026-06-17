;; enhanced-circuit-breaker.clar
;; Conxian Protocol - Enhanced Circuit Breaker (Apex v1.1.0)

(impl-trait .security-monitoring.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u8000))

(define-data-var admin principal tx-sender)
(define-data-var global-pause bool false)

(define-map paused-contracts principal bool)
(define-map isolated-protocols principal bool)

(define-read-only (is-admin (user principal))
  (is-eq user (var-get admin))
)

(define-read-only (is-contract-paused (target principal))
  (ok (or (var-get global-pause) (default-to false (map-get? paused-contracts target))))
)

(define-read-only (is-globally-paused)
  (ok (var-get global-pause))
)

(define-read-only (is-isolated (protocol principal))
  (ok (default-to false (map-get? isolated-protocols protocol)))
)

;; @desc Toggles the protocol-wide emergency pause. Admin only.
;; @return (response bool uint) - Returns ok(new-pause-state) on success, or an error.
(define-public (toggle-global-pause)
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set global-pause (not (var-get global-pause)))
    (ok (var-get global-pause))
  )
)

;; @desc Toggles the pause state for a specific contract. Admin only.
;; @param target: The contract principal to toggle.
;; @return (response bool uint) - Returns ok(new-pause-state) on success, or an error.
(define-public (toggle-contract-pause (target principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? paused-contracts target))))
      (map-set paused-contracts target (not current))
      (ok (not current))
    )
  )
)

;; @desc Toggles isolation mode for a specific external protocol. Admin only.
;; @param protocol: The external protocol principal to toggle isolation for.
;; @return (response bool uint) - Returns ok(new-isolation-state) on success, or an error.
(define-public (toggle-isolation (protocol principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? isolated-protocols protocol))))
      (map-set isolated-protocols protocol (not current))
      (ok (not current))
    )
  )
)

;; @desc Sets a new administrator for the enhanced circuit breaker. Admin only.
;; @param new-admin: The new administrator principal.
;; @return (response bool uint) - Returns ok(true) on success, or an error.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
