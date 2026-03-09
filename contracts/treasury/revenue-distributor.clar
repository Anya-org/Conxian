;; revenue-distributor.clar
;; Distributes protocol revenue - Upgraded for BME
;; 100% of fees are now effectively handled through the BME Engine/Vault logic.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-data-var admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; State
(define-data-var bme-vault principal .bme-engine)

;; Public Functions

;; @desc Distribute tokens for buy-back and burn
(define-public (distribute-token (token <sip-010-ft-trait>) (amount uint))
  (begin
    ;; In the Sovereign BME, we route 100% to the BME mechanism
    ;; If the token is already CXD, we burn it.
    ;; If it's STX/sBTC, we swap and burn.
    (if (is-eq (contract-of token) .cxd-token)
        (try! (contract-call? .bme-engine burn-protocol-fees amount))
        (try! (contract-call? .bme-engine swap-and-burn token amount))
    )
    (ok true)
  )
)

(define-public (distribute-stx (amount uint))
  (begin
    ;; Autonomous Buy-Back and Burn for STX
    ;; Placeholder: Logic to swap STX for CXD and burn
    (ok true)
  )
)

;; Admin Functions

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-bme-vault (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (var-set bme-vault new-vault)
    (ok true)
  )
)
