;; Error Codes Library
;; Centralized error code definitions for the Conxian Protocol

;; General Errors (1000-1999)
(define-constant ERR_INVALID_AMOUNT u1001)
(define-constant ERR_INSUFFICIENT_BALANCE u1002)
(define-constant ERR_UNAUTHORIZED u1003)
(define-constant ERR_INVALID_ADDRESS u1004)
(define-constant ERR_INVALID_TIMESTAMP u1005)
(define-constant ERR_CONTRACT_NOT_FOUND u1006)
(define-constant ERR_OPERATION_FAILED u1007)
(define-constant ERR_INVALID_INPUT u1008)
(define-constant ERR_RATE_LIMITED u1009)
(define-constant ERR_MAINTENANCE_MODE u1010)

;; Token Errors (2000-2999)
(define-constant ERR_TOKEN_NOT_FOUND u2001)
(define-constant ERR_INSUFFICIENT_TOKENS u2002)
(define-constant ERR_INVALID_TOKEN_ID u2003)
(define-constant ERR_TOKEN_ALREADY_EXISTS u2004)
(define-constant ERR_INVALID_TOKEN_URI u2005)
(define-constant ERR_TOKEN_TRANSFER_FAILED u2006)
(define-constant ERR_TOKEN_MINT_FAILED u2007)
(define-constant ERR_TOKEN_BURN_FAILED u2008)
(define-constant ERR_INVALID_APPROVAL u2009)
(define-constant ERR_APPROVAL_EXPIRED u2010)

;; NFT Errors (3000-3999)
(define-constant ERR_NFT_NOT_FOUND u3001)
(define-constant ERR_NFT_ALREADY_EXISTS u3002)
(define-constant ERR_NFT_TRANSFER_FAILED u3003)
(define-constant ERR_NFT_MINT_FAILED u3004)
(define-constant ERR_NFT_BURN_FAILED u3005)
(define-constant ERR_INVALID_NFT_ID u3006)
(define-constant ERR_NFT_NOT_OWNER u3007)
(define-constant ERR_NFT_LOCKED u3008)
(define-constant ERR_INVALID_NFT_URI u3009)
(define-constant ERR_NFT_APPROVAL_FAILED u3010)

;; DEX Errors (4000-4999)
(define-constant ERR_INVALID_POOL u4001)
(define-constant ERR_POOL_NOT_FOUND u4002)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u4003)
(define-constant ERR_INVALID_TRADE_AMOUNT u4004)
(define-constant ERR_SLIPPAGE_TOO_HIGH u4005)
(define-constant ERR_INVALID_TICK_RANGE u4006)
(define-constant ERR_TICK_OUT_OF_BOUNDS u4007)
(define-constant ERR_INVALID_PRICE u4008)
(define-constant ERR_TRADE_FAILED u4009)
(define-constant ERR_POOL_LOCKED u4010)

;; Oracle Errors (5000-5999)
(define-constant ERR_ORACLE_NOT_FOUND u5001)
(define-constant ERR_ORACLE_STALE u5002)
(define-constant ERR_INVALID_ORACLE_DATA u5003)
(define-constant ERR_ORACLE_UNAUTHORIZED u5004)
(define-constant ERR_ORACLE_OFFLINE u5005)
(define-constant ERR_INVALID_FEED_ID u5006)
(define-constant ERR_FEED_NOT_ACTIVE u5007)
(define-constant ERR_CONFIDENCE_TOO_LOW u5008)
(define-constant ERR_UPDATE_TOO_FREQUENT u5009)
(define-constant ERR_ORACLE_TIMEOUT u5010)

;; Governance Errors (6000-6999)
(define-constant ERR_PROPOSAL_NOT_FOUND u6001)
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED u6002)
(define-constant ERR_VOTING_PERIOD_ENDED u6003)
(define-constant ERR_INSUFFICIENT_VOTING_POWER u6004)
(define-constant ERR_ALREADY_VOTED u6005)
(define-constant ERR_QUORUM_NOT_MET u6006)
(define-constant ERR_INVALID_PROPOSAL_TYPE u6007)
(define-constant ERR_PROPOSAL_CANCELLED u6008)
(define-constant ERR_EXECUTION_FAILED u6009)
(define-constant ERR_INVALID_VOTER u6010)

;; Treasury Errors (7000-7999)
(define-constant ERR_INSUFFICIENT_TREASURY_BALANCE u7001)
(define-constant ERR_INVALID_ALLOCATION u7002)
(define-constant ERR_ALLOCATION_EXCEEDED u7003)
(define-constant ERR_INVALID_RECIPIENT u7004)
(define-constant ERR_DISTRIBUTION_FAILED u7005)
(define-constant ERR_TREASURY_LOCKED u7006)
(define-constant ERR_INVALID_CATEGORY u7007)
(define-constant ERR_CATEGORY_NOT_FOUND u7008)
(define-constant ERR_REBALANCE_FAILED u7009)
(define-constant ERR_EMERGENCY_MODE u7010)

