;; ------------------------------------------------------------
;; state-anchor.clar (Scaffold)
;; Purpose: Emit periodic state root hashes supplied by an authorized caller.
;; EVENTS:
;;   state-anchor (code u2001)
;; NOTE: Root provided externally; off-chain tool reproduces & verifies.
;; TODO (prod): replace deployer auth with governance / timelock gate.
;; ------------------------------------------------------------

(define-constant DEPLOYER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))

(define-data-var last-root (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-data-var last-height uint u0)
(define-data-var anchor-count uint u0)

(define-read-only (get-last-anchor)
  (ok { root: (var-get last-root), height: (var-get last-height), count: (var-get anchor-count) }))

(define-public (anchor-state (root (buff 32)))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR_NOT_AUTHORIZED)
    (var-set last-root root)
    (var-set last-height block-height)
    (var-set anchor-count (+ (var-get anchor-count) u1))
    (print { event: "state-anchor", code: u2001, height: block-height, root: root, count: (var-get anchor-count) })
    (ok true)))
