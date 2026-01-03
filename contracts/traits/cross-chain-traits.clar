;; cross-chain-traits.clar
;; Traits for Cross-Chain Interoperability

(define-trait bridge-endpoint-trait
    (
        (send-message ((buff 256) (buff 32)) (response uint uint))
        (receive-message ((buff 1024) (buff 64)) (response bool uint))
    )
)