;; Staking Errors (8000-8999)
(define-constant ERR_STAKE_NOT_FOUND u8001)
(define-constant ERR_STAKE_ALREADY_EXISTS u8002)
(define-constant ERR_STAKE_LOCKED u8003)
(define-constant ERR_INVALID_LOCK_PERIOD u8004)
(define-constant ERR_MIN_STAKE_AMOUNT u8005)
(define-constant ERR_MAX_STAKE_AMOUNT u8006)
(define-constant ERR_STAKE_PERIOD_ENDED u8007)
(define-constant ERR_REWARDS_CALCULATION_FAILED u8008)
(define-constant ERR_NO_REWARDS_AVAILABLE u8009)
(define-constant ERR_STAKE_EXTENSION_FAILED u8010)

;; Lending Errors (9000-9999)
(define-constant ERR_POSITION_NOT_FOUND u9001)
(define-constant ERR_INSUFFICIENT_COLLATERAL u9002)
(define-constant ERR_POSITION_LIQUIDATED u9003)
(define-constant ERR_INVALID_LOAN_AMOUNT u9004)
(define-constant ERR_INTEREST_RATE_INVALID u9005)
(define-constant ERR_COLLATERAL_RATIO_TOO_LOW u9006)
(define-constant ERR_LIQUIDATION_FAILED u9007)
(define-constant ERR_POSITION_CLOSED u9008)
(define-constant ERR_INVALID_ASSET u9009)
(define-constant ERR_LEVERAGE_TOO_HIGH u9010)

;; Compliance Errors (10000-10999)
(define-constant ERR_COMPLIANCE_CHECK_FAILED u10001)
(define-constant ERR_KYC_REQUIRED u10002)
(define-constant ERR_SANCTIONED_ADDRESS u10003)
(define-constant ERR_REGION_RESTRICTED u10004)
(define-constant ERR_TRANSACTION_LIMIT_EXCEEDED u10005)
(define-constant ERR_INVALID_VERIFICATION u10006)
(define-constant ERR_COMPLIANCE_OFFLINE u10007)
(define-constant ERR_RISK_SCORE_TOO_HIGH u10008)
(define-constant ERR_DOCUMENTATION_REQUIRED u10009)
(define-constant ERR_REGULATORY_HOLD u10010)

;; Security Errors (11000-11999)
(define-constant ERR_CIRCUIT_BREAKER_TRIGGERED u11001)
(define-constant ERR_RATE_LIMIT_EXCEEDED u11002)
(define-constant ERR_SUSPICIOUS_ACTIVITY u11003)
(define-constant ERR_BLACKLISTED_ADDRESS u11004)
(define-constant ERR_INVALID_SIGNATURE u11005)
(define-constant ERR_REPLAY_ATTACK u11006)
(define-constant ERR_FRONT_RUNNING_DETECTED u11007)
(define-constant ERR_MEV_PROTECTION_FAILED u11008)
(define-constant ERR_SECURITY_BREACH u11009)
(define-constant ERR_EMERGENCY_SHUTDOWN u11010)

;; System Errors (12000-12999)
(define-constant ERR_SYSTEM_OVERLOAD u12001)
(define-constant ERR_DATABASE_ERROR u12002)
(define-constant ERR_NETWORK_ERROR u12003)
(define-constant ERR_CONTRACT_UPGRADE u12004)
(define-constant ERR_MIGRATION_FAILED u12005)
(define-constant ERR_BACKUP_FAILED u12006)
(define-constant ERR_RECOVERY_FAILED u12007)
(define-constant ERR_CONFIGURATION_ERROR u12008)
(define-constant ERR_VERSION_MISMATCH u12009)
(define-constant ERR_UNKNOWN_ERROR u12010)

