;; bns-stub.clar

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
  (ok true)
)
