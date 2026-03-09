;; enhanced-circuit-breaker.clar
;; Conxian Protocol - Enhanced Circuit Breaker (Apex v1.1.0)
;; Implements multi-tier isolation for native and CSF-compliant external protocols.

(impl-trait .security-monitoring.circuit-breaker-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_ALREADY_SET (err u8001))
(define-constant ERR_NOT_FOUND (err u8002))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var global-pause bool false)

;; --- Maps ---
;; Tracks pause state for specific contracts
(define-map paused-contracts principal bool)

;; Tracks CSF-compliant protocols in "Isolation Mode" (Restricted liquidity)
(define-map isolated-protocols principal bool)

;; --- Authorization ---

(define-read-only (is-admin (user principal))
  (is-eq user (var-get admin))
)

;; --- Read-only Functions ---

;; @desc Returns if a contract or the entire system is paused
(define-read-only (is-contract-paused (target principal))
  (ok (or (var-get global-pause) (default-to false (map-get? paused-contracts target))))
)

;; @desc Returns if the entire protocol is globally paused
(define-read-only (is-globally-paused)
  (ok (var-get global-pause))
)

;; @desc Returns if an external CSF protocol is in isolation mode
(define-read-only (is-isolated (protocol principal))
  (ok (default-to false (map-get? isolated-protocols protocol)))
)

;; --- Public Administrative Functions ---

;; @desc Toggles the global pause state (Emergency Shutdown)
(define-public (toggle-global-pause)
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set global-pause (not (var-get global-pause)))
    (print { event: "global-pause-toggled", state: (var-get global-pause) })
    (ok (var-get global-pause))
  )
)

;; @desc Toggles pause state for a specific contract
(define-public (toggle-contract-pause (target principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? paused-contracts target))))
      (map-set paused-contracts target (not current))
      (print { event: "contract-pause-toggled", target: target, state: (not current) })
      (ok (not current))
    )
  )
)

;; @desc Toggles isolation mode for a CSF external protocol
(define-public (toggle-isolation (protocol principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (let ((current (default-to false (map-get? isolated-protocols protocol))))
      (map-set isolated-protocols protocol (not current))
      (print { event: "protocol-isolation-toggled", protocol: protocol, state: (not current) })
      (ok (not current))
    )
  )
)

;; @desc Update admin principal
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)
