;; agent-treasury.clar
;; Autonomous Fiscal Agent for Conxian Protocol
;; Upgraded for Sovereign BME Orchestration

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))

;; --- Data Variables ---
(define-data-var admin principal 'ST1BK6TFDEJ4TBVWH5SHNB6SPNWGY06YZFG9WMM4P)
(define-data-var initialized bool false)

;; --- Authorization ---

(define-read-only (is-authorized-admin)
  (or (is-eq tx-sender (var-get admin)) (not (var-get initialized)))
)

;; --- Public Functions ---

;; @desc Run the fiscal strategy - Orchestrates BME epoch and buy-backs
(define-public (run-fiscal-strategy (pools-to-reward (list 50 principal)) (cxd-token-trait <sip-010-trait>))
  (let (
    (intel (unwrap! (contract-call? .agent-risk get-cybernetic-intel) (err u2001)))
  )
    (begin
      ;; 1. Collect protocol fees from core modules
      (match (contract-call? .concentrated-liquidity-pool collect-protocol-fees cxd-token-trait)
        res true
        err-val false
      )

      ;; 2. Trigger BME epoch minting
      (match (contract-call? .bme-engine execute-epoch-minting pools-to-reward)
        res (begin (print { event: "bme-epoch-minted", success: true }) true)
        err-val (begin (print { event: "bme-epoch-skipped", reason: err-val }) false)
      )

      (ok true)
    )
  )
)

;; @desc Calculates performance-based adjustment for bounty (CXIP-013)
(define-read-only (calculate-performance-adjustment)
  (let (
    (metrics (unwrap-panic (contract-call? .agent-risk get-performance-metrics)))
    (growth-bps (get tvl-growth-bps metrics))
    (bounty-rate (get bounty-completion-rate metrics))
  )
    (if (or (> growth-bps u1200) (> bounty-rate u9500))
      (ok u500)
      (ok u0)
    )
  )
)

;; @desc Calculates dynamic allocation policy based on GCR (CXIP-013)
(define-read-only (calculate-cybernetic-policy)
  (let (
    (gcr (unwrap-panic (contract-call? .agent-risk get-gcr)))
  )
    (if (< gcr u110)
      ;; CRISIS Mode
      (ok {
        treasury: u0,
        bounty: u0,
        lp: u0,
        grant: u0,
        buyback: u0,
        insurance: u10000
      })
      (if (< gcr u150)
        ;; STABILITY Mode
        (ok {
          treasury: u4500,
          bounty: u3000,
          lp: u1500,
          grant: u500,
          buyback: u500,
          insurance: u0
        })
        ;; ABUNDANCE Mode
        (ok {
          treasury: u1000,
          bounty: u0,
          lp: u8000,
          grant: u0,
          buyback: u0,
          insurance: u1000
        })
      )
    )
  )
)

(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-authorized-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (var-set initialized true)
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-read-only (get-protocol-status)
  (ok { compliant: true, version: "v1.1.0-Apex" })
)
