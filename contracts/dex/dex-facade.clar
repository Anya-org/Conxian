;; dex-facade.clar
;; Centralized Facade for DEX Operations
;; Standardizes interactions with pools and factories

;; Traits
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)

;; Storage
(define-map authorized-pools principal bool)

;; Authorization
(define-private (is-admin)
  (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin))
)

;; Public Functions

(define-public (add-authorized-pool (pool principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-set authorized-pools pool true)
    (ok true)
  )
)

(define-public (remove-authorized-pool (pool principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-delete authorized-pools pool)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Checks if a pool is authorized and exists in the system
;; @param pool principal - The pool contract address
;; @returns bool
(define-read-only (pool-exists (pool principal))
  (default-to false (map-get? authorized-pools pool))
)

;; @desc Gets pool data via factory
(define-read-only (get-pool-data (token0 principal) (token1 principal) (type uint))
  (contract-call? .dex-factory get-pool token0 token1 type)
)

(define-public (initialize)
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    ;; Initialization logic if needed
    (ok true)
  )
)
