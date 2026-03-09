;; conxian-intent-trait.clar
;; SIP Trait for Conxian Stacks-Native Intent Layer
;; Aligned with Hardware Security (TEE/StrongBox)

(define-trait conxian-intent-solver-trait
  (
    ;; @desc Verify a cross-chain state proof or message
    ;; Uses standardized hardware-friendly signature structure
    (verify-intent-proof (state-proof (buff 2048)) (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))

    ;; @desc Execute an intent on-chain
    ;; @params intent-id, payload (encoded intent), solver-principal
    (execute-intent (intent-id (buff 32)) (payload (buff 1024)) (solver principal))

    ;; @desc Register a third-party dApp for BME fee routing
    (register-dapp (dapp-principal principal) (metadata-uri (string-ascii 256)))
  )
)

(define-trait conxian-liquidity-v1-trait
  (
    ;; @desc Provide liquidity natively via an intent
    (provide-liquidity-intent (intent-id (buff 32)) (amount uint) (token principal))

    ;; @desc Settle a swap intent
    (settle-swap-intent (intent-id (buff 32)) (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))
  )
)
