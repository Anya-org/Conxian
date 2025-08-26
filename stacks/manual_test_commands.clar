;; AutoVault Manual Testing Commands
;; Copy and paste these into clarinet console for interactive testing

;; === BASIC CONTRACT VERIFICATION ===

;; Test trait contracts exist
(contract-call? .sip-010-trait)
(contract-call? .strategy-trait) 
(contract-call? .vault-admin-trait)
(contract-call? .vault-trait)

;; === TOKENOMICS VERIFICATION ===

;; Check AVG token supply (should be 10,000,000)
(contract-call? .avg-token get-total-supply)

;; Check AVLP token supply (should be 5,000,000)
(contract-call? .avlp-token get-total-supply)

;; Verify token metadata
(contract-call? .avg-token get-name)
(contract-call? .avg-token get-symbol)
(contract-call? .avg-token get-decimals)

;; === VAULT FUNCTIONALITY ===

;; Get vault configuration
(contract-call? .vault get-vault-data)

;; Check vault admin functions
(contract-call? .vault get-admin)

;; Test fee structures
(contract-call? .vault get-management-fee)
(contract-call? .vault get-performance-fee)

;; === DAO GOVERNANCE ===

;; Check governance configuration
(contract-call? .dao-governance get-governance-data)

;; Verify voting parameters
(contract-call? .dao-governance get-voting-period)
(contract-call? .dao-governance get-execution-delay)

;; Test proposal thresholds
(contract-call? .dao-governance get-proposal-threshold)

;; === TREASURY MANAGEMENT ===

;; Get treasury information
(contract-call? .treasury get-treasury-info)

;; Check STX reserves for buybacks
(contract-call? .treasury get-stx-balance)

;; === DAO AUTOMATION ===

;; Verify automation configuration
(contract-call? .dao-automation get-automation-config)

;; Check market analysis parameters
(contract-call? .dao-automation get-market-thresholds)

;; Test buyback mechanisms
(contract-call? .dao-automation should-trigger-buyback)

;; === ANALYTICS ===

;; Get performance metrics
(contract-call? .analytics get-performance-data)

;; Check revenue tracking
(contract-call? .analytics get-revenue-metrics)

;; === BOUNTY SYSTEM ===

;; Verify bounty configuration
(contract-call? .bounty-system get-bounty-config)

;; Check active bounties
(contract-call? .bounty-system get-active-bounties)

;; === CREATOR TOKENS ===

;; Test creator token functionality
(contract-call? .creator-token get-creator-data tx-sender)

;; === TIMELOCK VERIFICATION ===

;; Check timelock configuration
(contract-call? .timelock get-admin)
(contract-call? .timelock get-delay)

;; === INTEGRATION TESTS ===

;; Test full deposit flow (simulated)
;; 1. Approve tokens
;; 2. Deposit to vault  
;; 3. Check share allocation
;; 4. Verify fee calculations

;; Test governance flow (simulated)
;; 1. Create proposal
;; 2. Vote on proposal
;; 3. Execute after timelock
;; 4. Verify state changes

;; Test revenue distribution (simulated)
;; 1. Generate fees
;; 2. Trigger distribution
;; 3. Check AVG holder rewards
;; 4. Verify buyback execution

