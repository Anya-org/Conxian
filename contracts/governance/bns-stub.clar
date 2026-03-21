;; bns-stub.clar
;; Mock for the Bitcoin Name System (BNS)

(define-map names { namespace: (buff 20), name: (buff 48) } { owner: principal, lease-ending-at: (optional uint) })
(define-map owner-to-name principal { namespace: (buff 20), name: (buff 48) })

;; --- BNS Mock Implementation ---

(define-read-only (resolve-principal (voter principal))
  (map-get? owner-to-name voter)
)

;; Admin function to seed BNS names for testing
(define-public (seed-bns-name (owner principal) (namespace (buff 20)) (name (buff 48)))
  (begin
    (map-set names { namespace: namespace, name: name } { owner: owner, lease-ending-at: none })
    (map-set owner-to-name owner { namespace: namespace, name: name })
    (ok true)
  )
)
