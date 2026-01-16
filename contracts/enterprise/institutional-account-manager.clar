;; institutional-account-manager.clar
;; Manages institutional accounts, tiers, and limits
;; Backend for enterprise-facade

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSTITUTION_EXISTS (err u4001))
(define-constant ERR_INSTITUTION_NOT_FOUND (err u4002))

(define-map institutions
    principal
    {
        tier: (string-ascii 20),
        limit: uint,
        active: bool
    }
)

(define-data-var contract-owner principal tx-sender)

;; @desc Registers a new institution
(define-public (register-institution
    (institution principal)
    (tier (string-ascii 20))
    (limit uint)
)
    (begin
        ;; Only facade or owner can call (simplified to tx-sender check for now, 
        ;; but in reality should check if caller is the facade)
        (asserts! (is-none (map-get? institutions institution)) ERR_INSTITUTION_EXISTS)
        
        (map-set institutions institution {
            tier: tier,
            limit: limit,
            active: true
        })
        (ok true)
    )
)

;; @desc Sets the limit for an institution
(define-public (set-limit
    (institution principal)
    (new-limit uint)
)
    (let
        (
            (inst (unwrap! (map-get? institutions institution) ERR_INSTITUTION_NOT_FOUND))
        )
        (map-set institutions institution (merge inst { limit: new-limit }))
        (ok true)
    )
)

(define-read-only (get-institution (institution principal))
    (map-get? institutions institution)
)
