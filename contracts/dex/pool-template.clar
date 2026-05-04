;; pool-template.clar
;; Conxian Protocol: Template system for standardized pool creation

;; Dependencies

;; Constants
(define-constant ERR_INVALID_TEMPLATE u23001)
(define-constant ERR_TEMPLATE_NOT_FOUND u23002)
(define-constant ERR_INVALID_POOL_TYPE u23003)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u23004)
(define-constant ERR_POOL_ALREADY_EXISTS u23005)
(define-constant ERR_UNAUTHORIZED u23006)

;; Template parameters
(define-constant MIN_LIQUIDITY u1000000)
(define-constant MAX_LIQUIDITY u1000000000000)
(define-constant DEFAULT_FEE_TIER u1000)
(define-constant TEMPLATE_VERSION u1)

;; Data variables
(define-data-var template-active bool true)
(define-data-var total-templates uint u0)

;; Storage maps
(define-map pool-templates
  { template-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    pool-type: (string-ascii 32),
    min-liquidity: uint,
    max-liquidity: uint,
    default-fee: uint,
    active: bool,
    created-at: uint
  }
)

;; Read-only functions

;; @desc Get details of a pool template
(define-read-only (get-template (template-id uint))
  (map-get? pool-templates { template-id: template-id })
)

;; Public functions

;; @desc Create a new pool template
(define-public (create-template
    (name (string-ascii 64))
    (description (string-ascii 256))
    (pool-type (string-ascii 32))
    (min-liquidity uint)
    (max-liquidity uint)
    (default-fee uint)
  )
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    (asserts! (> (len name) u0) (err ERR_INVALID_TEMPLATE))

    (let ((template-id (+ (var-get total-templates) u1)))
      (map-set pool-templates { template-id: template-id } {
        name: name,
        description: description,
        pool-type: pool-type,
        min-liquidity: min-liquidity,
        max-liquidity: max-liquidity,
        default-fee: default-fee,
        active: true,
        created-at: burn-block-height
      })
      (var-set total-templates template-id)
      (print { event: "template-created", template-id: template-id, name: name })
      (ok template-id)
    )
  )
)

;; @desc Deactivate a pool template
(define-public (deactivate-template (template-id uint))
  (begin
    (asserts! (is-eq tx-sender (contract-call? .conxian-protocol get-protocol-admin)) (err ERR_UNAUTHORIZED))
    (match (map-get? pool-templates { template-id: template-id })
      template (begin
                (map-set pool-templates { template-id: template-id } (merge template { active: false }))
                (ok true)
              )
      (err ERR_TEMPLATE_NOT_FOUND)
    )
  )
)
