;; AutoVault Vault Enhanced (safe wrapper)
;; Purpose: Provide SDK-aligned on-chain entrypoints while delegating core logic
;; to the canonical implementation in .vault-production.

(use-trait sip010 .sip-010-trait.sip-010-trait)

;; Simple pass-throughs to production vault to keep all logic on-chain.

(define-public (deposit (amount uint) (token <sip010>))
  (contract-call? .vault-production deposit amount token))

(define-public (withdraw (amount uint) (token <sip010>))
  (contract-call? .vault-production withdraw amount token))

(define-read-only (get-balance (who principal))
  u0) ;; Simplified - return placeholder

(define-read-only (get-tvl)
  u0) ;; Simplified - return placeholder

