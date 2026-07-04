;; bme-engine.clar
;; Burn-Mint Equilibrium Engine for Conxian Protocol
;; CXIP-013 Aligned: DEX 45% / Bounty 30% / Governance 15% / Grants 10%

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_EPOCH (err u1001))
(define-constant ERR_SWAP_FAILED (err u2002))

(define-constant MINT_PER_EPOCH u100000000)
(define-constant EPOCH_LENGTH u144)

;; CXIP-013 Emission Weights (basis points, total = 10000)
(define-constant WEIGHT_DEX u4500)      ;; 45% - DEX Liquidity
(define-constant WEIGHT_BOUNTY u3000)   ;; 30% - Bounty Completion
(define-constant WEIGHT_GOV u1500)      ;; 15% - Governance Staking
(define-constant WEIGHT_GRANTS u1000)   ;; 10% - Strategic Grants

(define-map dex-activity principal uint)
(define-map bounty-activity principal uint)
(define-map gov-activity principal uint)
(define-map grants-activity principal uint)
(define-map activity-reporters principal bool)

(define-data-var total-dex-activity uint u0)
(define-data-var total-bounty-activity uint u0)
(define-data-var total-gov-activity uint u0)
(define-data-var total-grants-activity uint u0)
(define-data-var total-burned uint u0)
(define-data-var last-mint-block uint burn-block-height)
(define-data-var admin principal tx-sender)

(define-private (is-authorized-reporter)
  (or
    (is-eq tx-sender (var-get admin))
    (default-to false (map-get? activity-reporters tx-sender))
    (is-ok (contract-call? .conxian-access has-role tx-sender u2))
  )
)

(define-public (add-activity-reporter (reporter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set activity-reporters reporter true)
    (ok true)
  )
)

(define-public (register-fee-activity (lp principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set dex-activity lp (+ (default-to u0 (map-get? dex-activity lp)) amount))
    (var-set total-dex-activity (+ (var-get total-dex-activity) amount))
    (ok true)
  )
)

(define-public (register-dex-activity (contributor principal) (amount uint))
  (register-fee-activity contributor amount)
)

(define-public (register-bounty-activity (contributor principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set bounty-activity contributor (+ (default-to u0 (map-get? bounty-activity contributor)) amount))
    (var-set total-bounty-activity (+ (var-get total-bounty-activity) amount))
    (ok true)
  )
)

(define-public (register-gov-activity (voter principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set gov-activity voter (+ (default-to u0 (map-get? gov-activity voter)) amount))
    (var-set total-gov-activity (+ (var-get total-gov-activity) amount))
    (ok true)
  )
)

(define-public (register-grants-activity (contributor principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set grants-activity contributor (+ (default-to u0 (map-get? grants-activity contributor)) amount))
    (var-set total-grants-activity (+ (var-get total-grants-activity) amount))
    (ok true)
  )
)

(define-public (execute-epoch-minting (targets (list 100 principal)))
  (let ((current-height burn-block-height)
        (last-mint (var-get last-mint-block)))
    (begin
      (asserts! (>= (- current-height last-mint) EPOCH_LENGTH) ERR_INVALID_EPOCH)
      (map distribute-merit-rewards targets)
      (var-set total-dex-activity u0)
      (var-set total-bounty-activity u0)
      (var-set total-gov-activity u0)
      (var-set total-grants-activity u0)
      (var-set last-mint-block current-height)
      (ok true)
    )
  )
)

(define-private (distribute-merit-rewards (target principal))
  (let ((dex-share (let ((activity (default-to u0 (map-get? dex-activity target)))
                         (total (var-get total-dex-activity))
                         (allocation (/ (* MINT_PER_EPOCH WEIGHT_DEX) u10000)))
                     (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (bounty-share (let ((activity (default-to u0 (map-get? bounty-activity target)))
                            (total (var-get total-bounty-activity))
                            (allocation (/ (* MINT_PER_EPOCH WEIGHT_BOUNTY) u10000)))
                        (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (gov-share (let ((activity (default-to u0 (map-get? gov-activity target)))
                         (total (var-get total-gov-activity))
                         (allocation (/ (* MINT_PER_EPOCH WEIGHT_GOV) u10000)))
                     (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (grants-share (let ((activity (default-to u0 (map-get? grants-activity target)))
                            (total (var-get total-grants-activity))
                            (allocation (/ (* MINT_PER_EPOCH WEIGHT_GRANTS) u10000)))
                        (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (total-mint (+ dex-share bounty-share gov-share grants-share)))
    (if (> total-mint u0)
      (is-ok (contract-call? .cxd-token mint total-mint target))
      false
    )
  )
)

(define-public (burn-protocol-fees (amount uint))
  (begin
    (try! (contract-call? .cxd-token burn amount tx-sender))
    (var-set total-burned (+ (var-get total-burned) amount))
    (ok true)
  )
)

(define-public (swap-and-burn (token <sip-010-ft-trait>) (amount uint))
  (begin
    ;; Transfer tokens from tx-sender to swap-router for the swap
    (try! (as-contract (contract-call? token transfer amount tx-sender .swap-router none)))
    ;; Execute swap: token -> CXD via CSF swap-router, receiving CXD at self
    ;; Entire swap+burn runs as-contract so tx-sender is bme-engine
    (as-contract
      (match (contract-call? .swap-router csf-swap token .cxd-token amount tx-sender)
        swap-result (let ((cxd-received (get amount-out swap-result)))
          ;; Burn the received CXD
          (try! (contract-call? .cxd-token burn cxd-received tx-sender))
          (var-set total-burned (+ (var-get total-burned) cxd-received))
          (print { event: "swap-and-burn-executed", token: (contract-of token), amount: amount, cxd-burned: cxd-received })
          (ok true)
        )
        swap-err (begin
          (print { event: "swap-and-burn-failed", token: (contract-of token), amount: amount })
          ERR_SWAP_FAILED
        )
      )
    )
  )
)

(define-read-only (get-bme-stats)
  (ok {
    total-dex-activity: (var-get total-dex-activity),
    total-burned: (var-get total-burned),
    last-mint-block: (var-get last-mint-block),
    mint-per-epoch: MINT_PER_EPOCH
  })
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex" })
)

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
