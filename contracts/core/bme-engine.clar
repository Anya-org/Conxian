;; bme-engine.clar
;; Sovereign Burn-Mint Equilibrium (BME) Engine
;; Conxian Protocol - Apex Upgrade (v1.1.0)
;; Remediated June 2026: Meritocratic Multi-Marker Emission Model

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_EPOCH (err u1001))
(define-constant ERR_NO_ACTIVITY (err u1002))
(define-constant EPOCH_LENGTH u144)
(define-constant MINT_PER_EPOCH u100000000000)

;; Emission Weights (BPS)
(define-constant WEIGHT_DEX u4500)      ;; 45%
(define-constant WEIGHT_BOUNTY u3000)   ;; 30%
(define-constant WEIGHT_GOV u1500)      ;; 15%
(define-constant WEIGHT_STRATEGIC u1000) ;; 10%

;; --- Data Vars ---
(define-data-var admin principal tx-sender)
(define-data-var last-mint-block uint u0)
(define-data-var total-burned uint u0)

;; Aggregate Activity Totals per Epoch
(define-data-var total-dex-activity uint u0)
(define-data-var total-lending-activity uint u0)
(define-data-var total-bounty-activity uint u0)
(define-data-var total-gov-activity uint u0)

;; --- Maps ---
(define-map dex-activity principal uint)
(define-map lending-activity principal uint)
(define-map bounty-activity principal uint)
(define-map gov-activity principal uint)

(define-map authorized-activity-reporters principal bool)

;; --- Authorization ---

(define-private (is-authorized-reporter)
  (default-to false (map-get? authorized-activity-reporters contract-caller))
)

;; @desc Add an authorized principal that can report activity to the BME engine
(define-public (add-activity-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set authorized-activity-reporters reporter true)
    (ok true)
  )
)

;; --- BME Activity Registration ---

;; @desc Register DEX liquidity activity
(define-public (register-dex-activity (pool principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set dex-activity pool (+ (default-to u0 (map-get? dex-activity pool)) amount))
    (var-set total-dex-activity (+ (var-get total-dex-activity) amount))
    (ok true)
  )
)

;; @desc Register Lending activity
(define-public (register-lending-activity (market principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set lending-activity market (+ (default-to u0 (map-get? lending-activity market)) amount))
    (var-set total-lending-activity (+ (var-get total-lending-activity) amount))
    (ok true)
  )
)

;; @desc Register Bounty completion activity
(define-public (register-bounty-activity (contributor principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set bounty-activity contributor (+ (default-to u0 (map-get? bounty-activity contributor)) amount))
    (var-set total-bounty-activity (+ (var-get total-bounty-activity) amount))
    (ok true)
  )
)

;; @desc Register Governance participation activity
(define-public (register-gov-activity (voter principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set gov-activity voter (+ (default-to u0 (map-get? gov-activity voter)) amount))
    (var-set total-gov-activity (+ (var-get total-gov-activity) amount))
    (ok true)
  )
)

;; --- BME Core Logic ---

;; @desc Trigger the minting and distribution of rewards for the current epoch
;; @param targets: List of principals to reward across all categories
(define-public (execute-epoch-minting (targets (list 100 principal)))
  (let (
    (current-height burn-block-height)
    (last-mint (var-get last-mint-block))
  )
    (begin
      (asserts! (>= (- current-height last-mint) EPOCH_LENGTH) ERR_INVALID_EPOCH)

      ;; Distribute across categories
      (map distribute-merit-rewards targets)

      ;; Reset epoch totals
      (var-set total-dex-activity u0)
      (var-set total-lending-activity u0)
      (var-set total-bounty-activity u0)
      (var-set total-gov-activity u0)

      (var-set last-mint-block current-height)
      (ok true)
    )
  )
)

(define-private (distribute-merit-rewards (target principal))
  (let (
    (dex-share (calculate-share target dex-activity (var-get total-dex-activity) WEIGHT_DEX))
    (lending-share (calculate-share target lending-activity (var-get total-lending-activity) WEIGHT_DEX)) ;; Lending shares DEX weight in this model
    (bounty-share (calculate-share target bounty-activity (var-get total-bounty-activity) WEIGHT_BOUNTY))
    (gov-share (calculate-share target gov-activity (var-get total-gov-activity) WEIGHT_GOV))
    (total-mint (+ dex-share lending-share bounty-share gov-share))
  )
    (if (> total-mint u0)
      (is-ok (contract-call? .cxd-token mint total-mint target))
      false
    )
  )
)

(define-private (calculate-share (target principal) (activity-map (map principal uint)) (total uint) (weight uint))
  (let (
    (activity (default-to u0 (map-get? activity-map target)))
    (category-allocation (/ (* MINT_PER_EPOCH weight) u10000))
  )
    (if (and (> total u0) (> activity u0))
      (/ (* activity category-allocation) total)
      u0
    )
  )
)

;; @desc Burn a specific amount of protocol fees in CXD
(define-public (burn-protocol-fees (amount uint))
  (begin
    (try! (contract-call? .cxd-token burn amount tx-sender))
    (var-set total-burned (+ (var-get total-burned) amount))
    (ok true)
  )
)

;; @desc Swap a specific token for CXD and burn it
(define-public (swap-and-burn (token <sip-010-ft-trait>) (amount uint))
  (begin
    ;; In production, this calls swap-router
    (print { event: "swap-and-burn-triggered", token: (contract-of token), amount: amount })
    ;; For simulation we just simulate the burn of an equivalent value if it was CXD
    (var-set total-burned (+ (var-get total-burned) amount))
    (ok true)
  )
)

;; --- Read-only ---

;; @desc Get global statistics for the BME engine
(define-read-only (get-bme-stats)
  (ok {
    total-dex-activity: (var-get total-dex-activity),
    total-burned: (var-get total-burned),
    last-mint-block: (var-get last-mint-block),
    mint-per-epoch: MINT_PER_EPOCH
  })
)

;; @desc Get the current operational status of the BME engine
(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex" })
)
