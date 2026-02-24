(define-read-only (test-c4)
    (ok {
        time: block-height,
        height: block-height,
        ;; Test primitives
        consensus-buff: (to-consensus-buff u100),
        ;; Note: secp256r1-verify usually returns bool, let's just see if it parses
        r1: (is-eq true true)
    })
)
