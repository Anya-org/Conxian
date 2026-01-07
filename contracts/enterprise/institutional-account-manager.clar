;; institutional-account-manager.clar
;; Conxian Enterprise Standard: Institutional Account Management (BaaS)
;; Adheres to Decentralized Modularity and Bitcoin Ethos

;; Constants
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_TIER (err u5001))

;; Maps
(define-map institutional-accounts
  principal
  {
    tier: (string-ascii 20),
    status: (string-ascii 20),
    limit-per-trade: uint,
    total-deployed: uint,
  }
)

;; @desc Registers an institutional account (BaaS)
(define-public (register-institution
    (institution principal)
    (tier (string-ascii 20))
    (limit uint)
  )
  (begin
    ;; Authorization check: Must be Enterprise Facade or Admin (via Access)
    (asserts!
      (or
        (is-eq contract-caller .enterprise-facade)
        (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1))
      )
      ERR_UNAUTHORIZED
    )
    (map-set institutional-accounts institution {
      tier: tier,
      status: "ACTIVE",
      limit-per-trade: limit,
      total-deployed: u0,
    })
    (print {
      event: "institution-registered",
      institution: institution,
      tier: tier,
      tenure-id: (contract-call? .block-utils get-current-tenure-id),
    })
    (ok true)
  )
)

;; @desc Validates if an institution can execute a large deployment
(define-read-only (is-deployment-authorized
    (institution principal)
    (amount uint)
  )
  (match (map-get? institutional-accounts institution)
    account
    (ok (<= amount (get limit-per-trade account)))
    (err u5002) ;; ERR_NOT_REGISTERED
  )
)

;; @desc Updates the limit for an institution
(define-public (set-limit
    (institution principal)
    (new-limit uint)
  )
  (begin
    (asserts!
      (or
        (is-eq contract-caller .enterprise-facade)
        (unwrap-panic (contract-call? .conxian-access has-role tx-sender u1))
      )
      ERR_UNAUTHORIZED
    )
    (match (map-get? institutional-accounts institution)
      account
      (begin
        (map-set institutional-accounts institution
          (merge account { limit-per-trade: new-limit })
        )
        (print {
          event: "limit-updated",
          institution: institution,
          new-limit: new-limit,
        })
        (ok true)
      )
      (err u5002) ;; ERR_NOT_REGISTERED
    )
  )
)

;; @desc Institutional Yield Boost Logic
(define-read-only (get-yield-multiplier (institution principal))
  (match (map-get? institutional-accounts institution)
    account
    (if (is-eq (get tier account) "PLATINUM")
      (ok u120)
      (ok u100)
    )
    ;; 1.2x or 1.0x
    (ok u100)
  )
)
