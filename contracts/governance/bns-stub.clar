;; bns-stub.clar
;; Mock for the Bitcoin Name System (BNS)

(define-map names { namespace: (buff 20) name: (buff 48) } { owner: principal lease-ending-at: (optional uint) })
(define-map owner-to-name principal { namespace: (buff 20) name: (buff 48) })

;; --- BNS Mock Implementation ---

;; @desc Resolves a principal from a BNS-like voter registry.
;; @param voter: The principal to resolve.
(define-read-only (resolve-principal (voter principal))
  (ok voter)
)

;; @desc Seeds a BNS name for simulation and testing purposes.
;; @param owner: The owner of the seeded name.
;; @param namespace: The BNS namespace.
;; @param name: The BNS name.
(define-public (seed-bns-name (owner principal) (namespace (buff 20)) (name (buff 48)))
  (begin
    (map-set names { namespace: namespace name: name } { owner: owner lease-ending-at: none })
    (map-set owner-to-name owner { namespace: namespace name: name })
    (ok true)
  )
)
