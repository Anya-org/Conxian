;;; # Dimensional Core Contract
;;;
;;; Core engine for managing leveraged dimensional positions with automated risk tracking.
;;; Adheres to Clarity 4 / Nakamoto Standard (SIP-033/034).
;;; 
;;; Version: 1.2.0
;;; Enforced Standards: CXIP-012 (Dual-Clock) CXIP-013 (Fiscal Dam)

;; Traits
(use-trait oracle-trait .defi-traits.oracle-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)

;; ===== Constants =====
(define-constant CONTRACT_VERSION "1.2.0")
(define-constant MAX_LEVERAGE u100)
(define-constant MIN_COLLATERAL u1000)
(define-constant PROTOCOL_FEE_DENOMINATOR u10000)
(define-constant DEFAULT_MAINTENANCE_MARGIN u500)
(define-constant MAX_FEE_RATE u1000)

;; ===== Error Codes =====
(define-constant ERR_UNAUTHORIZED u2001)
(define-constant ERR_INVALID_POSITION u2002)
(define-constant ERR_INSUFFICIENT_COLLATERAL u2003)
(define-constant ERR_SLIPPAGE u2004)
(define-constant ERR_POSITION_NOT_ACTIVE u2008)
(define-constant ERR_INVALID_LEVERAGE u2006)
(define-constant ERR_BITCOIN_NOT_FINALIZED u10001)

;; ===== Data Variables =====
(define-data-var owner principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var risk-manager-principal principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var dimensional-token principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var next-position-id uint u0)
(define-data-var protocol-fee-rate uint u30)
(define-data-var total-value-locked uint u0)

;; ===== Data Maps =====
(define-map positions
  { owner: principal id: uint }
  {
    collateral: uint
    size: int
    entry-price: uint
    entry-time: uint        ;; Unix timestamp (burn-block-height)
    last-funding: uint     ;; Unix timestamp (burn-block-height)
    last-updated: uint     ;; Unix timestamp (burn-block-height)
    position-type: (string-ascii 20)
    status: (string-ascii 20)
    max-leverage: uint
    maintenance-margin: uint
    tenure-id: uint         ;; Nakamoto Tenure ID (block-height based)
  }
)

;; ===== Read-Only Functions =====

;; @desc Retrieves a position's details.
;; @param user principal - The owner of the position.
;; @param position-id uint - The unique identifier of the position.
;; @returns (optional tuple)
(define-read-only (get-position (user principal) (position-id uint))
  (map-get? positions { owner: user id: position-id })
)

(define-read-only (calculate-tvl)
  (ok (var-get total-value-locked))
)

;; @desc Calculates the health factor of a position.
;; @param user principal - Position owner.
;; @param position-id uint - Position ID.
;; @param oracle-ref <oracle-trait> - Reference to the price oracle.
;; @returns (response uint uint)
(define-public (get-health-factor (user principal) (position-id uint) (oracle-ref <oracle-trait>))
  (let (
      (position (unwrap! (get-position user position-id) (err ERR_INVALID_POSITION)))
      (current-price (try! (contract-call? oracle-ref get-price (var-get dimensional-token))))
      (collateral (get collateral position))
      (pnl (calculate-pnl position current-price))
      (mm (get maintenance-margin position))
      (adjusted-collateral (if (>= pnl 0) (+ collateral (to-uint pnl)) (if (> (to-uint (* -1 pnl)) collateral) u0 (- collateral (to-uint (* -1 pnl))))))
    )
    (ok (if (> mm u0) (/ (* adjusted-collateral u10000) mm) u999999999))
  )
)

;; ===== Public Functions: Position Management =====

;; @desc Opens a new dimensional position.
;; @param collateral-amount uint - Amount of collateral to post.
;; @param leverage uint - Leverage multiplier.
;; @param position-type (string-ascii 20) - LONG or SHORT.
;; @param token-trait <sip-010-ft-trait> - Collateral token.
;; @param oracle-ref <oracle-trait> - Price oracle.
;; @returns (response uint uint)
(define-public (open-position
    (collateral-amount uint)
    (leverage uint)
    (position-type (string-ascii 20))
    (token-trait <sip-010-ft-trait>)
    (oracle-ref <oracle-trait>)
  )
  (begin
    (asserts! (> burn-block-height u6) (err ERR_BITCOIN_NOT_FINALIZED))
    (let (
        (pos-id (var-get next-position-id))
        (price (try! (contract-call? oracle-ref get-price (contract-of token-trait))))
        (size (to-int (* collateral-amount leverage)))
      )
      (asserts! (>= collateral-amount MIN_COLLATERAL) (err ERR_UNAUTHORIZED))
      (asserts! (<= leverage MAX_LEVERAGE) (err ERR_INVALID_LEVERAGE))

      (try! (contract-call? token-trait transfer collateral-amount tx-sender (as-contract tx-sender) none))
      (try! (contract-call? .position-nft mint tx-sender pos-id))

      (map-set positions { owner: tx-sender id: pos-id } {
        collateral: collateral-amount
        size: (if (is-eq position-type "LONG") size (* size -1))
        entry-price: price
        entry-time: burn-block-height
        last-funding: burn-block-height
        last-updated: burn-block-height
        position-type: position-type
        status: "ACTIVE"
        max-leverage: leverage
        maintenance-margin: (+ DEFAULT_MAINTENANCE_MARGIN (* leverage leverage))
        tenure-id: (/ block-height u10)
      })

      (var-set next-position-id (+ pos-id u1))
      (var-set total-value-locked (+ (var-get total-value-locked) collateral-amount))
      (ok pos-id)
    )
  )
)