;; Error message functions
(define-read-only (get-error-message (error-code uint))
  (match error-code
    ERR_INVALID_AMOUNT "Invalid amount provided"
    ERR_INSUFFICIENT_BALANCE "Insufficient balance"
    ERR_UNAUTHORIZED "Unauthorized access"
    ERR_INVALID_ADDRESS "Invalid address"
    ERR_INVALID_TIMESTAMP "Invalid timestamp"
    ERR_CONTRACT_NOT_FOUND "Contract not found"
    ERR_OPERATION_FAILED "Operation failed"
    ERR_INVALID_INPUT "Invalid input"
    ERR_RATE_LIMITED "Rate limited"
    ERR_MAINTENANCE_MODE "System in maintenance mode"
    
    ERR_TOKEN_NOT_FOUND "Token not found"
    ERR_INSUFFICIENT_TOKENS "Insufficient tokens"
    ERR_INVALID_TOKEN_ID "Invalid token ID"
    ERR_TOKEN_ALREADY_EXISTS "Token already exists"
    ERR_INVALID_TOKEN_URI "Invalid token URI"
    ERR_TOKEN_TRANSFER_FAILED "Token transfer failed"
    ERR_TOKEN_MINT_FAILED "Token mint failed"
    ERR_TOKEN_BURN_FAILED "Token burn failed"
    ERR_INVALID_APPROVAL "Invalid approval"
    ERR_APPROVAL_EXPIRED "Approval expired"
    
    ERR_NFT_NOT_FOUND "NFT not found"
    ERR_NFT_ALREADY_EXISTS "NFT already exists"
    ERR_NFT_TRANSFER_FAILED "NFT transfer failed"
    ERR_NFT_MINT_FAILED "NFT mint failed"
    ERR_NFT_BURN_FAILED "NFT burn failed"
    ERR_INVALID_NFT_ID "Invalid NFT ID"
    ERR_NFT_NOT_OWNER "Not NFT owner"
    ERR_NFT_LOCKED "NFT locked"
    ERR_INVALID_NFT_URI "Invalid NFT URI"
    ERR_NFT_APPROVAL_FAILED "NFT approval failed"
    
    ERR_INVALID_POOL "Invalid pool"
    ERR_POOL_NOT_FOUND "Pool not found"
    ERR_INSUFFICIENT_LIQUIDITY "Insufficient liquidity"
    ERR_INVALID_TRADE_AMOUNT "Invalid trade amount"
    ERR_SLIPPAGE_TOO_HIGH "Slippage too high"
    ERR_INVALID_TICK_RANGE "Invalid tick range"
    ERR_TICK_OUT_OF_BOUNDS "Tick out of bounds"
    ERR_INVALID_PRICE "Invalid price"
    ERR_TRADE_FAILED "Trade failed"
    ERR_POOL_LOCKED "Pool locked"
    
    ERR_ORACLE_NOT_FOUND "Oracle not found"
    ERR_ORACLE_STALE "Oracle data stale"
    ERR_INVALID_ORACLE_DATA "Invalid oracle data"
    ERR_ORACLE_UNAUTHORIZED "Oracle unauthorized"
    ERR_ORACLE_OFFLINE "Oracle offline"
    ERR_INVALID_FEED_ID "Invalid feed ID"
    ERR_FEED_NOT_ACTIVE "Feed not active"
    ERR_CONFIDENCE_TOO_LOW "Confidence too low"
    ERR_UPDATE_TOO_FREQUENT "Update too frequent"
    ERR_ORACLE_TIMEOUT "Oracle timeout"
    
    ERR_PROPOSAL_NOT_FOUND "Proposal not found"
    ERR_PROPOSAL_ALREADY_EXECUTED "Proposal already executed"
    ERR_VOTING_PERIOD_ENDED "Voting period ended"
    ERR_INSUFFICIENT_VOTING_POWER "Insufficient voting power"
    ERR_ALREADY_VOTED "Already voted"
    ERR_QUORUM_NOT_MET "Quorum not met"
    ERR_INVALID_PROPOSAL_TYPE "Invalid proposal type"
    ERR_PROPOSAL_CANCELLED "Proposal cancelled"
    ERR_EXECUTION_FAILED "Execution failed"
    ERR_INVALID_VOTER "Invalid voter"
    
    ERR_INSUFFICIENT_TREASURY_BALANCE "Insufficient treasury balance"
    ERR_INVALID_ALLOCATION "Invalid allocation"
    ERR_ALLOCATION_EXCEEDED "Allocation exceeded"
    ERR_INVALID_RECIPIENT "Invalid recipient"
    ERR_DISTRIBUTION_FAILED "Distribution failed"
    ERR_TREASURY_LOCKED "Treasury locked"
    ERR_INVALID_CATEGORY "Invalid category"
    ERR_CATEGORY_NOT_FOUND "Category not found"
    ERR_REBALANCE_FAILED "Rebalance failed"
    ERR_EMERGENCY_MODE "Emergency mode"
    
    ERR_STAKE_NOT_FOUND "Stake not found"
    ERR_STAKE_ALREADY_EXISTS "Stake already exists"
    ERR_STAKE_LOCKED "Stake locked"
    ERR_INVALID_LOCK_PERIOD "Invalid lock period"
    ERR_MIN_STAKE_AMOUNT "Minimum stake amount"
    ERR_MAX_STAKE_AMOUNT "Maximum stake amount"
    ERR_STAKE_PERIOD_ENDED "Stake period ended"
    ERR_REWARDS_CALCULATION_FAILED "Rewards calculation failed"
    ERR_NO_REWARDS_AVAILABLE "No rewards available"
    ERR_STAKE_EXTENSION_FAILED "Stake extension failed"
    
    ERR_POSITION_NOT_FOUND "Position not found"
    ERR_INSUFFICIENT_COLLATERAL "Insufficient collateral"
    ERR_POSITION_LIQUIDATED "Position liquidated"
    ERR_INVALID_LOAN_AMOUNT "Invalid loan amount"
    ERR_INTEREST_RATE_INVALID "Invalid interest rate"
    ERR_COLLATERAL_RATIO_TOO_LOW "Collateral ratio too low"
    ERR_LIQUIDATION_FAILED "Liquidation failed"
    ERR_POSITION_CLOSED "Position closed"
    ERR_INVALID_ASSET "Invalid asset"
    ERR_LEVERAGE_TOO_HIGH "Leverage too high"
    
    ERR_COMPLIANCE_CHECK_FAILED "Compliance check failed"
    ERR_KYC_REQUIRED "KYC required"
    ERR_SANCTIONED_ADDRESS "Sanctioned address"
    ERR_REGION_RESTRICTED "Region restricted"
    ERR_TRANSACTION_LIMIT_EXCEEDED "Transaction limit exceeded"
    ERR_INVALID_VERIFICATION "Invalid verification"
    ERR_COMPLIANCE_OFFLINE "Compliance offline"
    ERR_RISK_SCORE_TOO_HIGH "Risk score too high"
    ERR_DOCUMENTATION_REQUIRED "Documentation required"
    ERR_REGULATORY_HOLD "Regulatory hold"
    
    ERR_CIRCUIT_BREAKER_TRIGGERED "Circuit breaker triggered"
    ERR_RATE_LIMIT_EXCEEDED "Rate limit exceeded"
    ERR_SUSPICIOUS_ACTIVITY "Suspicious activity"
    ERR_BLACKLISTED_ADDRESS "Blacklisted address"
    ERR_INVALID_SIGNATURE "Invalid signature"
    ERR_REPLAY_ATTACK "Replay attack"
    ERR_FRONT_RUNNING_DETECTED "Front running detected"
    ERR_MEV_PROTECTION_FAILED "MEV protection failed"
    ERR_SECURITY_BREACH "Security breach"
    ERR_EMERGENCY_SHUTDOWN "Emergency shutdown"
    
    ERR_SYSTEM_OVERLOAD "System overload"
    ERR_DATABASE_ERROR "Database error"
    ERR_NETWORK_ERROR "Network error"
    ERR_CONTRACT_UPGRADE "Contract upgrade"
    ERR_MIGRATION_FAILED "Migration failed"
    ERR_BACKUP_FAILED "Backup failed"
    ERR_RECOVERY_FAILED "Recovery failed"
    ERR_CONFIGURATION_ERROR "Configuration error"
    ERR_VERSION_MISMATCH "Version mismatch"
    ERR_UNKNOWN_ERROR "Unknown error"
    
    "Unknown error code"
  )
)

