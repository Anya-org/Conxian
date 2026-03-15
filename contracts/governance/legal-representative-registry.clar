;; legal-representative-registry.clar
;; Conxian Protocol Standard Contract

;; legal-representative-registry.clar
;; Registry of Clean-Hands/KYC'd Entities
;; Maps on-chain principals to off-chain legal identities (hash)

(define-constant ERR_UNAUTHORIZED u1000)

;; Data Storage
(define-map legal-registry
    principal
    {
        name-hash: (buff 32)
        jurisdiction: (string-ascii 64)
        active: bool
    }
)

(define-data-var registrar principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)

;; Read Only
(define-read-only (is-registered (entity principal))
    (match (map-get? legal-registry entity)
        data (get active data)
        false
    )
)

(define-read-only (get-entity-info (entity principal))
    (map-get? legal-registry entity)
)

;; Admin Functions

;; @desc Register representative
;; @returns (response bool uint)
(define-public (register-representative (entity principal) (name-hash (buff 32)) (jurisdiction (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender (var-get registrar)) (err ERR_UNAUTHORIZED))
        (map-set legal-registry entity {
            name-hash: name-hash
            jurisdiction: jurisdiction
            active: true
        })
        (print { event: "entity-registered" entity: entity jurisdiction: jurisdiction })
        (ok true)
    )
)


;; @desc Update status
;; @returns (response bool uint)
(define-public (update-status (entity principal) (active bool))
    (let (
        (profile (unwrap-panic (map-get? legal-registry entity)))
    )
        (asserts! (is-eq tx-sender (var-get registrar)) (err ERR_UNAUTHORIZED))
        (map-set legal-registry entity (merge profile { active: active }))
        (ok true)
    )
)
