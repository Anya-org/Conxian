;; travel-rule-service.clar
;; Conxian Enterprise Standard: Travel Rule Service (IVMS101 Compliant Audit Trail)
;; Manages VASP registration and transaction logging.

;; Constants
(define-constant ERR_UNAUTHORIZED u9000)
(define-constant ERR_INVALID_DATA u9001)

;; Data Vars
(define-data-var admin principal tx-sender)

;; Maps
(define-map registered-vasps (string-ascii 20) bool)
;; Map: TxRef -> Ivms101Hash
(define-map travel-rule-logs (buff 32) (buff 32))

;; Authorization
(define-private (is-admin) (is-eq tx-sender (var-get admin)))

;; Public Functions

(define-public (register-vasp (vasp-id (string-ascii 20)))
    (begin
        (asserts! (is-admin) (err ERR_UNAUTHORIZED))
        (map-set registered-vasps vasp-id true)
        (ok true)
    )
)

(define-public (log-travel-rule-data 
        (transaction-ref (buff 32))
        (ivms101-hash (buff 32))
        (originator-vasp (string-ascii 20))
        (beneficiary-vasp (string-ascii 20))
        (amount uint)
        (token principal)
    )
    (begin
        (asserts! (or (is-vasp-registered originator-vasp) (is-admin)) (err ERR_UNAUTHORIZED))
        (map-set travel-rule-logs transaction-ref ivms101-hash)
        (print {
            event: "travel-rule-log",
            tx-ref: transaction-ref,
            data-hash: ivms101-hash,
            originator: originator-vasp,
            beneficiary: beneficiary-vasp,
            amount: amount,
            token: token,
            timestamp: burn-block-height
        })
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (is-vasp-registered (vasp-id (string-ascii 20)))
    (default-to false (map-get? registered-vasps vasp-id))
)

(define-read-only (get-log (tx-ref (buff 32)))
    (map-get? travel-rule-logs tx-ref)
)

(define-read-only (requires-travel-rule (amount uint))
    (> amount u1000000)
)
