;; Multi-vault registry with strategy references

(define-data-var admin principal tx-sender)
(define-data-var next-index uint u0)

(define-map vaults { vault: principal } { strategy: (optional principal), active: bool })
(define-map indices { index: uint } { vault: principal })

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-public (set-admin (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (var-set admin p)
    (ok true)
  )
)

(define-public (register-vault (v principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((exists (is-some (map-get? vaults { vault: v }))))
      (if exists
        (ok false)
        (let ((i (var-get next-index)))
          (map-set vaults { vault: v } { strategy: none, active: true })
          (map-set indices { index: i } { vault: v })
          (var-set next-index (+ i u1))
          (ok true)
        )
      )
    )
  )
)

(define-public (set-vault-strategy (v principal) (s principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((item (map-get? vaults { vault: v })))
      (match item i
        (begin
          (map-set vaults { vault: v } { strategy: (some s), active: (get active i) })
          (ok true)
        )
        (err u101)
      )
    )
  )
)

(define-public (set-vault-active (v principal) (a bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u100))
    (let ((item (map-get? vaults { vault: v })))
      (match item i
        (begin
          (map-set vaults { vault: v } { strategy: (get strategy i), active: a })
          (ok true)
        )
        (err u101)
      )
    )
  )
)

(define-read-only (get-vault (v principal))
  (default-to { strategy: none, active: false } (map-get? vaults { vault: v }))
)

(define-read-only (get-vault-at (i uint))
  (let ((it (map-get? indices { index: i })))
    (match it r (ok (get vault r)) (err u101))
  )
)

(define-read-only (get-count)
  (var-get next-index)
)

;; Errors
;; u100: unauthorized
;; u101: not-found
