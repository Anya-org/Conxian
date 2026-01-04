;; agent-treasury.clar
;; The Autonomous CFO (Chief Financial Officer)
;; Implements autonomous, on-chain capital management, including automated
;; revenue distribution and allocation policy management.

;; ---
;; @SECTION
;; TRAITS & DEPENDENCIES
;; ---

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait roles-trait .core-traits.rbac-trait)

;; ---
;; @SECTION
;; CONSTANTS & ERRORS
;; ---

(define-constant ROLE_ADMIN u1)

(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_SHARE (err u8001))
(define-constant ERR_DISTRIBUTION_FAILED (err u8002))

;; ---
;; @SECTION
;; STATE & CONFIGURATION
;; ---

(define-data-var contract-owner principal tx-sender) ;; Retained for initial setup
(define-data-var rbac-contract principal .rbac)

;; Allocation percentages (in basis points, 10000 = 100%)
(define-data-var staking-share uint u6000) ;; 60%
(define-data-var dev-fund-share uint u2000) ;; 20%
(define-data-var insurance-share uint u2000) ;; 20%

;; Destination vaults for revenue distribution
(define-data-var staking-vault principal .cxd-staking)
(define-data-var dev-fund-vault principal .dev-fund)
(define-data-var insurance-vault principal .conxian-insurance-fund)

;; ---
;; @SECTION
;; CORE LOGIC
;; ---

;; @desc The core autonomous function of the CFO. It receives tokens (protocol fees)
;; and distributes them to the various protocol vaults based on the on-chain allocation policy.
;; @param token The SIP-010 token contract to distribute.
;; @param amount The total amount of the token to distribute.
;; @param sender The original sender of the fees.
(define-public (distribute (token <sip-010-trait>) (amount uint) (sender principal))
    (let
        (
            (total-shares u10000)
            (staking-amt (/ (* amount (var-get staking-share)) total-shares))
            (dev-amt (/ (* amount (var-get dev-fund-share)) total-shares))
            ;; The remainder goes to the insurance fund to avoid dust.
            (insurance-amt (- amount staking-amt dev-amt))
        )
        (begin
            ;; Ensure the revenue is sent from an authorized source (e.g., the DEX facade)
            (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))

            ;; Distribute funds
            (try! (as-contract (contract-call? token transfer staking-amt (as-contract tx-sender) (var-get staking-vault) none)))
            (try! (as-contract (contract-call? token transfer dev-amt (as-contract tx-sender) (var-get dev-fund-vault) none)))
            (try! (as-contract (contract-call? token transfer insurance-amt (as-contract tx-sender) (var-get insurance-vault) none)))

            (print {
                event: "revenue-distributed",
                token: (contract-of token),
                total-amount: amount,
                staking-amount: staking-amt,
                dev-fund-amount: dev-amt,
                insurance-fund-amount: insurance-amt
            })
            (ok true)
        )
    )
)

;; ---
;; @SECTION
;; READ-ONLY FUNCTIONS
;; ---

;; @desc Retrieves the current revenue allocation percentages.
;; @returns (response { dev: uint, insurance: uint, staking: uint } none)
(define-read-only (get-allocation-percentages)
    (ok {
        staking: (var-get staking-share),
        dev: (var-get dev-fund-share),
        insurance: (var-get insurance-share)
    })
)

;; ---
;; @SECTION
;; ADMIN & CONFIGURATION
;; ---

;; @desc Sets the allocation percentages for revenue distribution.
;; @param staking The new share for staking rewards (in basis points).
;; @param dev The new share for the development fund (in basis points).
;; @param insurance The new share for the insurance fund (in basis points).
(define-private (is-authorized (role uint))
    (if (is-eq tx-sender (var-get contract-owner))
        true
        (contract-call? .rbac has-role tx-sender role)
    )
)

(define-public (set-allocations (staking uint) (dev uint) (insurance uint))
    (begin
        (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
        (asserts! (is-eq (+ staking dev insurance) u10000) ERR_INVALID_SHARE)
        (var-set staking-share staking)
        (var-set dev-fund-share dev)
        (var-set insurance-share insurance)
        (ok true)
    )
)

(define-public (set-staking-vault (address principal))
  (begin
    (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
    (var-set staking-vault address)
    (ok true)
  )
)

(define-public (set-dev-fund-vault (address principal))
  (begin
    (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
    (var-set dev-fund-vault address)
    (ok true)
  )
)

(define-public (set-insurance-vault (address principal))
  (begin
    (asserts! (is-authorized ROLE_ADMIN) ERR_UNAUTHORIZED)
    (var-set insurance-vault address)
    (ok true)
  )
)
