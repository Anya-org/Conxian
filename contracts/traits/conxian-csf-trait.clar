;; conxian-csf-trait.clar
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(define-trait trait-csf-liquidity-v1 (
  (register-liquidity-marker ((string-ascii 256)) (response bool uint))
  (execute-csf-swap (<sip-010-trait> <sip-010-trait> uint principal) (response { amount-out: uint  fee-collected: uint } uint))
  (request-flash-liquidity (<sip-010-trait> uint (buff 32)) (response bool uint))
  (settle-arbitrage (<sip-010-trait> <sip-010-trait> uint (list 10 principal)) (response uint uint))
  (claim-conxian-yield (<sip-010-trait> uint principal) (response uint uint))
  (get-csf-health () (response { tvl: uint  utilization: uint  is-active: bool } uint))
))
