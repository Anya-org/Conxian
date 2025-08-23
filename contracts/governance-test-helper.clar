;; Test helper (non-production): manipulate governance proposal state for SDK tests
(define-constant ERR_AUTH (err u900))
(define-constant GOVERNANCE .dao-governance)
(define-constant ALLOWED tx-sender) ;; deployer only in simnet

(define-public (force-activate (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (ok (contract-call? .dao-governance get-proposal id))))

(define-public (force-succeed (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (ok (contract-call? .dao-governance get-proposal id))))

(define-public (force-queue (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (ok (contract-call? .dao-governance get-proposal id))))
