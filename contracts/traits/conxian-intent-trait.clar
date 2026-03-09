;; conxian-intent-trait.clar
;; SIP Trait for Conxian Stacks-Native Intent Layer

(define-trait conxian-intent-solver-trait
  (
    (verify-intent-proof ((buff 1024) (buff 32) (buff 64) (buff 33)) (response bool uint))
    (execute-intent ((buff 32) (buff 1024) principal) (response bool uint))
    (register-dapp (principal (string-ascii 256)) (response bool uint))
  )
)

(define-trait conxian-liquidity-v1-trait
  (
    (provide-liquidity-intent ((buff 32) uint principal) (response bool uint))
    (settle-swap-intent ((buff 32) principal principal uint uint) (response bool uint))
  )
)
