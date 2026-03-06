;; Standard Pausable Contract
(define-data-var paused bool false)
(define-public (is-paused) (ok (var-get paused)))
(define-public (set-paused (new-state bool)) (begin (var-set paused new-state) (ok true)))
