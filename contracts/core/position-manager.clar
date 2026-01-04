;; position-manager.clar
;; Manages the lifecycle of trading positions
;; Core Backend Contract - Accessed via Dimensional Engine Facade

(impl-trait .core-traits.position-manager-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_POSITION_NOT_FOUND (err u3000))

;; State - Engine Address
(define-data-var dimensional-engine principal .dimensional-engine)

(define-map positions
    uint
    {
        owner: principal,
        token: principal,
        size: uint,
        collateral: uint,
        leverage: uint,
        entry-price: uint,
        is-long: bool,
        open: bool,
    }
)

(define-data-var next-position-id uint u1)

;; Authorization: Only the Facade (Dimensional Engine) can call state-changing functions
(define-private (is-engine)
    (is-eq tx-sender (var-get dimensional-engine))
)

(define-public (set-dimensional-engine (engine principal))
    (begin
        (var-set dimensional-engine engine)
        (ok true)
    )
)

(define-public (open-position
        (user principal)
        (token principal)
        (amount uint)
        (leverage uint)
        (long bool)
    )
    (let ((pos-id (var-get next-position-id)))
        (asserts! (is-engine) ERR_NOT_AUTHORIZED)

        (map-set positions pos-id {
            owner: user,
            token: token,
            size: (* amount leverage),
            collateral: amount,
            leverage: leverage,
            entry-price: u0, ;; To be fetched from oracle via engine
            is-long: long,
            open: true,
        })
        (var-set next-position-id (+ pos-id u1))
        (ok pos-id)
    )
)

    (define-public (close-position
        (user principal)
        (position-id uint)
    )
    (begin
        (let ((pos (unwrap! (map-get? positions position-id) ERR_POSITION_NOT_FOUND)))
            (asserts! (is-eq (get owner pos) user) ERR_NOT_AUTHORIZED)
            (map-set positions position-id (merge pos { open: false }))
            (ok true)
        )
    )
)