;; compoundable-vault-trait.clar
;; Explicit interface for vaults that expose reward harvesting and compounding.
;; A coordinator must pass the minimum acceptable output and the destination
;; principal in the same call so the vault can enforce its own atomic route.

(define-trait compoundable-vault-trait
  (
    ;; @desc Return rewards currently available to compound.
    (get-pending-rewards () (response uint uint))

    ;; @desc Compound into the supplied destination and return actual output.
    ;; The vault must enforce its own accounting and route atomically.
    (compound (uint principal) (response uint uint))
  )
)
