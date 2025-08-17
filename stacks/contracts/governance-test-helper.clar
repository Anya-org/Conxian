;; Test helper (non-production): manipulate governance proposal state for SDK tests
(define-constant ERR_AUTH (err u900))
(define-constant GOVERNANCE .dao-governance)
(define-constant ALLOWED tx-sender) ;; deployer only in simnet

(define-public (force-activate (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (let ((p (unwrap! (contract-call? GOVERNANCE get-proposal id) (err u901))))
      (let ((updated (merge p { start-block: u0, end-block: (+ block-height u200), state: u1 })))
        (map-set dao-governance.proposals { id: id } updated)
        (ok true))))

(define-public (force-succeed (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (let ((p (unwrap! (contract-call? GOVERNANCE get-proposal id) (err u901))))
      (let ((updated (merge p { state: u2 })))
        (map-set dao-governance.proposals { id: id } updated)
        (ok true))))

(define-public (force-queue (id uint))
  (begin
    (asserts! (is-eq tx-sender ALLOWED) ERR_AUTH)
    (let ((p (unwrap! (contract-call? GOVERNANCE get-proposal id) (err u901))))
      (let ((updated (merge p { state: u4, execution-block: block-height }) ))
        (map-set dao-governance.proposals { id: id } updated)
        (ok true))))
