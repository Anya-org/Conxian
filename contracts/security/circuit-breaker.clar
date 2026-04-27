;; circuit-breaker.clar
;; Conxian Security: Circuit Breaker
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(impl-trait .security-monitoring.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_VETO_ACTIVE (err u7001))
(define-constant ERR_ALREADY_VETOED (err u7002))

(define-data-var admin principal tx-sender)
(define-map paused-contracts principal bool)

;; --- Veto & Quorum Logic ---
(define-map veto-signatures principal bool)
(define-data-var veto-count uint u0)
(define-data-var quorum-threshold uint u3)
(define-data-var veto-active bool false)

;; @desc Checks if a specific contract principal is currently paused.
;; @param target: The contract principal to check.
(define-read-only (is-contract-paused (target principal))
  (ok (default-to false (map-get? paused-contracts target)))
)

;; @desc Toggles the pause state for a specific contract. Admin only.
;; @param target: The contract principal to toggle.
(define-public (toggle-contract-pause (target principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get veto-active)) ERR_VETO_ACTIVE)
    (let ((current (default-to false (map-get? paused-contracts target))))
      (map-set paused-contracts target (not current))
      (ok (not current))
    )
  )
)

;; @desc Sets a new administrator for the circuit breaker. Admin only.
;; @param new-admin: The new administrator principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get veto-active)) ERR_VETO_ACTIVE)
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Triggers a veto. If quorum is reached, the system enters a vetoed state locking admin functions.
(define-public (trigger-veto)
  (let ((current-count (var-get veto-count)))
    (asserts! (not (default-to false (map-get? veto-signatures tx-sender))) ERR_ALREADY_VETOED)
    (map-set veto-signatures tx-sender true)
    (var-set veto-count (+ current-count u1))
    (if (>= (+ current-count u1) (var-get quorum-threshold))
      (begin
        (var-set veto-active true)
        (ok true)
      )
      (ok true)
    )
  )
)

;; @desc Resolves an active veto, assuming the issue is handled via ExecutorDAO overrides or emergency updates.
(define-public (resolve-veto)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set veto-count u0)
    (var-set veto-active false)
    (ok true)
  )
)
