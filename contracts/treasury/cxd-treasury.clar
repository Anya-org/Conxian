;; cxd-treasury.clar
;; "Intelligence-Led Adaptive Yield Engine (AYE)"
;; Consolidates revenue allocation, dynamic rebalancing, and accrued claims.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_SHARE u1001)
(define-constant ERR_POLICY_LOCKED u1002)
(define-constant ERR_OUT_OF_BOUNDS u1003)

;; Default allocation: 60/20/20 split
(define-constant TARGET_STAKING_SHARE u6000) ;; 60%
(define-constant TARGET_DEV_SHARE u2000)     ;; 20%
(define-constant TARGET_INSURANCE_SHARE u2000) ;; 20%

;; Current allocations (Basis points: 10000 = 100%)
(define-data-var staking-share uint u6000)
(define-data-var dev-fund-share uint u2000)
(define-data-var insurance-share uint u2000)

;; Accrued Claims for Stakers (Priority Claims)
(define-map accrued-claims principal uint)

;; Governance & Authorization
(define-data-var admin principal tx-sender)
(define-data-var agent-treasury principal .agent-treasury)
(define-data-var policy-locked bool false)

;; State Bounds (Set by Strategic Council/Admin)
(define-data-var min-staking-allowed uint u0)
(define-data-var max-insurance-allowed uint u10000)

;; --- Read Functions ---

(define-read-only (get-allocation-percentages)
  (ok {
    staking: (var-get staking-share),
    dev: (var-get dev-fund-share),
    insurance: (var-get insurance-share),
  })
)

(define-read-only (get-accrued-claim (token principal))
  (default-to u0 (map-get? accrued-claims token))
)

(define-read-only (get-bounds)
  {
    min-staking: (var-get min-staking-allowed),
    max-insurance: (var-get max-insurance-allowed)
  }
)

;; --- Public Functions ---

;; @desc Rebalance revenue flows. Called by Agent-Treasury or Admin.
(define-public (rebalance
    (staking uint)
    (dev uint)
    (insurance uint)
  )
  (begin
    (print { caller: contract-caller, admin: (var-get admin), agent: (var-get agent-treasury) })
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller (var-get agent-treasury))) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (asserts! (is-eq (+ staking (+ dev insurance)) u10000) (err ERR_INVALID_SHARE))

    ;; Check bounds
    (asserts! (>= staking (var-get min-staking-allowed)) (err ERR_OUT_OF_BOUNDS))
    (asserts! (<= insurance (var-get max-insurance-allowed)) (err ERR_OUT_OF_BOUNDS))

    (var-set staking-share staking)
    (var-set dev-fund-share dev)
    (var-set insurance-share insurance)

    (print {
      event: "rebalanced",
      staking: staking,
      dev: dev,
      insurance: insurance,
      timestamp: burn-block-height
    })
    (ok true)
  )
)

;; @desc Record a diverted claim. Called by revenue-distributor when staking-share < TARGET_STAKING_SHARE.
(define-public (record-diverted-claim (token principal) (amount uint))
  (begin
    ;; In a real scenario, this would be restricted to the revenue-distributor contract
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller .revenue-distributor)) (err ERR_UNAUTHORIZED))
    (let (
      (current (get-accrued-claim token))
    )
      (map-set accrued-claims token (+ current amount))
      (ok true)
    )
  )
)

;; @desc Backfill claims from treasury.
;; WARNING: This function only updates the registry.
;; The caller MUST ensure that the corresponding assets are transferred
;; to the staking vault from the insurance fund or operational treasury.
(define-public (backfill-claims (token principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (let (
      (current (get-accrued-claim token))
    )
      (asserts! (>= current amount) (err ERR_INVALID_SHARE))
      (map-set accrued-claims token (- current amount))

      (print { event: "claims-backfilled", token: token, amount: amount })
      (ok true)
    )
  )
)

;; --- Admin Functions ---

(define-public (set-bounds (min-staking uint) (max-insurance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set min-staking-allowed min-staking)
    (var-set max-insurance-allowed max-insurance)
    (ok true)
  )
)

(define-public (set-agent-treasury (new-agent principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set agent-treasury new-agent)
    (ok true)
  )
)

(define-public (lock-policy)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set policy-locked true)
    (ok true)
  )
)
