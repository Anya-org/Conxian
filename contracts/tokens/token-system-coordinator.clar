;; token-system-coordinator.clar
;; Conxian Enterprise Standard: Token System Coordinator (Facade)
;; Central entry point for token minting, burning, and specialized operations.
;; Orchestrates actions across CXD, CXVG, and other system tokens.
;; Tier 0: "Hands-Off" Coordination with Compliance.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)
(use-trait ft-mintable-trait .sip-standards.ft-mintable-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_INVALID_TOKEN u1001)
(define-constant ERR_NON_COMPLIANT u1002)

;; Data Vars
(define-data-var coordinator-admin principal tx-sender) ;; Ops Engine or Timelock
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)

;; System token contracts
(define-data-var cxd-token-contract principal .cxd-token)
(define-data-var cxvg-token-contract principal .cxvg-token)

;; Authorized Minters (e.g. Emission Controller, AMM, Staking)
(define-map authorized-minters principal bool)

;; --- Internal Helpers ---

(define-private (is-admin)
  (is-eq tx-sender (var-get coordinator-admin))
)

(define-private (is-authorized-minter)
  (default-to false (map-get? authorized-minters tx-sender))
)

(define-private (check-compliance (user principal))
  (let (
      (result (contract-call? .regulatory-adapter
                check-clean-hands-compliance
                user
             ))
    )
    (is-ok result)
  )
)

(define-private (mint-token
    (token <ft-mintable-trait>)
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-authorized-minter) (err ERR_UNAUTHORIZED))
    (asserts! (check-compliance recipient) (err ERR_NON_COMPLIANT))
    (try! (contract-call? token mint amount recipient))
    (ok true)
  )
)

(define-private (burn-token
    (token <ft-mintable-trait>)
    (amount uint)
    (owner principal)
  )
  (begin
    (asserts! (is-eq tx-sender owner) (err ERR_UNAUTHORIZED))
    (try! (contract-call? token burn amount owner))
    (ok true)
  )
)

;; --- Administration ---

(define-public (set-coordinator-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set coordinator-admin new-admin)
    (ok true)
  )
)

(define-public (set-minter-status (minter principal) (status bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (map-set authorized-minters minter status)
    (ok true)
  )
)

(define-public (set-cxd-token (token principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set cxd-token-contract token)
    (ok true)
  )
)

(define-public (set-cxvg-token (token principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set cxvg-token-contract token)
    (ok true)
  )
)

;; --- Facade: Minting ---

;; @desc Mints CXD (Revenue Token)
;; Only authorized minters (e.g. Emission Controller) can trigger this via the coordinator.
(define-public (mint-cxd
    (token <ft-mintable-trait>)
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq (contract-of token) (var-get cxd-token-contract)) (err ERR_INVALID_TOKEN))
    (mint-token token amount recipient)
  )
)

;; @desc Mints CXVG (Voting Token)
;; Only authorized minters can trigger this.
(define-public (mint-cxvg
    (token <ft-mintable-trait>)
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq (contract-of token) (var-get cxvg-token-contract)) (err ERR_INVALID_TOKEN))
    (mint-token token amount recipient)
  )
)

;; --- Facade: Burning ---

(define-public (burn-cxd
    (token <ft-mintable-trait>)
    (amount uint)
    (owner principal)
  )
  (begin
    (asserts! (is-eq (contract-of token) (var-get cxd-token-contract)) (err ERR_INVALID_TOKEN))
    (burn-token token amount owner)
  )
)

(define-public (burn-cxvg
    (token <ft-mintable-trait>)
    (amount uint)
    (owner principal)
  )
  (begin
    (asserts! (is-eq (contract-of token) (var-get cxvg-token-contract)) (err ERR_INVALID_TOKEN))
    (burn-token token amount owner)
  )
)
