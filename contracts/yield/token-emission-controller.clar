;; token-emission-controller.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-data-var admin principal tx-sender)
(define-map emission-targets principal uint)

;; Principal Injection Pattern
(define-data-var coordinator-contract principal .token-system-coordinator)
(define-data-var cxvg-token-contract principal .cxvg-token)
(define-data-var self-launch-contract principal .self-launch-coordinator)

(define-constant MAX_EMISSION_PER_EPOCH u10000000000) ;; Hard safety cap
(define-data-var epoch-emission-total uint u0)

;; @desc Request a CXD mint for a specific recipient based on target weighting
(define-public (request-mint (amount uint) (recipient principal))
  (let (
    (weight (default-to u0 (map-get? emission-targets tx-sender)))
  )
    (asserts! (> weight u0) (err ERR_UNAUTHORIZED))
    (asserts! (<= (+ (var-get epoch-emission-total) amount) MAX_EMISSION_PER_EPOCH) (err u1003))

    (var-set epoch-emission-total (+ (var-get epoch-emission-total) amount))
    (print { event: "mint-requested", amount: amount, recipient: recipient })
    ;; MINT LOGIC WOULD CALL CXVG TOKEN HERE
    (ok true)
  )
)

;; @desc Initialize the controller with core system principals
(define-public (initialize (coordinator principal) (cxvg principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set coordinator-contract coordinator)
    (var-set cxvg-token-contract cxvg)
    (ok true)
  )
)

;; @desc Add or update an authorized emission target
(define-public (add-emission-target (target principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set emission-targets target weight)
    (ok true)
  )
)
