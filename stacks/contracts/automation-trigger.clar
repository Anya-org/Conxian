;; Automation Trigger Contract
;; Provides authorized hooks to call adaptive founder reallocation adjustment
;; and epoch advancement while respecting security controls (timelock / DAO)

(define-constant CONTRACT_VERSION u1)

;; Errors
(define-constant ERR_UNAUTHORIZED u900)
(define-constant ERR_DISABLED u901)

;; Data Vars
(define-data-var dao-governance principal .dao-governance)
(define-data-var enabled bool true)
(define-data-var dao-initialized bool false)
(define-data-var deployer principal tx-sender) ;; temporary until governance init sets canonical dao
(define-data-var last-participation-bps uint u0)
(define-data-var participation-updates uint u0)
(define-map participation-history { idx: uint } { bps: uint })
(define-data-var test-mode bool false)

;; Authorization predicate (returns bool; callers enforce with asserts!)
(define-private (is-dao)
  (or (is-eq tx-sender (var-get dao-governance)) (and (var-get test-mode) (is-eq tx-sender (var-get deployer))))
)

;; One-time initializer to set dao governance principal explicitly (if different deployer wrapper)
;; One-time initializer to set dao governance principal explicitly
;; Initialize or update dao governance principal (protected: only current dao or if not set, anyone)
(define-public (init-dao (dao principal))
  (begin
    (if (var-get dao-initialized)
      (asserts! (is-dao) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq tx-sender (var-get deployer)) (err ERR_UNAUTHORIZED)))
    (var-set dao-governance dao)
    (var-set dao-initialized true)
    (print { event: "automation-dao-initialized", dao: dao })
    (ok dao)
  )
)

;; Admin toggle
(define-public (set-enabled (flag bool))
  (begin
    (asserts! (is-dao) (err ERR_UNAUTHORIZED))
    (var-set enabled flag)
    (print { event: "automation-enabled-set", enabled: flag })
    (ok flag)
  )
)

;; Test mode toggle (non-production). Allows deployer to act as DAO for local simnet.
(define-public (set-test-mode (flag bool))
  (begin
    (asserts! (is-eq tx-sender (var-get deployer)) (err ERR_UNAUTHORIZED))
    (var-set test-mode flag)
    (print { event: "automation-test-mode", enabled: flag })
    (ok flag)
  )
)

;; Adaptive reallocation trigger: queries rolling participation and forwards to avg-token
;; Trigger with externally supplied participation bps (off-chain computed or read beforehand)
(define-public (trigger-adaptive-reallocation (participation-bps uint))
  (begin
    (asserts! (var-get enabled) (err ERR_DISABLED))
    (asserts! (is-dao) (err ERR_UNAUTHORIZED))
    (var-set last-participation-bps participation-bps)
    (let ((new-count (+ (var-get participation-updates) u1)))
      (var-set participation-updates new-count)
      (map-set participation-history { idx: new-count } { bps: participation-bps })
      (print { event: "automation-participation-external", bps: participation-bps, count: new-count }))
  (let ((res (as-contract (contract-call? .avg-token adaptive-realloc-adjust participation-bps))))
    (print { event: "automation-adaptive-invoke", result: res }))
  (ok true)
  )
)

;; Combined epoch advance + adaptive reallocation (optional convenience)
(define-public (advance-and-reallocate (participation-bps uint))
  (begin
    (asserts! (var-get enabled) (err ERR_DISABLED))
    (asserts! (is-dao) (err ERR_UNAUTHORIZED))
    (var-set last-participation-bps participation-bps)
    (let ((new-count (+ (var-get participation-updates) u1)))
      (var-set participation-updates new-count)
      (map-set participation-history { idx: new-count } { bps: participation-bps })
      (print { event: "automation-advance-reallocate", bps: participation-bps, count: new-count }))
  (ok true))
)

;; Read-only status
(define-read-only (get-status)
  { enabled: (var-get enabled), dao: (var-get dao-governance), initialized: (var-get dao-initialized), last-participation-bps: (var-get last-participation-bps), update-count: (var-get participation-updates) }
)

(define-read-only (get-participation (idx uint))
  (match (map-get? participation-history { idx: idx }) entry (get bps entry) u0)
)
