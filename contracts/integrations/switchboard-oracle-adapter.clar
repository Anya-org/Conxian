;; switchboard-oracle-adapter.clar
;; Conxian Oracle Standard: System Sentinel (Intelligence Layer)
;; Handles Governance Alerts, Circuit Breakers, and System Health

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7200))
(define-constant ROLE_SENTINEL u5)

;; State
(define-data-var system-alert-level uint u0) ;; 0 = Normal, 1 = Caution, 2 = Emergency
(define-data-var last-alert-message (string-ascii 64) "Status: Green")

;; @desc Pushes a system-wide alert signal (Simulating Switchboard intelligence)
(define-public (push-system-alert (level uint) (message (string-ascii 64)))
    (begin
        ;; Only the Sentinel role or DAO can call this
        (asserts! (or 
            (is-eq tx-sender (contract-call? .conxian-protocol get-admin))
            (contract-call? .rbac has-role tx-sender ROLE_SENTINEL)
        ) ERR_UNAUTHORIZED)
        
        (var-set system-alert-level level)
        (var-set last-alert-message message)
        
        (print {
            event: "system-alert-pushed",
            level: level,
            message: message,
            tenure-id: (contract-call? .block-utils get-current-tenure-id)
        })
        
        ;; If emergency, trigger protocol-wide pause
        (if (>= level u2)
            (contract-call? .conxian-protocol set-paused true)
            (ok true)
        )
    )
)

;; Read Only
(define-read-only (get-alert-status)
    (ok {
        level: (var-get system-alert-level),
        message: (var-get last-alert-message)
    })
)

(define-read-only (get-name)
    (ok "Switchboard-System-Sentinel")
)
