;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for CXIP-013 (5-way split)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-data-var admin principal tx-sender)
(define-constant TARGET_LP_SHARE u1500) ;; CXIP-013 Target

;; State
(define-data-var lp-vault principal .cxd-staking)
(define-data-var treasury-vault principal .operational-treasury)
(define-data-var bounty-vault principal .operational-treasury) ;; Defaults to op-treasury if not set
(define-data-var grant-vault principal .operational-treasury) ;; Defaults to op-treasury if not set
(define-data-var buyback-vault principal .operational-treasury) ;; Defaults to op-treasury if not set
(define-data-var insurance-vault principal .conxian-insurance-fund)

;; Public Functions

(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (let (
    (policy (unwrap-panic (contract-call? .cxd-treasury get-allocation-percentages)))
    (treasury-amt (/ (* amount (get treasury policy)) u10000))
    (bounty-amt   (/ (* amount (get bounty policy))   u10000))
    (lp-amt       (/ (* amount (get lp policy))       u10000))
    (grant-amt    (/ (* amount (get grant policy))    u10000))
    (buyback-amt  (/ (* amount (get buyback policy))  u10000))
    (ins-amt      (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (if (> treasury-amt u0) (try! (as-contract (contract-call? token transfer treasury-amt tx-sender (var-get treasury-vault) none))) true)
      (if (> bounty-amt u0)   (try! (as-contract (contract-call? token transfer bounty-amt   tx-sender (var-get bounty-vault)   none))) true)
      (if (> lp-amt u0)       (try! (as-contract (contract-call? token transfer lp-amt       tx-sender (var-get lp-vault)       none))) true)
      (if (> grant-amt u0)    (try! (as-contract (contract-call? token transfer grant-amt    tx-sender (var-get grant-vault)    none))) true)
      (if (> buyback-amt u0)  (try! (as-contract (contract-call? token transfer buyback-amt  tx-sender (var-get buyback-vault)  none))) true)
      (if (> ins-amt u0)      (try! (as-contract (contract-call? token transfer ins-amt      tx-sender (var-get insurance-vault) none))) true)

      ;; Record diverted claim if LP share is below target
      (if (< (get lp policy) TARGET_LP_SHARE)
        (let (
          (target-amt (/ (* amount TARGET_LP_SHARE) u10000))
          (diverted (- target-amt lp-amt))
        )
          (if (> diverted u0) (try! (contract-call? .cxd-treasury record-diverted-claim (contract-of token) diverted)) true)
        )
        true
      )
      (ok true)
    )
  )
)

(define-public (distribute-stx (amount uint))
  (let (
    (policy (unwrap-panic (contract-call? .cxd-treasury get-allocation-percentages)))
    (treasury-amt (/ (* amount (get treasury policy)) u10000))
    (bounty-amt   (/ (* amount (get bounty policy))   u10000))
    (lp-amt       (/ (* amount (get lp policy))       u10000))
    (grant-amt    (/ (* amount (get grant policy))    u10000))
    (buyback-amt  (/ (* amount (get buyback policy))  u10000))
    (ins-amt      (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (if (> treasury-amt u0) (try! (as-contract (stx-transfer? treasury-amt tx-sender (var-get treasury-vault)))) true)
      (if (> bounty-amt u0)   (try! (as-contract (stx-transfer? bounty-amt   tx-sender (var-get bounty-vault))))   true)
      (if (> lp-amt u0)       (try! (as-contract (stx-transfer? lp-amt       tx-sender (var-get lp-vault))))       true)
      (if (> grant-amt u0)    (try! (as-contract (stx-transfer? grant-amt    tx-sender (var-get grant-vault))))    true)
      (if (> buyback-amt u0)  (try! (as-contract (stx-transfer? buyback-amt  tx-sender (var-get buyback-vault))))  true)
      (if (> ins-amt u0)      (try! (as-contract (stx-transfer? ins-amt      tx-sender (var-get insurance-vault)))) true)

      ;; Record diverted claim if LP share is below target
      (if (< (get lp policy) TARGET_LP_SHARE)
        (let (
          (target-amt (/ (* amount TARGET_LP_SHARE) u10000))
          (diverted (- target-amt lp-amt))
        )
          (if (> diverted u0) (try! (contract-call? .cxd-treasury record-diverted-claim .cxd-token diverted)) true)
        )
        true
      )
      (ok true)
    )
  )
)

;; Admin Functions

(define-public (set-destinations (new-lp principal) (new-treasury principal) (new-bounty principal) (new-grant principal) (new-buyback principal) (new-ins principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set lp-vault new-lp)
    (var-set treasury-vault new-treasury)
    (var-set bounty-vault new-bounty)
    (var-set grant-vault new-grant)
    (var-set buyback-vault new-buyback)
    (var-set insurance-vault new-ins)
    (ok true)
  )
)

;; Read-only
(define-read-only (get-destinations)
  {
    lp: (var-get lp-vault),
    treasury: (var-get treasury-vault),
    bounty: (var-get bounty-vault),
    grant: (var-get grant-vault),
    buyback: (var-get buyback-vault),
    insurance: (var-get insurance-vault)
  }
)

;; Compatibility Alias
(define-read-only (get-operational-treasury)
  (var-get treasury-vault)
)
