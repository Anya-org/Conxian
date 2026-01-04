;; swap-router.clar
;; Conxian Standard: DEX Interaction Layer
;; Entry point for swapping tokens across pools

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_SLIPPAGE (err u3000))

;; @desc Execute an exact input swap
;; @param pool-id uint
;; @param token-in <sip-010-trait>
;; @param token-out <sip-010-trait>
;; @param amount-in uint
;; @param min-amount-out uint
;; @returns (response uint uint) - amount-out
(define-public (exact-input-single
        (pool-id uint)
        (token-in <sip-010-trait>)
        (token-out <sip-010-trait>)
        (amount-in uint)
        (min-amount-out uint)
    )
    (begin
        ;; 1. Global Pause Check (Fail Fast Optimization)
        ;; By checking the system-wide pause before any other state-reading operations,
        ;; we prevent unnecessary `contract-call?` costs in the common case where the
        ;; protocol is halted. This saves one read operation on every reverted transaction.
        (asserts! (not (contract-call? .conxian-protocol is-paused)) (err u1001))
        
        (let (
            (tenure-id (contract-call? .block-utils get-current-tenure-id))
        )
            ;; 2. Pull tokens from user
            (try! (contract-call? token-in transfer amount-in tx-sender .concentrated-liquidity-pool none))
            
            ;; 3. Execute swap on pool
            ;; Note: simplified zero-for-one check based on principal matching
            (let (
                (zero-for-one true) ;; Dynamic logic would go here
                (amount-out (try! (contract-call? .concentrated-liquidity-pool swap pool-id zero-for-one amount-in)))
            )
                ;; 4. Slippage check
                (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE)

                (print {
                    event: "router-swap",
                    pool-id: pool-id,
                    user: tx-sender,
                    amount-in: amount-in,
                    amount-out: amount-out,
                    tenure-id: tenure-id
                })

                (ok amount-out)
            )
        )
    )
)
