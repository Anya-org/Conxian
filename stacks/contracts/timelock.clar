;; Timelock governance for Vault admin actions

(use-trait sip010 .sip-010-trait.sip-010-trait)
;; Trait alias for vault admin surface enabling dynamic target via parameter
(use-trait vadmin .vault-admin-trait.vault-admin-trait)

;; Queue set-treasury
(define-public (queue-set-treasury (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-treasury { id: id } { p: p, eta: eta })
      (print { event: "queue-set-treasury", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Queue set-fee-split-bps
(define-public (queue-set-fee-split-bps (bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-split { id: id } { bps: bps, eta: eta })
      (print { event: "queue-set-fee-split-bps", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Queue withdraw-treasury
(define-public (queue-withdraw-treasury (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-wtreas { id: id } { to: to, amount: amount, eta: eta })
      (print { event: "queue-withdraw-treasury", id: id, eta: eta })
      (ok id)
    )
  )
)

(define-data-var admin principal tx-sender)
(define-data-var min-delay uint u20) ;; blocks delay before execution
(define-data-var next-id uint u0)

(define-map q-fees { id: uint } { deposit-bps: uint, withdraw-bps: uint, eta: uint })
(define-map q-paused { id: uint } { p: bool, eta: uint })
(define-map q-gcap { id: uint } { cap: uint, eta: uint })
(define-map q-ucap { id: uint } { cap: uint, eta: uint })
(define-map q-rlim { id: uint } { enabled: bool, cap: uint, eta: uint })
;; Additional admin actions
;; Store token principal in the queue (cannot store trait references)
(define-map q-ctok { id: uint } { token: principal, eta: uint })
;; token stored as principal to avoid storing trait references
(define-map q-wres { id: uint } { to: principal, amount: uint, eta: uint })
(define-map q-autofees { id: uint } { enabled: bool, util-high: uint, util-low: uint, min-fee: uint, max-fee: uint, eta: uint })
;; Treasury-related admin actions
(define-map q-treasury { id: uint } { p: principal, eta: uint })
(define-map q-split { id: uint } { bps: uint, eta: uint })
(define-map q-wtreas { id: uint } { to: principal, amount: uint, eta: uint })

(define-read-only (get-admin) (ok (var-get admin)))
(define-read-only (get-min-delay) (var-get min-delay))
(define-read-only (get-next-id) (var-get next-id))

(define-public (set-admin (new principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin new)
    (print { event: "tl-set-admin", caller: tx-sender, new: new })
    (ok true)
  )
)

(define-public (set-min-delay (d uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set min-delay d)
    (print { event: "tl-set-min-delay", caller: tx-sender, d: d })
    (ok true)
  )
)

(define-private (next)
  (let ((id (var-get next-id)))
    (var-set next-id (+ id u1))
    id
  )
)

;; Queue actions
(define-public (queue-set-fees (deposit-bps uint) (withdraw-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next))
          (eta (+ block-height (var-get min-delay))))
      (map-set q-fees { id: id } { deposit-bps: deposit-bps, withdraw-bps: withdraw-bps, eta: eta })
      (print { event: "queue-set-fees", id: id, eta: eta })
      (ok id)
    )
  )
)

(define-public (queue-set-paused (p bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-paused { id: id } { p: p, eta: eta })
      (print { event: "queue-set-paused", id: id, eta: eta })
      (ok id)
    )
  )
)

(define-public (queue-set-global-cap (cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-gcap { id: id } { cap: cap, eta: eta })
      (print { event: "queue-set-global-cap", id: id, eta: eta })
      (ok id)
    )
  )
)

(define-public (queue-set-user-cap (cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-ucap { id: id } { cap: cap, eta: eta })
      (print { event: "queue-set-user-cap", id: id, eta: eta })
      (ok id)
    )
  )
)

(define-public (queue-set-rate-limit (enabled bool) (cap-per-block uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-rlim { id: id } { enabled: enabled, cap: cap-per-block, eta: eta })
      (print { event: "queue-set-rate-limit", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Queue set-token (bind vault to a new SIP-010 contract principal)
(define-public (queue-set-token (c principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-ctok { id: id } { token: c, eta: eta })
      (print { event: "queue-set-token", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Queue withdraw-reserve
(define-public (queue-withdraw-reserve (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-wres { id: id } { to: to, amount: amount, eta: eta })
      (print { event: "queue-withdraw-reserve", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Queue set-autofees
(define-public (queue-set-auto-fees (enabled bool) (util-high uint) (util-low uint) (min-fee uint) (max-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((id (next)) (eta (+ block-height (var-get min-delay))))
      (map-set q-autofees { id: id } { enabled: enabled, util-high: util-high, util-low: util-low, min-fee: min-fee, max-fee: max-fee, eta: eta })
      (print { event: "queue-set-auto-fees", id: id, eta: eta })
      (ok id)
    )
  )
)

;; Execute actions (requires timelock to be the admin of .vault)
(define-public (execute-set-fees (id uint))
  (let ((item (map-get? q-fees { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-fees { id: id })
        ;; (as-contract (contract-call? .vault set-fees (get deposit-bps i) (get withdraw-bps i)))
        (ok true) ;; Placeholder
      )
      (err u102)
    )
  )
)

(define-public (execute-set-paused (id uint))
  (let ((item (map-get? q-paused { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-paused { id: id })
  ;; Execute directly against the vault; timelock is the admin by default
  (as-contract (contract-call? .vault set-paused (get p i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-global-cap (id uint))
  (let ((item (map-get? q-gcap { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-gcap { id: id })
  ;; (as-contract (contract-call? .vault set-global-cap (get cap i))) ;; Temporarily disabled
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-set-user-cap (id uint))
  (let ((item (map-get? q-ucap { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-ucap { id: id })
  ;; (as-contract (contract-call? .vault set-user-cap (get cap i))) ;; Temporarily disabled
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-set-rate-limit (id uint))
  (let ((item (map-get? q-rlim { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-rlim { id: id })
  ;; (as-contract (contract-call? .vault set-rate-limit (get enabled i) (get cap i)))
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-set-token (id uint))
  (let ((item (map-get? q-ctok { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-ctok { id: id })
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-withdraw-reserve (id uint))
  (let ((item (map-get? q-wres { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-wres { id: id })
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-set-treasury (id uint))
  (let ((item (map-get? q-treasury { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-treasury { id: id })
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-set-fee-split-bps (id uint))
  (let ((item (map-get? q-split { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-split { id: id })
  (ok true)
      )
      (err u102)
    )
  )
)

(define-public (execute-withdraw-treasury (id uint))
  (let ((item (map-get? q-wtreas { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-wtreas { id: id })
  (ok true)
      )
      (err u102)
    )
  )
)
(define-public (execute-set-fees-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-fees { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-fees { id: id })
        (as-contract (contract-call? v set-fees (get deposit-bps i) (get withdraw-bps i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-paused-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-paused { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-paused { id: id })
        (as-contract (contract-call? v set-paused (get p i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-global-cap-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-gcap { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-gcap { id: id })
        (as-contract (contract-call? v set-global-cap (get cap i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-user-cap-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-ucap { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-ucap { id: id })
        (as-contract (contract-call? v set-user-cap (get cap i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-rate-limit-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-rlim { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-rlim { id: id })
        (as-contract (contract-call? v set-rate-limit (get enabled i) (get cap i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-token-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-ctok { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-ctok { id: id })
        (as-contract (contract-call? v set-token (get token i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-withdraw-reserve-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-wres { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-wres { id: id })
        (as-contract (contract-call? v withdraw-reserve (get to i) (get amount i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-treasury-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-treasury { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-treasury { id: id })
        (as-contract (contract-call? v set-treasury (get p i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-fee-split-bps-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-split { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-split { id: id })
        (as-contract (contract-call? v set-fee-split-bps (get bps i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-withdraw-treasury-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-wtreas { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-wtreas { id: id })
        (as-contract (contract-call? v withdraw-treasury (get to i) (get amount i)))
      )
      (err u102)
    )
  )
)

(define-public (execute-set-auto-fees-v2 (id uint) (v <vadmin>))
  (let ((item (map-get? q-autofees { id: id })))
    (match item i
      (begin
        (asserts! (>= block-height (get eta i)) (err u101))
        (map-delete q-autofees { id: id })
        (unwrap! (as-contract (contract-call? v set-auto-fees-enabled (get enabled i))) (err u103))
        (unwrap! (as-contract (contract-call? v set-util-thresholds (get util-high i) (get util-low i))) (err u103))
        (unwrap! (as-contract (contract-call? v set-fee-bounds (get min-fee i) (get max-fee i))) (err u103))
        (ok true)
      )
      (err u102)
    )
  )
)

;; Errors
;; u100: unauthorized
;; u101: timelock-not-ready
;; u102: not-found
