;; File: contracts/traits/pausable-trait.clar
(define-trait pausable-trait
  (
    (is-paused () (response bool uint))
    (set-paused (bool) (response bool uint))
  )
)
