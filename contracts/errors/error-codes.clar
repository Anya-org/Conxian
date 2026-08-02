;; error-codes.clar
;; Centralized Protocol-Wide Error Code Registry
;; All Conxian Protocol modules reference these standardized codes.
;;
;; Error ranges by functional domain:
;;   1000-1999: Core Protocol
;;   2000-2999: DEX & Math
;;   3000-3999: Governance
;;   4000-4999: Agents & Monitoring
;;   5000-5999: Performance & Yield
;;   6000-6999: Bitcoin/sBTC Bridge
;;   7000-7999: Treasury & Revenue
;;   8000-8999: Security & Compliance
;;   9000-9999: Integrations & Oracle

;; --- Global Standards ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)
(define-constant ERR_NOT_IMPLEMENTED u9999)

;; --- Core & Protocol (1000-1999) ---
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_INVALID_AMOUNT u1003)
(define-constant ERR_INSUFFICIENT_COLLATERAL u1004)
(define-constant ERR_INVALID_PROOF u1005)
(define-constant ERR_ZERO_AMOUNT u1006)
(define-constant ERR_OVERFLOW u1007)
(define-constant ERR_NOT_INITIALIZED u1008)
(define-constant ERR_ALREADY_INITIALIZED u1009)
(define-constant ERR_CONTRACT_MISMATCH u1010)
(define-constant ERR_TIMELOCK_ACTIVE u1011)
(define-constant ERR_NO_PENDING_OWNER u1012)

;; --- DEX & Math (2000-2999) ---
(define-constant ERR_INVALID_TICK u2001)
(define-constant ERR_INVALID_PATH u2005)
(define-constant ERR_SLIPPAGE u3000)
(define-constant ERR_INSUFFICIENT_OUTPUT u2002)
(define-constant ERR_PRICE_ORACLE_STALE u2003)
(define-constant ERR_POOL_NOT_FOUND u2004)
(define-constant ERR_SQRT_PRICE_LIMIT u2006)
(define-constant ERR_LIQUIDITY_ZERO u2007)

;; --- Governance (3000-3999) ---
(define-constant ERR_PROPOSAL_NOT_FOUND u3001)
(define-constant ERR_PROPOSAL_NOT_ACTIVE u3003)
(define-constant ERR_VOTING_CLOSED u3004)
(define-constant ERR_QUORUM_NOT_REACHED u3006)
(define-constant ERR_PROPOSAL_FAILED u3007)
(define-constant ERR_INVALID_PROPOSAL_CONTRACT u3008)
(define-constant ERR_ALREADY_EXECUTED u3009)
(define-constant ERR_ALREADY_VOTED u3010)
(define-constant ERR_HANDOVER_INCOMPLETE u3011)
(define-constant ERR_STEP_ALREADY_COMPLETE u3012)

;; --- Agents & Monitoring (4000-4999) ---
(define-constant ERR_AGENT_NOT_FOUND u4001)
(define-constant ERR_AGENT_UNAUTHORIZED u4002)
(define-constant ERR_MONITORING_DISABLED u4003)
(define-constant ERR_RATE_LIMIT_EXCEEDED u4004)

;; --- Performance & Yield (5000-5999) ---
(define-constant ERR_YIELD_STRATEGY_FAILED u5001)
(define-constant ERR_COMPOUNDING_FAILED u5002)
(define-constant ERR_STRATEGY_NOT_FOUND u5003)
(define-constant ERR_PERFORMANCE_BELOW_THRESHOLD u5004)

;; --- Bitcoin/sBTC Bridge (6000-6999) ---
(define-constant ERR_BITVM2_VERIFICATION_FAILED u6001)
(define-constant ERR_DLC_NOT_FOUND u6002)
(define-constant ERR_BOND_NOT_FOUND u6003)
(define-constant ERR_ALREADY_REDEEMED u6004)
(define-constant ERR_NOT_MATURED u6005)
(define-constant ERR_INSUFFICIENT_FUNDS u6006)
(define-constant ERR_NOT_VERIFIER u6007)
(define-constant ERR_ALREADY_ATTESTED u6008)
(define-constant ERR_CHALLENGE_ACTIVE u6009)
(define-constant ERR_CHALLENGE_EXPIRED u6010)
(define-constant ERR_PROOF_EXPIRED u6011)
(define-constant ERR_PROOF_NOT_FOUND u6012)

;; --- Treasury & Revenue (7000-7999) ---
(define-constant ERR_TREASURY_UNAUTHORIZED u7001)
(define-constant ERR_FEE_COLLECTION_FAILED u7002)
(define-constant ERR_REVENUE_DISTRIBUTION_FAILED u7003)
(define-constant ERR_ALLOCATION_NOT_FOUND u7004)
(define-constant ERR_BUDGET_EXCEEDED u7005)

;; --- Security & Compliance (8000-8999) ---
(define-constant ERR_NON_COMPLIANT u8001)
(define-constant ERR_KYC_REQUIRED u8002)
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE u8003)
(define-constant ERR_PROOF_OF_RESERVES_FAILED u8004)
(define-constant ERR_RATE_LIMIT_TRIGGERED u8005)

;; --- Integrations & Oracle (9000-9999) ---
(define-constant ERR_ORACLE_STALE u9001)
(define-constant ERR_ORACLE_MISMATCH u9002)
(define-constant ERR_INTEGRATION_DISABLED u9003)
(define-constant ERR_ADAPTER_NOT_FOUND u9004)

;; --- Read-only lookups ---

(define-read-only (get-error-name (code uint))
  (if (is-eq code u1000)
    (ok "ERR_UNAUTHORIZED")
    (if (is-eq code u1001)
      (ok "ERR_PAUSED")
      (if (is-eq code u1002)
        (ok "ERR_INSUFFICIENT_LIQUIDITY")
        (if (is-eq code u1003)
          (ok "ERR_INVALID_AMOUNT")
          (if (is-eq code u1004)
            (ok "ERR_INSUFFICIENT_COLLATERAL")
            (if (is-eq code u1005)
              (ok "ERR_INVALID_PROOF")
              (if (is-eq code u2001)
                (ok "ERR_INVALID_TICK")
                (if (is-eq code u3001)
                  (ok "ERR_PROPOSAL_NOT_FOUND")
                  (if (is-eq code u6001)
                    (ok "ERR_BITVM2_VERIFICATION_FAILED")
                    (if (is-eq code u6007)
                      (ok "ERR_NOT_VERIFIER")
                      (if (is-eq code u7001)
                        (ok "ERR_TREASURY_UNAUTHORIZED")
                        (if (is-eq code u8001)
                          (ok "ERR_NON_COMPLIANT")
                          (if (is-eq code u9001)
                            (ok "ERR_ORACLE_STALE")
                            (ok "ERR_UNKNOWN")
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-error-domain (code uint))
  (if (< code u2000) (ok "CORE")
    (if (< code u3000) (ok "DEX_MATH")
      (if (< code u4000) (ok "GOVERNANCE")
        (if (< code u5000) (ok "AGENTS")
          (if (< code u6000) (ok "YIELD")
            (if (< code u7000) (ok "BITCOIN_BRIDGE")
              (if (< code u8000) (ok "TREASURY")
                (if (< code u9000) (ok "SECURITY")
                  (if (< code u10000) (ok "INTEGRATIONS")
                    (ok "UNKNOWN")
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)
