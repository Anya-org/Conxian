;; legal-representative-registry.clar
;; Registry of Clean-Hands/KYC'd Entities
;; Maps on-chain principals to off-chain legal identities (hash)

(define-constant ERR_UNAUTHORIZED u1000)

;; Data Storage
(define-map legal-registry
    principal
    {
        name-hash: (buff 32),
        jurisdiction: (string-ascii 64),
        active: bool
    }
)

(define-data-var registrar principal tx-sender)

;; Read Only

;; @desc Checks if an entity is registered and active.
;; @param entity: The principal to check.
;; @return bool
(define-read-only (is-registered (entity principal))
    (match (map-get? legal-registry entity)
        data (get active data)
        false
    )
)

;; @desc Returns registry information for a given entity.
;; @param entity: The principal to query.
;; @return (optional {name-hash: (buff 32), jurisdiction: (string-ascii 64), active: bool})
(define-read-only (get-entity-info (entity principal))
    (map-get? legal-registry entity)
)

;; Admin Functions

;; @desc Registers a new representative in the legal registry.
;; @param entity: The principal of the representative.
;; @param name-hash: The hash of the legal name.
;; @param jurisdiction: The legal jurisdiction (e.g., "DE", "CH").
;; @return (response bool uint)
(define-public (register-representative (entity principal) (name-hash (buff 32)) (jurisdiction (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender (var-get registrar)) (err ERR_UNAUTHORIZED))
        (map-set legal-registry entity {
            name-hash: name-hash,
            jurisdiction: jurisdiction,
            active: true
        })
        (print { event: "entity-registered", entity: entity, jurisdiction: jurisdiction })
        (ok true)
    )
)


;; @desc Updates the active status of a registered representative.
;; @param entity: The principal of the representative.
;; @param active: The new active status.
;; @return (response bool uint)
(define-public (update-status (entity principal) (active bool))
    (let (
        (profile (unwrap-panic (map-get? legal-registry entity)))
    )
        (asserts! (is-eq tx-sender (var-get registrar)) (err ERR_UNAUTHORIZED))
        (map-set legal-registry entity (merge profile { active: active }))
        (ok true)
    )
)
