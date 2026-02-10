;; circuit-breaker.clar
;; Implements automated pause triggers for volatility and emergency stops

(use-trait roles-trait .core-traits.conxian-access-trait)
(impl-trait .security-monitoring.circuit-breaker-trait)

(define-constant ROLE_ADMIN u1)
(define-constant ROLE_KEEPER u2)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NOT_FOUND u1001)
(define-constant ERR_ALREADY_PAUSED u1002)

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var rbac-contract principal .conxian-access)

;; Map of paused contracts
(define-map paused-contracts
  principal
  bool
)

;; Map of specific function pauses: { contract, function-name } -> bool
(define-map paused-functions
  {
    contract: principal,
    func: (string-ascii 64),
  }
  bool
)

;; Authorization check
(define-private (is-authorized (role uint))
  (if (is-eq tx-sender (var-get contract-owner))
    true
    (is-eq (ok true) (contract-call? .conxian-access has-role tx-sender role))
  )
)

;; Admin Functions

(define-public (set-contract-paused
    (target principal)
    (paused bool)
  )
  (begin
    (asserts! (is-authorized ROLE_ADMIN) (err ERR_UNAUTHORIZED)) ;; u1 = Admin/Guardian role
    (map-set paused-contracts target paused)
    (ok true)
  )
)

(define-public (set-function-paused
    (target principal)
    (func-name (string-ascii 64))
    (paused bool)
  )
  (begin
    (asserts! (is-authorized u1) (err ERR_UNAUTHORIZED))
    (map-set paused-functions {
      contract: target,
      func: func-name,
    }
      paused
    )
    (ok true)
  )
)

;; Read-Only Checks

(define-read-only (is-contract-paused (target principal))
  (default-to false (map-get? paused-contracts target))
)

(define-read-only (is-function-paused
    (target principal)
    (func-name (string-ascii 64))
  )
  (or
    (is-contract-paused target)
    (default-to false
      (map-get? paused-functions {
        contract: target,
        func: func-name,
      })
    )
  )
)

;; Trait Implementation

(define-read-only (check-breaker) (ok (is-contract-paused (as-contract tx-sender))))
(define-read-only (is-circuit-breaker-active)
  (ok (is-contract-paused (as-contract tx-sender)))
)

(define-public (trigger-circuit-breaker)
  (begin
    (asserts! (is-authorized ROLE_KEEPER) (err ERR_UNAUTHORIZED))
    (map-set paused-contracts (as-contract tx-sender) true)
    (ok true)
  )
)

(define-public (reset-circuit-breaker)
  (begin
    (asserts! (is-authorized ROLE_ADMIN) (err ERR_UNAUTHORIZED))
    (map-set paused-contracts (as-contract tx-sender) false)
    (ok true)
  )
)

(define-public (get-circuit-breaker-status)
  (ok {
    active: (is-contract-paused (as-contract tx-sender)),
    last-triggered: u0, ;; To be implemented
    trigger-count: u0   ;; To be implemented
  })
)

;; Trigger mechanism for automated systems (e.g., from an Oracle or Risk Manager)
(define-public (trigger-circuit-breaker-for (target principal))
  (begin
    ;; Only specific automated roles can trigger this
    (asserts! (is-authorized u2) (err ERR_UNAUTHORIZED)) ;; u2 = Automation/Keeper role
    (map-set paused-contracts target true)
    (print {
      event: "circuit-breaker-triggered",
      target: target,
      triggered-by: tx-sender,
    })
    (ok true)
  )
)
