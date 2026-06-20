;; finance-metrics.clar
;; Conxian Protocol: Core Financial Telemetry and Health Metrics
;; Version: v1.2.0
;; Includes Unified Theory variables (C_R, V_X, A_S)

(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var total-value-locked uint u0)
(define-data-var global-collateral-ratio uint u0)
(define-data-var admin principal tx-sender)

;; Conxian Unified Theory Variables
(define-data-var cost-of-reproduction uint u0)
(define-data-var execution-velocity uint u0)
(define-data-var system-autonomy uint u0)

(define-read-only (get-tvl) (ok (var-get total-value-locked)))
(define-read-only (get-protocol-tvl) (ok (var-get total-value-locked)))
(define-read-only (get-gcr) (ok (var-get global-collateral-ratio)))

;; Unified Theory Getters
(define-read-only (get-cost-of-reproduction) (ok (var-get cost-of-reproduction)))
(define-read-only (get-execution-velocity) (ok (var-get execution-velocity)))
(define-read-only (get-system-autonomy) (ok (var-get system-autonomy)))

(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    version: "v1.2.0-Apex",
    tvl: (var-get total-value-locked),
    gcr: (var-get global-collateral-ratio),
    theory: {
      c-r: (var-get cost-of-reproduction),
      v-x: (var-get execution-velocity),
      a-s: (var-get system-autonomy)
    }
  })
)

(define-public (update-metrics (new-tvl uint) (new-gcr uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set total-value-locked new-tvl)
    (var-set global-collateral-ratio new-gcr)
    (ok true)
  )
)

(define-public (update-theory-metrics (new-c-r uint) (new-v-x uint) (new-a-s uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set cost-of-reproduction new-c-r)
    (var-set execution-velocity new-v-x)
    (var-set system-autonomy new-a-s)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
