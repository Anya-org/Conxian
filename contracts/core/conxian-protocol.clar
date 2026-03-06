;; conxian-protocol.clar
;; Core Facade for Conxian Protocol - Nakamoto Aligned
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_PAUSED u1001)

(define-data-var paused bool false)
(define-data-var contract-owner principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

(define-map modules { name: (string-ascii 32) } { contract: principal, active: bool, hash: (optional (buff 32)) })

;; @desc Get global protocol status
(define-read-only (get-protocol-status)
  (ok { compliant: true, paused: (var-get paused), tenure-id: (some (/ block-height u10)), timestamp: burn-block-height, version: "07" })
)

;; @desc Set paused
(define-public (set-paused (new-paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set paused new-paused)
    (ok true)
  )
)

;; @desc Pause the protocol
(define-public (pause)
  (set-paused true)
)

;; @desc Unpause the protocol
(define-public (unpause)
  (set-paused false)
)

;; @desc Register module
(define-public (register-module (name (string-ascii 32)) (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set modules { name: name } { contract: contract, active: true, hash: (some 0x0000000000000000000000000000000000000000000000000000000000000000) })
    (ok true)
  )
)

;; @desc Get module principal by name
(define-read-only (get-module (name (string-ascii 32))) (map-get? modules { name: name }))

;; @desc Check if protocol is paused
(define-read-only (is-paused) (var-get paused))

;; @desc Get protocol owner principal
(define-read-only (get-protocol-owner) (var-get contract-owner))

;; @desc Get protocol admin principal
(define-read-only (get-protocol-admin) (var-get contract-owner))

;; @desc Legacy admin lookup
(define-read-only (get-admin) (var-get contract-owner))