;; @desc Closes an active position.
;; @param position-id uint - The ID of the position to close.
;; @param token-trait <sip-010-ft-trait> - The collateral token trait.
;; @param oracle <oracle-trait> - The price oracle trait.
;; @returns (response bool uint)
(define-public (close-position (position-id uint) (token-trait <sip-010-ft-trait>) (oracle <oracle-trait>))
  (let (
      (pos (unwrap! (get-position tx-sender position-id) (err ERR_INVALID_POSITION)))
      (price (try! (contract-call? oracle get-price (var-get dimensional-token))))
      (pnl (calculate-pnl pos price))
      (fees (calculate-fees pos))
      (collateral (get collateral pos))
      (payout (if (>= pnl 0) (+ collateral (to-uint pnl)) (if (> (to-uint (* -1 pnl)) collateral) u0 (- collateral (to-uint (* -1 pnl))))))
      (final-amt (if (>= payout fees) (- payout fees) u0))
    )
    (begin
      (asserts! (is-eq (get status pos) "ACTIVE") (err ERR_POSITION_NOT_ACTIVE))
      (map-set positions { owner: tx-sender id: position-id } (merge pos { status: "CLOSED" last-updated: burn-block-height }))
      (if (> final-amt u0) (try! (as-contract (contract-call? token-trait transfer final-amt tx-sender tx-sender none))) true)
      (try! (contract-call? .position-nft burn position-id))
      (var-set total-value-locked (- (var-get total-value-locked) collateral))
      (ok true)
    )
  )
)

;; @desc Liquidates a position.
;; @param user principal - The owner of the position.
;; @param position-id uint - The ID of the position to liquidate.
;; @param oracle-ref <oracle-trait> - The price oracle trait.
;; @returns (response bool uint)
(define-public (liquidate-position (user principal) (position-id uint) (oracle-ref <oracle-trait>))
  (begin
    (asserts! (is-eq contract-caller (var-get risk-manager-principal)) (err ERR_UNAUTHORIZED))
    (let (
        (pos (unwrap! (get-position user position-id) (err ERR_INVALID_POSITION)))
        (collateral (get collateral pos))
      )
      (asserts! (is-eq (get status pos) "ACTIVE") (err ERR_POSITION_NOT_ACTIVE))
      (map-set positions { owner: user id: position-id } (merge pos { status: "LIQUIDATED" last-updated: burn-block-height }))
      (try! (contract-call? .position-nft burn position-id))
      (var-set total-value-locked (- (var-get total-value-locked) collateral))
      (ok true)
    )
  )
)

;; ===== Private Helpers =====

(define-private (calculate-pnl (pos { collateral: uint size: int entry-price: uint entry-time: uint last-funding: uint last-updated: uint position-type: (string-ascii 20) status: (string-ascii 20) max-leverage: uint maintenance-margin: uint tenure-id: uint }) (curr-price uint))
  (let (
      (size (get size pos))
      (entry (get entry-price pos))
      (abs-size (if (>= size 0) (to-uint size) (to-uint (* size -1))))
    )
    (if (> size 0)
      (to-int (/ (* abs-size (- curr-price entry)) entry))
      (to-int (/ (* abs-size (- entry curr-price)) entry))
    )
  )
)

(define-private (calculate-fees (pos { collateral: uint size: int entry-price: uint entry-time: uint last-funding: uint last-updated: uint position-type: (string-ascii 20) status: (string-ascii 20) max-leverage: uint maintenance-margin: uint tenure-id: uint }))
  (let (
      (size (get size pos))
      (abs-size (if (>= size 0) (to-uint size) (to-uint (* size -1))))
      (duration (- burn-block-height (get entry-time pos)))
    )
    (/ (* abs-size duration (var-get protocol-fee-rate)) (* u86400 PROTOCOL_FEE_DENOMINATOR)) ;; Normalized to per-day rate
  )
)

;; ===== Admin =====

;; @desc Updates the authorized risk manager principal.
;; @param mgr principal - The new risk manager principal.
;; @returns (response bool uint)
(define-public (set-risk-manager (mgr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (var-set risk-manager-principal mgr)
    (ok true)
  )
)
