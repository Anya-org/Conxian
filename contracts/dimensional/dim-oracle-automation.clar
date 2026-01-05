;; dim-oracle-automation.clar
;; Conxian SAB: Dimensional Oracle Automation
;; Automates oracle price updates for dimensional assets

(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait oracle-trait .oracle-trait.oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u3002))
(define-constant UPDATE_INTERVAL u100) ;; 100 blocks

;; Data Vars
(define-data-var admin principal tx-sender)
(define-data-var last-update uint u0)

;; Oracle registry
(define-map oracle-registry
  (string-ascii 32)
  principal
)

;; Public functions
(define-public (register-oracle
    (asset (string-ascii 32))
    (oracle principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set oracle-registry asset oracle)
    (ok true)
  )
)

(define-public (update-oracle-prices)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set last-update block-height)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-oracle (asset (string-ascii 32)))
  (match (map-get? oracle-registry asset)
    oracle (ok oracle)
    (err u0)
  )
)

(define-read-only (should-update)
  (ok (> (- block-height (var-get last-update)) UPDATE_INTERVAL))
)