;; token-emission-controller.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_EMISSION_CAP u1003)
(define-data-var admin principal tx-sender)
(define-map emission-targets principal uint)

;; Principal Injection Pattern
(define-data-var coordinator-contract principal .token-system-coordinator)
(define-data-var cxvg-token-contract principal .cxvg-token)
(define-data-var self-launch-contract principal .self-launch-coordinator)

(define-constant MAX_EMISSION_PER_EPOCH u10000000000) ;; Hard safety cap
(define-data-var epoch-emission-total uint u0)
(define-constant EPOCH_LENGTH u144)
(define-data-var last-epoch-reset uint burn-block-height)

(define-private (sync-epoch-if-needed)
  (let (
    (current-height burn-block-height)
    (last-reset (var-get last-epoch-reset))
  )
    (begin
      (if (>= (- current-height last-reset) EPOCH_LENGTH)
        (begin
          (var-set epoch-emission-total u0)
          (var-set last-epoch-reset current-height)
          true
        )
        true
      )
      (ok true)
    )
  )
)

(define-public (request-mint (amount uint) (recipient principal))
  (let (
    (weight (default-to u0 (map-get? emission-targets tx-sender)))
  )
    (begin
      (asserts! (> weight u0) (err ERR_UNAUTHORIZED))
      (try! (sync-epoch-if-needed))

      (let ((new-total (+ (var-get epoch-emission-total) amount)))
        (asserts! (<= new-total MAX_EMISSION_PER_EPOCH) (err ERR_EMISSION_CAP))
        (try! (contract-call? (var-get cxvg-token-contract) mint amount recipient))
        (var-set epoch-emission-total new-total)
        (print { event: "mint-requested", amount: amount, recipient: recipient })
        (ok true)
      )
    )
  )
)

(define-public (sync-epoch)
  (sync-epoch-if-needed)
)

(define-public (initialize (coordinator principal) (cxvg principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set coordinator-contract coordinator)
    (var-set cxvg-token-contract cxvg)
    (ok true)
  )
)

(define-public (add-emission-target (target principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set emission-targets target weight)
    (ok true)
  )
)
