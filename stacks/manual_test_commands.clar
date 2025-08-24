;; AutoVault Manual Testing Commands
;; Copy and paste these into npx clarinet console for interactive testing

;; === BASIC CONTRACT VERIFICATION ===

;; Check vault initial state
(contract-call? .vault get-total-balance)
(contract-call? .vault get-total-shares)
(contract-call? .vault get-paused)
(contract-call? .vault get-admin)

;; === VAULT FUNCTIONALITY ===

;; Test basic vault functions
(contract-call? .vault get-fees)
(contract-call? .vault get-treasury)
(contract-call? .vault get-token)
(contract-call? .vault get-utilization)

;; Test deposit functionality (10 STX)
(contract-call? .vault deposit u10000000 .mock-ft)

;; Check vault state after deposit
(contract-call? .vault get-total-balance)
(contract-call? .vault get-total-shares)
(contract-call? .vault get-shares tx-sender)

;; Test share calculations
(contract-call? .vault calculate-shares-precise u5000000)
(contract-call? .vault calculate-balance-precise u5000000)

;; === TREASURY MANAGEMENT ===

;; Test treasury functions
(contract-call? .treasury get-treasury-balance)
(contract-call? .treasury get-treasury-summary)
(contract-call? .treasury is-dao-or-admin)

;; === MATH LIBRARY TESTS ===

;; Test mathematical functions
(contract-call? .math-lib sqrt-uint u10000)
(contract-call? .math-lib geometric-mean u100 u200)
(contract-call? .math-lib get-math-constants)

;; === ORACLE SYSTEM ===

;; Test oracle aggregator
(contract-call? .oracle-aggregator get-admin)

;; === MOCK TOKEN TESTS ===

;; Test mock FT functionality
(contract-call? .mock-ft get-total-supply)
(contract-call? .mock-ft get-balance-of tx-sender)
(contract-call? .mock-ft get-name)
(contract-call? .mock-ft get-symbol)

;; === WITHDRAWAL TESTS ===

;; Test withdrawal (5 STX worth)
(contract-call? .vault withdraw u5000000 .mock-ft)

;; Check final state
(contract-call? .vault get-total-balance)
(contract-call? .vault get-shares tx-sender)

;; === INTEGRATION TESTS ===

;; Full cycle test: Deposit -> Check -> Withdraw -> Verify

