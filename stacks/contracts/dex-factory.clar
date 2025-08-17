;; BETA: Experimental DEX component - not audited; avoid production reliance.
;; DEX Factory - creates constant product pools and stores registry

(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_POOL_EXISTS u101)
(define-constant ERR_INVALID_FEE u102)
(define-constant ERR_SAME_TOKEN u103)
(define-constant ERR_NOT_FOUND u104)

(define-constant BPS_DENOM u10000)
(define-constant MAX_LP_FEE_BPS u100) ;; 1%

(define-data-var admin principal tx-sender)
(define-data-var pool-count uint u0)

;; token pair -> pool principal
(define-map pools { token-x: principal, token-y: principal } { pool: principal })

(define-read-only (get-pool (token-x principal) (token-y principal))
  (map-get? pools { token-x: token-x, token-y: token-y })
)

(define-read-only (get-pool-count) (var-get pool-count))

(define-public (set-admin (new principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new)
    (ok true)
  )
)

(define-public (create-pool (token-x principal) (token-y principal) (lp-fee-bps uint) (protocol-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (< lp-fee-bps MAX_LP_FEE_BPS) (err ERR_INVALID_FEE))
    (asserts! (< protocol-fee-bps lp-fee-bps) (err ERR_INVALID_FEE))
    (asserts! (not (is-eq token-x token-y)) (err ERR_SAME_TOKEN))

    ;; prevent duplicates in either order
    (asserts! (is-none (map-get? pools { token-x: token-x, token-y: token-y })) (err ERR_POOL_EXISTS))
    (asserts! (is-none (map-get? pools { token-x: token-y, token-y: token-x })) (err ERR_POOL_EXISTS))

    (let ((id (+ (var-get pool-count) u1)))
      (var-set pool-count id)
      ;; For now pool contract deployed separately; factory only records mapping.
      ;; Expect a deploy naming scheme: dex-pool-{id}.clar referencing this registry.
      (map-set pools { token-x: token-x, token-y: token-y } { pool: (as-contract tx-sender) })
      (print { event: "pool-created", id: id, token-x: token-x, token-y: token-y, lp-fee-bps: lp-fee-bps, protocol-fee-bps: protocol-fee-bps })
      (ok id)
    )
  )
)
