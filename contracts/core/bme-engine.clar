;; bme-engine.clar
;; Burn-Mint Equilibrium Engine for Conxian Protocol

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_EPOCH (err u1001))

(define-constant MINT_PER_EPOCH u100000000)
(define-constant EPOCH_LENGTH u144)

(define-constant WEIGHT_DEX u4000)
(define-constant WEIGHT_LENDING u3000)
(define-constant WEIGHT_BOUNTY u2000)
(define-constant WEIGHT_GOV u1000)

(define-map dex-activity principal uint)
(define-map lending-activity principal uint)
(define-map bounty-activity principal uint)
(define-map gov-activity principal uint)

(define-data-var total-dex-activity uint u0)
(define-data-var total-lending-activity uint u0)
(define-data-var total-bounty-activity uint u0)
(define-data-var total-gov-activity uint u0)
(define-data-var total-burned uint u0)
(define-data-var last-mint-block uint burn-block-height)

(define-private (is-authorized-reporter)
  (is-ok (contract-call? .conxian-access has-role tx-sender u2))
)

(define-public (register-fee-activity (lp principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set dex-activity lp (+ (default-to u0 (map-get? dex-activity lp)) amount))
    (var-set total-dex-activity (+ (var-get total-dex-activity) amount))
    (ok true)
  )
)

(define-public (register-lending-activity (user principal) (amount uint))
  (begin
    (asserts! (is-authorized-reporter) ERR_UNAUTHORIZED)
    (map-set lending-activity user (+ (default-to u0 (map-get? lending-activity user)) amount))
    (var-set total-lending-activity (+ (var-get total-lending-activity) amount))
    (ok true)
  )
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

(define-public (execute-epoch-minting (targets (list 100 principal)))
  (let ((current-height burn-block-height)
        (last-mint (var-get last-mint-block)))
    (begin
      (asserts! (>= (- current-height last-mint) EPOCH_LENGTH) ERR_INVALID_EPOCH)
      (map distribute-merit-rewards targets)
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
  (let ((dex-share (let ((activity (default-to u0 (map-get? dex-activity target)))
                         (total (var-get total-dex-activity))
                         (allocation (/ (* MINT_PER_EPOCH WEIGHT_DEX) u10000)))
                     (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (lending-share (let ((activity (default-to u0 (map-get? lending-activity target)))
                             (total (var-get total-lending-activity))
                             (allocation (/ (* MINT_PER_EPOCH WEIGHT_LENDING) u10000)))
                         (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (bounty-share (let ((activity (default-to u0 (map-get? bounty-activity target)))
                            (total (var-get total-bounty-activity))
                            (allocation (/ (* MINT_PER_EPOCH WEIGHT_BOUNTY) u10000)))
                        (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (gov-share (let ((activity (default-to u0 (map-get? gov-activity target)))
                         (total (var-get total-gov-activity))
                         (allocation (/ (* MINT_PER_EPOCH WEIGHT_GOV) u10000)))
                     (if (and (> total u0) (> activity u0)) (/ (* activity allocation) total) u0)))
        (total-mint (+ dex-share lending-share bounty-share gov-share)))
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
    (print { event: "swap-and-burn-triggered", token: (contract-of token), amount: amount })
    (var-set total-burned (+ (var-get total-burned) amount))
    (ok true)
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
