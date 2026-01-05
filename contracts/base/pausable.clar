;; pausable.clar
;; Standard Pausable Contract & Trait
;; Allows authorized roles to pause/unpause contract functionality

(define-trait pausable-trait (
    (is-paused
        ()
        (response bool uint)
    )
))

(define-data-var paused bool false)
(define-constant ERR_PAUSED (err u1001))
(define-constant ERR_NOT_PAUSED (err u1002))
(define-constant ERR_UNAUTHORIZED (err u1000))

(define-data-var admin principal tx-sender)

(define-read-only (is-paused)
    (ok (var-get paused))
)

(define-public (pause)
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set paused true)
        (ok true)
    )
)

(define-public (unpause)
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
        (var-set paused false)
        (ok true)
    )
)