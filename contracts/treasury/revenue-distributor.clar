;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for CXIP-013 (5-way split)

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant TARGET_LP_SHARE u1500) ;; CXIP-013 Target

;; State
(define-data-var lp-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var treasury-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var bounty-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Defaults to op-treasury if not set
(define-data-var grant-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Defaults to op-treasury if not set
(define-data-var buyback-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) ;; Defaults to op-treasury if not set
(define-data-var insurance-vault principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Principal Injection
(define-data-var cxd-treasury-principal principal .cxd-treasury)
(define-data-var cxd-token-principal principal .cxd-token)

;; Public Functions

(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (let (
    (policy (unwrap! (contract-call? .cxd-treasury get-allocation-percentages) (err ERR_UNAUTHORIZED)))
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
      (if (> buyback-amt  u0) (try! (as-contract (contract-call? token transfer buyback-amt  tx-sender (var-get buyback-vault)  none))) true)
      (if (> ins-amt      u0) (try! (as-contract (contract-call? token transfer ins-amt      tx-sender (var-get insurance-vault) none))) true)

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
    (policy (unwrap! (contract-call? .cxd-treasury get-allocation-percentages) (err ERR_UNAUTHORIZED)))
    (treasury-amt (/ (* amount (get treasury policy)) u10000))
    (bounty-amt   (/ (* amount (get bounty policy))   u10000))
    (lp-amt       (/ (* amount (get lp policy))       u10000))
    (grant-amt    (/ (* amount (get grant policy))    u10000))
    (buyback-amt  (/ (* amount (get buyback policy))  u10000))
    (ins-amt      (/ (* amount (get insurance policy)) u10000))
  )
    (begin
      (if (> treasury-amt u0) (try! (as-contract (stx-transfer? treasury-amt tx-sender (var-get treasury-vault)))) true)
      (if (> bounty-amt   u0) (try! (as-contract (stx-transfer? bounty-amt   tx-sender (var-get bounty-vault))))   true)
      (if (> lp-amt       u0) (try! (as-contract (stx-transfer? lp-amt       tx-sender (var-get lp-vault))))       true)
      (if (> grant-amt    u0) (try! (as-contract (stx-transfer? grant-amt    tx-sender (var-get grant-vault))))    true)
      (if (> buyback-amt  u0) (try! (as-contract (stx-transfer? buyback-amt  tx-sender (var-get buyback-vault))))  true)
      (if (> ins-amt      u0) (try! (as-contract (stx-transfer? ins-amt      tx-sender (var-get insurance-vault)))) true)

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

(define-public (initialize (new-admin principal) (treasury principal) (token principal))
  (begin
    (asserts! (is-eq tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (var-set cxd-treasury-principal treasury)
    (var-set cxd-token-principal token)
    (ok true)
  )
)

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
