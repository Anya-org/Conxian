;; bns-stub.clar
;; Mock for the Bitcoin Name System (BNS)

(define-map names { namespace: (buff 20), name: (buff 48) } { owner: principal, lease-ending-at: (optional uint) })
(define-map owner-to-name principal { namespace: (buff 20), name: (buff 48) })

;; --- Admin ---

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; --- BNS Mock Implementation ---

(define-read-only (resolve-principal (voter principal))
  (map-get? owner-to-name voter)
)

;; Admin function to seed BNS names for testing
(define-public (seed-bns-name (owner principal) (namespace (buff 20)) (name (buff 48)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set names { namespace: namespace, name: name } { owner: owner, lease-ending-at: none })
    (map-set owner-to-name owner { namespace: namespace, name: name })
    (ok true)
  )
)
