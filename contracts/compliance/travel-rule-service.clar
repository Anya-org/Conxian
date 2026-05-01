;; travel-rule-service.clar
;; Conxian Enterprise Standard: Travel Rule Service (IVMS101 Compliant Audit Trail)
;; Manages VASP registration and transaction logging for institutional compliance.

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u9000)
(define-constant ERR_INVALID_DATA u9001)

;; --- State ---

(define-data-var admin principal tx-sender)

;; Maps
(define-map registered-vasps (string-ascii 20) bool)
;; Map: TxRef -> Ivms101Hash
(define-map travel-rule-logs (buff 32) (buff 32))

;; --- Authorization ---

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; --- Public Functions ---

;; @desc Register a new Virtual Asset Service Provider (VASP)
;; @param vasp-id: 20-character identifier for the VASP
(define-public (register-vasp (vasp-id (string-ascii 20)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-set registered-vasps vasp-id true)
    (ok true)
  )
)

;; @desc Log travel rule data for a transaction
;; @param transaction-ref: The 32-byte transaction reference
;; @param ivms101-hash: The 32-byte hash of the IVMS101 data package
;; @param originator-vasp: The VASP ID of the sender
;; @param beneficiary-vasp: The VASP ID of the recipient
;; @param amount: The transaction amount
;; @param token: The token being transferred
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
      event: "travel-rule-log", tx-ref: transaction-ref, data-hash: ivms101-hash, originator: originator-vasp, beneficiary: beneficiary-vasp, amount: amount, token: token, timestamp: burn-block-height
    })
    (ok true)
  )
)

;; --- Read-only Functions ---

;; @desc Check if a VASP is authorized
;; @param vasp-id: The VASP identifier to check
(define-read-only (is-vasp-registered (vasp-id (string-ascii 20)))
  (default-to false (map-get? registered-vasps vasp-id))
)

;; @desc Retrieve the IVMS101 hash for a transaction reference
;; @param tx-ref: The transaction reference
(define-read-only (get-log (tx-ref (buff 32)))
  (map-get? travel-rule-logs tx-ref)
)

;; @desc Determine if a transaction amount requires travel rule reporting
;; @param amount: The transaction value
(define-read-only (requires-travel-rule (amount uint))
  (> amount u1000000)
)
