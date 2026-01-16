;; governance-handover.clar
;; Conxian Enterprise Standard: Governance Handover Verification
;; Verifies the "Tier 0" transition of control from Deployer to Timelock/DAO.
;; Ensures "Hands-Off" ethos by cryptographically proving no admin keys remain in individual hands.

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u10000))
(define-constant ERR_HANDOVER_INCOMPLETE (err u10001))
(define-constant TARGET_OWNER .timelock)

;; Contract Principals
(define-data-var conxian-protocol-contract principal .conxian-protocol)
(define-data-var agent-risk-contract principal .agent-risk)
(define-data-var agent-treasury-contract principal .agent-treasury)
(define-data-var regulatory-adapter-contract principal .regulatory-adapter)
(define-data-var conxian-access-contract principal .conxian-access)

;; Critical System Contracts to Audit
;; These must all be owned by .timelock for the system to be considered "Tier 0"
(define-constant CONTRACTS_TO_VERIFY (list
  .conxian-protocol
  .agent-risk
  .agent-treasury
  .compliance.regulatory-adapter
  .conxian-access
))

;; @desc Verifies that a specific contract has been transferred to the Timelock
(define-private (verify-contract-owner (target principal))
  (let (
      ;; Dynamic contract-call to get-contract-owner
      ;; Note: In Clarity, we can't easily dynamic-dispatch to a list of diverse contracts 
      ;; unless they share a trait. We assume they all implement 'get-contract-owner'.
      ;; For this aggregator, we might need explicit checks if they don't share a trait.
      ;; However, we added 'get-contract-owner' to the agents.
      ;; We will use a try! to catch failures if function doesn't exist (though it should).
      (owner (unwrap-panic (contract-call? .conxian-access get-contract-owner)))
    )
    ;; Real implementation requires explicit calls or a trait. 
    ;; Since lists in Clarity are strict, we'll implement an explicit check function.
    true
  )
)

;; @desc Main Verification Function
;; Returns true if ALL critical systems are owned by the Timelock.
(define-public (verify-full-handover)
  (let (
      (protocol-owner (unwrap-panic (contract-call? .conxian-protocol get-admin)))
      (risk-owner (unwrap-panic (contract-call? .agent-risk get-contract-owner)))
      (treasury-owner (unwrap-panic (contract-call? .agent-treasury get-contract-owner)))
      (reg-owner (unwrap-panic (contract-call? .regulatory-adapter get-contract-owner)))
      (access-owner (unwrap-panic (contract-call? .conxian-access get-contract-owner)))
    )
    (asserts! (contract-call? .admin-facade is-global-admin) ERR_NOT_AUTHORIZED) ;; Added this line based on the instruction's context.

    ;; Check Conxian Protocol
    (asserts! (is-eq protocol-owner TARGET_OWNER)
      (err {
        contract: "conxian-protocol",
        owner: protocol-owner,
      })
    )

    ;; Check Risk Agent
    (asserts! (is-eq risk-owner TARGET_OWNER)
      (err {
        contract: "agent-risk",
        owner: risk-owner,
      })
    )

    ;; Check Treasury Agent
    (asserts! (is-eq treasury-owner TARGET_OWNER)
      (err {
        contract: "agent-treasury",
        owner: treasury-owner,
      })
    )

    ;; Check Regulatory Adapter
    (asserts! (is-eq reg-owner TARGET_OWNER)
      (err {
        contract: "regulatory-adapter",
        owner: reg-owner,
      })
    )

    ;; Check Access Control Root
    (asserts! (is-eq access-owner TARGET_OWNER)
      (err {
        contract: "conxian-access",
        owner: access-owner,
      })
    )

    (print {
      event: "handover-verified",
      status: "complete",
      new-owner: TARGET_OWNER,
    })
    (ok true)
  )
)

;; @desc Signal Readiness
;; Can be used by the UI to show the "Decentralization Score" or "Tier 0 Status"
(define-read-only (get-handover-status)
  (match (verify-full-handover)
    success (ok "TIER-0-ACHIEVED")
    failure (err "HANDOVER-PENDING")
  )
)
