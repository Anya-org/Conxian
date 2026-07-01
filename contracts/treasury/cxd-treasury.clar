;; cxd-treasury.clar
;; "Intelligence-Led Adaptive Yield Engine (AYE)" - Upgraded for CXIP-013
;; Consolidates revenue allocation dynamic rebalancing and accrued claims.
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_SHARE u1001)
(define-constant ERR_POLICY_LOCKED u1002)
(define-constant ERR_OUT_OF_BOUNDS u1003)

;; CXIP-013 Baseline (Sum = 10000)
(define-constant TARGET_TREASURY_SHARE u4500)
(define-constant TARGET_BOUNTY_SHARE u3000)
(define-constant TARGET_LP_SHARE u1500)
(define-constant TARGET_GRANT_SHARE u500)
(define-constant TARGET_BUYBACK_SHARE u500)

;; Current allocations (Basis points: 10000 = 100%)
(define-data-var treasury-share uint u4500)
(define-data-var bounty-share uint u3000)
(define-data-var lp-share uint u1500)
(define-data-var grant-share uint u500)
(define-data-var buyback-share uint u500)
(define-data-var insurance-share uint u0)

;; Accrued Claims for Stakers (Priority Claims)
(define-map accrued-claims principal uint)

;; Governance & Authorization
(define-data-var admin principal tx-sender)
(define-data-var agent-treasury-principal principal tx-sender)
(define-data-var revenue-distributor-principal principal tx-sender)
(define-data-var policy-locked bool false)

;; State Bounds
(define-data-var min-lp-allowed uint u0)
(define-data-var max-insurance-allowed uint u10000)

;; --- Read Functions ---

;; @desc Returns the current percentage weights for the 6-way split.
(define-read-only (get-allocation-percentages)
  (ok {
    treasury: (var-get treasury-share),
    bounty: (var-get bounty-share),
    lp: (var-get lp-share),
    grant: (var-get grant-share),
    buyback: (var-get buyback-share),
    insurance: (var-get insurance-share),
    staking: (var-get lp-share),
    dev: (var-get treasury-share)
  })
)

;; @desc Returns the total accrued claim for a specific token.
;; @param token: The token principal.
(define-read-only (get-accrued-claim (token principal))
  (default-to u0 (map-get? accrued-claims token))
)

;; --- Public Functions ---

;; @desc Updates the 6-way split percentages (must sum to 10000).
;; @param treasury: Treasury share in bps.
;; @param bounty: Bounty share in bps.
;; @param lp: LP share in bps.
;; @param grant: Grant share in bps.
;; @param buyback: Buyback share in bps.
;; @param insurance: Insurance share in bps.
(define-public (rebalance
    (treasury uint)
    (bounty uint)
    (lp uint)
    (grant uint)
    (buyback uint)
    (insurance uint)
  )
  (begin
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller (var-get agent-treasury-principal))) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get policy-locked)) (err ERR_POLICY_LOCKED))
    (asserts! (is-eq (+ treasury (+ bounty (+ lp (+ grant (+ buyback insurance))))) u10000) (err ERR_INVALID_SHARE))

    (var-set treasury-share treasury)
    (var-set bounty-share bounty)
    (var-set lp-share lp)
    (var-set grant-share grant)
    (var-set buyback-share buyback)
    (var-set insurance-share insurance)

    (print {
      event: "rebalanced",
      treasury: treasury,
      bounty: bounty,
      lp: lp,
      grant: grant,
      buyback: buyback,
      insurance: insurance,
      timestamp: block-height
    })
    (ok true)
  )
)

;; @desc Records claims diverted to the treasury for later allocation.
;; @param token: The token principal.
;; @param amount: The quantity diverted.
(define-public (record-diverted-claim (token principal) (amount uint))
  (begin
    (asserts! (or (is-eq contract-caller (var-get admin)) (is-eq contract-caller (var-get revenue-distributor-principal))) (err ERR_UNAUTHORIZED))
    (let (
      (current (get-accrued-claim token))
    )
      (map-set accrued-claims token (+ current amount))
      (ok true)
    )
  )
)

;; --- Admin Functions ---

;; @desc Initializes the treasury with a designated administrator.
;; @param new-admin: The administrator principal.
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; @desc Authorizes specific contracts to trigger rebalancing or record claims.
;; @param agent: The agent treasury principal.
;; @param distributor: The revenue distributor principal.
(define-public (set-authorized-principals (agent principal) (distributor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set agent-treasury-principal agent)
    (var-set revenue-distributor-principal distributor)
    (ok true)
  )
)

;; @desc Updates the administrative principal.
;; @param new-admin: The new administrator principal.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
