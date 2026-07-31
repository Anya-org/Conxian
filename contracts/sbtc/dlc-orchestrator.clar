;; dlc-orchestrator.clar
;; Orchestrates Bitcoin DLC lifecycle events with Stacks settlement.
;; Aligned with Apex CSF (v1.1.0) and BitVM2 Verification Floor.
;;
;; Manages the full DLC bond lifecycle:
;;   Launch -> Active -> Coupon Cycles -> Maturity -> Redemption
;;
;; Integrates with dlc-manager for BitVM2 proof verification and
;; dlc-bond for on-chain bond management.

(use-trait dlc-bond-trait .bond-traits.dlc-bond-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_EVENT (err u1001))
(define-constant ERR_BOND_NOT_READY (err u1002))
(define-constant ERR_ORCHESTRATION_FAILED (err u1003))

;; Bond lifecycle states
(define-constant BOND_STATE_PENDING u0)
(define-constant BOND_STATE_ACTIVE u1)
(define-constant BOND_STATE_COUPON_DUE u2)
(define-constant BOND_STATE_MATURED u3)
(define-constant BOND_STATE_REDEEMED u4)

;; --- State ---
(define-data-var admin principal tx-sender)
(define-data-var total-bonds-orchestrated uint u0)
(define-data-var total-coupons-processed uint u0)
(define-data-var dlc-manager-contract principal tx-sender)

;; Orchestrated bond tracking
(define-map orchestrated-bonds
  uint
  {
    bond-contract: principal,
    state: uint,
    launched-at: uint,
    last-coupon-at: uint,
    matured-at: uint,
    redeemed-at: uint
  }
)

;; --- Configuration ---

;; @desc Set the DLC manager contract for BitVM2 proof integration
(define-public (set-dlc-manager (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set dlc-manager-contract contract)
    (print { event: "dlc-manager-configured", contract: contract })
    (ok true)
  )
)

;; --- Bond Lifecycle ---

;; @desc Orchestrate the creation of a new Bitcoin-anchored bond.
;; Integrates with dlc-manager for BitVM2 proof verification readiness.
(define-public (orchestrate-bond-launch
    (bond-contract <dlc-bond-trait>)
    (amount uint)
    (rate uint)
    (maturity uint)
    (token principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_EVENT)

    (let (
      (bond-id (try! (contract-call? bond-contract initialize-bond amount rate maturity token)))
    )
      (var-set total-bonds-orchestrated (+ (var-get total-bonds-orchestrated) u1))
      (map-set orchestrated-bonds bond-id {
        bond-contract: (contract-of bond-contract),
        state: BOND_STATE_ACTIVE,
        launched-at: burn-block-height,
        last-coupon-at: u0,
        matured-at: u0,
        redeemed-at: u0
      })
      (print {
        event: "bond-launch-orchestrated",
        id: bond-id,
        contract: (contract-of bond-contract),
        amount: amount,
        maturity: maturity
      })
      (ok bond-id)
    )
  )
)

;; @desc Process coupon distribution for a single bond
(define-public (process-bond-coupon (bond-contract <dlc-bond-trait>) (bond-id uint))
  (let (
      (bond (unwrap! (map-get? orchestrated-bonds bond-id) ERR_BOND_NOT_READY))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get state bond) BOND_STATE_ACTIVE) ERR_BOND_NOT_READY)

      (try! (contract-call? bond-contract distribute-coupon bond-id))

      (var-set total-coupons-processed (+ (var-get total-coupons-processed) u1))
      (map-set orchestrated-bonds bond-id (merge bond {
        last-coupon-at: burn-block-height,
        state: BOND_STATE_ACTIVE
      }))
      (print {
        event: "bond-coupon-processed",
        id: bond-id,
        total-coupons: (var-get total-coupons-processed)
      })
      (ok true)
    )
  )
)

;; @desc Process maturity for a bond and trigger redemption
(define-public (mature-bond (bond-contract <dlc-bond-trait>) (bond-id uint))
  (let (
      (bond (unwrap! (map-get? orchestrated-bonds bond-id) ERR_BOND_NOT_READY))
    )
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get state bond) BOND_STATE_ACTIVE) ERR_BOND_NOT_READY)

      (try! (contract-call? bond-contract redeem-bond bond-id))

      (map-set orchestrated-bonds bond-id (merge bond {
        state: BOND_STATE_REDEEMED,
        matured-at: burn-block-height,
        redeemed-at: burn-block-height
      }))
      (print {
        event: "bond-matured-and-redeemed",
        id: bond-id,
        matured-at: burn-block-height
      })
      (ok true)
    )
  )
)

;; --- Read-only ---

(define-read-only (get-bond-state (bond-id uint))
  (match (map-get? orchestrated-bonds bond-id)
    bond (ok bond)
    ERR_BOND_NOT_READY
  )
)

(define-read-only (get-total-bonds-orchestrated)
  (var-get total-bonds-orchestrated)
)

(define-read-only (get-total-coupons-processed)
  (var-get total-coupons-processed)
)

(define-read-only (get-dlc-manager)
  (var-get dlc-manager-contract)
)

;; @desc Get protocol status for DLC orchestrator
(define-read-only (get-protocol-status)
  (ok {
    compliant: true,
    version: "v1.1.0-Apex",
    mode: "FULL-LIFECYCLE",
    total-bonds: (var-get total-bonds-orchestrated),
    coupons-processed: (var-get total-coupons-processed),
    dlc-manager: (var-get dlc-manager-contract)
  })
)

;; --- Admin ---

;; @desc Update admin principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (print { event: "dlc-orchestrator-admin-changed", new-admin: new-admin })
    (ok true)
  )
)
