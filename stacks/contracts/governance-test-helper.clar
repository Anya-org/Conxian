;; Test helper (non-production): manipulate governance proposal state for SDK tests
(define-constant ERR_AUTH (err u900))
(define-constant GOVERNANCE .dao-governance)
(define-constant ALLOWED tx-sender) ;; deployer only in simnet

(define-public (test-get-proposal (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    ;; Use gov-token contract call instead of dao-governance to avoid circular dependency
    (ok true))) ;; Simplified for now to break circular dependency

(define-public (force-succeed (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    ;; Simplified to avoid circular dependency
    (ok true)))

(define-public (force-queue (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    ;; Simplified to avoid circular dependency
    (ok true)))
