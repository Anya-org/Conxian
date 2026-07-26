;; mock-admin-forwarder.clar
;;
;; Simnet-only forwarding contract used to prove that privileged yield
;; functions authenticate the immediate caller rather than tx-sender. The
;; functions are intentionally public and untrusted; configuring this contract
;; as an admin is the explicit controlled-forwarding test case.

(use-trait compoundable-vault-trait .compoundable-vault-trait.compoundable-vault-trait)

(define-public (forward-staking-set-admin (new-admin principal))
  (contract-call? .cxd-staking set-admin new-admin)
)

(define-public (forward-staking-set-reward-rate (rate uint))
  (contract-call? .cxd-staking set-reward-rate rate)
)

(define-public (forward-staking-set-cooldown-blocks (blocks uint))
  (contract-call? .cxd-staking set-cooldown-blocks blocks)
)

(define-public (forward-staking-set-paused (paused bool))
  (contract-call? .cxd-staking set-paused paused)
)

(define-public (forward-clp-create-pool
    (token-0 principal)
    (token-1 principal)
    (fee uint)
    (initial-price uint)
    (initial-tick int)
  )
  (contract-call?
    .concentrated-liquidity-pool
    create-pool
    token-0
    token-1
    fee
    initial-price
    initial-tick
  )
)

(define-public (forward-staking-fund-rewards (amount uint))
  ;; Make the forwarding contract the transaction sender for its own token
  ;; balance while preserving it as cxd-staking's immediate caller.
  (as-contract (contract-call? .cxd-staking fund-rewards amount))
)

(define-public (forward-auto-set-admin (new-admin principal))
  (contract-call? .auto-compounder set-admin new-admin)
)

(define-public (forward-auto-register-vault
    (vault <compoundable-vault-trait>)
    (destination-vault principal)
    (trigger-mode uint)
    (min-interval uint)
    (min-reward-threshold uint)
    (min-output uint)
    (enabled bool)
  )
  (contract-call?
    .auto-compounder
    register-vault
    vault
    destination-vault
    trigger-mode
    min-interval
    min-reward-threshold
    min-output
    enabled
  )
)

(define-public (forward-auto-update-vault-config
    (vault <compoundable-vault-trait>)
    (destination-vault principal)
    (trigger-mode uint)
    (min-interval uint)
    (min-reward-threshold uint)
    (min-output uint)
    (enabled bool)
  )
  (contract-call?
    .auto-compounder
    update-vault-config
    vault
    destination-vault
    trigger-mode
    min-interval
    min-reward-threshold
    min-output
    enabled
  )
)

(define-public (forward-auto-set-vault-enabled
    (vault <compoundable-vault-trait>)
    (enabled bool)
  )
  (contract-call? .auto-compounder set-vault-enabled vault enabled)
)

(define-public (forward-auto-compound (vault <compoundable-vault-trait>))
  (contract-call? .auto-compounder compound vault)
)
