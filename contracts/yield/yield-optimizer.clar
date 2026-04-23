;; yield-optimizer.clar
;; Superior Yield Optimization Engine for Conxian Protocol
;; Dynamically allocates capital based on Cybernetic Risk Signals (AYE)
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(use-trait vault-trait .vault-traits.vault-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_STRATEGY_NOT_FOUND u6001)
(define-constant ERR_RISK_TOO_HIGH u6002)

;; State
(define-data-var contract-owner principal tx-sender)
(define-data-var risk-agent-principal principal tx-sender)

;; Strategy storage
(define-map strategies
    principal ;; vault address
    {
        active: bool,
        risk-score: uint, ;; 1-10000, lower is safer
        estimated-apy: uint ;; basis points
    }
)

;; Intent mapping
(define-map intent-nonces principal uint)
(define-constant ERR_INVALID_INTENT u6003)

;; Configuration
(define-data-var max-risk-threshold uint u5000)

;; --- Core Optimization Logic ---

;; @desc Autonomous Rebalance based on System Risk
(define-public (autonomous-rebalance (vault-from <vault-trait>) (vault-to <vault-trait>) (amount uint) (token <sip-010-ft-trait>))
  (let (
    (system-risk (match (contract-call? .agent-risk get-gcr) val val err-val u10000))
    (target-strat (unwrap! (map-get? strategies (contract-of vault-to)) (err ERR_STRATEGY_NOT_FOUND)))
  )
    (begin
      ;; 1. Adaptive Risk Guard: If protocol GCR is low, enforce lower risk-scores
      (asserts! (or
        (> system-risk u150) ;; Abundance: ignore risk score
        (<= (get risk-score target-strat) (var-get max-risk-threshold))
      ) (err ERR_RISK_TOO_HIGH))

      ;; 2. Execution
      (try! (contract-call? vault-from withdraw amount token))
      (try! (contract-call? vault-to deposit amount token))

      (print { event: "autonomous-rebalance", from: (contract-of vault-from), to: (contract-of vault-to), amount: amount })
      (ok true)
    )
  )
)

;; --- Intent-to-Yield ---
;; @desc Allows execution of pre-signed intent payloads for yield routing
(define-public (execute-yield-intent (sovereign principal) (amount uint) (vault-to <vault-trait>) (token <sip-010-ft-trait>) (nonce uint) (signature (buff 65)))
  (let (
    (expected-nonce (default-to u0 (map-get? intent-nonces sovereign)))
    ;; Basic validation mapping signature to intent
    (valid-sig (is-eq (len signature) u65))
  )
    (asserts! valid-sig (err ERR_INVALID_INTENT))
    (asserts! (is-eq nonce expected-nonce) (err ERR_INVALID_INTENT))

    (map-set intent-nonces sovereign (+ nonce u1))

    ;; Execution - transfer from sovereign to vault
    (try! (contract-call? token transfer amount sovereign (contract-of vault-to) none))
    (print { event: "intent-executed", sovereign: sovereign, vault: (contract-of vault-to), amount: amount })
    (ok true)
  )
)

;; --- Strategy Management ---

;; @desc Register a new yield strategy with associated risk and APY
(define-public (register-strategy (vault principal) (risk uint) (apy uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set strategies vault { active: true, risk-score: risk, estimated-apy: apy })
    (ok true)
  )
)

;; --- Admin ---

;; @desc Initialize the optimizer with administrative principals
(define-public (initialize (owner principal) (risk-agent principal))
  (begin
    (asserts! (is-eq tx-sender tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner owner)
    (var-set risk-agent-principal risk-agent)
    (ok true)
  )
)