;; Error category functions
(define-read-only (get-error-category (error-code uint))
  (if (< error-code u2000)
      "General"
      (if (< error-code u3000)
          "Token"
          (if (< error-code u4000)
              "NFT"
              (if (< error-code u5000)
                  "DEX"
                  (if (< error-code u6000)
                      "Oracle"
                      (if (< error-code u7000)
                          "Governance"
                          (if (< error-code u8000)
                              "Treasury"
                              (if (< error-code u9000)
                                  "Staking"
                                  (if (< error-code u10000)
                                      "Lending"
                                      (if (< error-code u11000)
                                          "Compliance"
                                          (if (< error-code u12000)
                                              "Security"
                                              "System"
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

;; Error severity functions
(define-read-only (get-error-severity (error-code uint))
  (match error-code
    ERR_SYSTEM_OVERLOAD "Critical"
    ERR_SECURITY_BREACH "Critical"
    ERR_EMERGENCY_SHUTDOWN "Critical"
    ERR_CIRCUIT_BREAKER_TRIGGERED "High"
    ERR_INSUFFICIENT_COLLATERAL "High"
    ERR_POSITION_LIQUIDATED "High"
    ERR_COMPLIANCE_CHECK_FAILED "High"
    ERR_SANCTIONED_ADDRESS "High"
    ERR_RATE_LIMIT_EXCEEDED "Medium"
    ERR_INSUFFICIENT_BALANCE "Medium"
    ERR_INSUFFICIENT_TOKENS "Medium"
    ERR_INSUFFICIENT_LIQUIDITY "Medium"
    ERR_ORACLE_STALE "Medium"
    ERR_VOTING_PERIOD_ENDED "Low"
    ERR_ALREADY_VOTED "Low"
    ERR_INVALID_AMOUNT "Low"
    ERR_INVALID_INPUT "Low"
    "Unknown"
  )
)
