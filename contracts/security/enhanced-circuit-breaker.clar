;; enhanced-circuit-breaker.clar
;; Conxian Protocol - Enhanced Circuit Breaker (Apex v1.1.0)

(impl-trait .security-monitoring.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u8000))

(define-data-var admin principal tx-sender)
(define-data-var global-pause bool false)

(define-map paused-contracts principal bool)
(define-map isolated-protocols principal bool)

;; @desc Checks if a user is an authorized administrator for the circuit breaker.
;; @param user: The principal to verify.
(define-read-only (is-admin (user principal))
  (is-eq user (var-get admin))
)

;; @desc Checks if a specific contract principal is currently paused.
;; @param target: The contract principal to check.
(define-read-only (is-contract-paused (target principal))
  (ok (or (var-get global-pause) (default-to false (map-get? paused-contracts target))))
)

;; @desc Checks the status of the global protocol-wide pause.
(define-read-only (is-globally-paused)
  (ok (var-get global-pause))
)

;; @desc Checks if an external protocol is isolated from the CSF router.
;; @param protocol: The external protocol principal.
(define-read-only (is-isolated (protocol principal))
  (ok (default-to false (map-get? isolated-protocols protocol)))
)

;; @desc Toggles the protocol-wide global pause state. Admin only.
(define-public (toggle-global-pause)
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set global-pause (not (var-get global-pause)))
    (ok (var-get global-pause))
  )
)

;; @desc Toggles the pause state for a specific contract. Admin only.
;; @param target: The contract principal to toggle.
(define-public (toggle-contract-pause (target principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? paused-contracts target))))
      (map-set paused-contracts target (not current))
      (ok (not current))
    )
  )
)

;; @desc Toggles the isolation status of an external CSF protocol. Admin only.
;; @param protocol: The external protocol principal to toggle.
(define-public (toggle-isolation (protocol principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? isolated-protocols protocol))))
      (map-set isolated-protocols protocol (not current))
      (ok (not current))
    )
  )
)

;; @desc Transfers administrative privileges to a new principal. Admin only.
;; @param new-admin: The new administrator principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
