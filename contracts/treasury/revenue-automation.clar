;; revenue-automation.clar
;; Enforces non-negotiable protocol fee extraction (100 bps)
;; Aligned with CON-60 and Apex BME (v1.1.0)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant PROTOCOL_FEE_BPS u100) ;; 100 bps = 1%

;; --- State ---
(define-data-var admin principal tx-sender)

;; --- Public Functions ---

;; @desc Calculate and collect protocol fee for a given amount
(define-public (collect-revenue (token <sip-010-ft-trait>) (amount uint) (payer principal))
  (let (
    (fee (/ (* amount PROTOCOL_FEE_BPS) u10000))
  )
    (begin
      (asserts! (> fee u0) (ok u0))
      ;; Transfer fee to revenue-distributor
      (try! (contract-call? token transfer fee payer .revenue-distributor none))
      (print { event: "revenue-collected", token: (contract-of token), amount: fee, payer: payer })
      (ok fee)
    )
  )
)

;; --- Admin ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
