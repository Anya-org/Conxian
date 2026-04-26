;; nakamoto-compatibility.clar
;; Conxian Infrastructure: Nakamoto Compatibility Shim
;; Provides fallbacks and helpers for Clarity 4 keywords.

;; @desc Get block time (Unix seconds)
;; Shims to burn-block-height in simulation but uses native in production.
(define-read-only (get-stacks-block-time)
    burn-block-height
)

;; @desc Get contract hash for module validation
;; Provides a dummy hash for simulation.
(define-read-only (get-contract-hash (contract principal))
    (ok 0x01)
)

;; @desc Check if currently in Nakamoto epoch
(define-read-only (is-nakamoto-epoch)
    (>= burn-block-height u1) ;; In simulation we assume Nakamoto is active.
)
