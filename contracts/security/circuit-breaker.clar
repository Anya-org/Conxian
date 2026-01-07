;; circuit-breaker.clar
;; Implements automated pause triggers for volatility and emergency stops

(use-trait roles-trait .core-traits.rbac-trait)

(define-constant ROLE_ADMIN u1)
(define-constant ROLE_KEEPER u2)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_FOUND (err u1001))
(define-constant ERR_ALREADY_PAUSED (err u1002))

;; Data Vars
(define-data-var contract-owner principal tx-sender)
(define-data-var rbac-contract principal .rbac)

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
    (contract-call? .rbac has-role tx-sender role)
  )
)

;; Admin Functions

(define-public (set-contract-paused
    (target principal)
    (paused bool)
  )
  (begin
    (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED) ;; u1 = Admin/Guardian role
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
    (asserts! (is-authorized u1) ERR_UNAUTHORIZED)
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

;; Trigger mechanism for automated systems (e.g., from an Oracle or Risk Manager)
(define-public (trigger-circuit-breaker (target principal))
  (begin
    ;; Only specific automated roles can trigger this
    (asserts! (is-authorized u2) ERR_UNAUTHORIZED) ;; u2 = Automation/Keeper role
    (map-set paused-contracts target true)
    (print {
      event: "circuit-breaker-triggered",
      target: target,
      triggered-by: tx-sender,
    })
    (ok true)
  )
)
