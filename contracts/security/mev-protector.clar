;; mev-protector.clar
;; Implements Commit-Reveal scheme to prevent sandwich attacks

(define-constant ERR_INVALID_COMMIT (err u2000))
(define-constant ERR_COMMIT_EXPIRED (err u2001))
(define-constant ERR_COMMIT_NOT_FOUND (err u2002))
(define-constant ERR_BLOCK_HEIGHT_MISMATCH (err u2003))

;; Commitment storage
;; Key: User Principal
;; Value: { hash: (buff 32), block-height: uint }
(define-map commits principal { hash: (buff 32), height: uint })

(define-constant COMMIT_WINDOW u10) ;; Blocks within which reveal must happen

(define-public (commit (hash (buff 32)))
    (begin
        (map-set commits tx-sender { hash: hash, height: block-height })
        (ok true)
    )
)

(define-public (reveal (salt (buff 32)) (payload (buff 128)))
    (let (
        (user-commit (unwrap! (map-get? commits tx-sender) ERR_COMMIT_NOT_FOUND))
        (computed-hash (sha256 (concat salt payload)))
    )
        (asserts! (<= block-height (+ (get height user-commit) COMMIT_WINDOW)) ERR_COMMIT_EXPIRED)
        (asserts! (is-eq (get hash user-commit) computed-hash) ERR_INVALID_COMMIT)
        
        ;; If valid, clear commit to prevent replay
        (map-delete commits tx-sender)
        (ok true)
    )
)

;; Read-only helper to verify a commit exists and is valid for the current block
(define-read-only (has-valid-commit (user principal))
    (match (map-get? commits user)
        commit-data (<= block-height (+ (get height commit-data) COMMIT_WINDOW))
        false
    )
)
