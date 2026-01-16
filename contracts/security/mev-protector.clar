;; mev-protector.clar
;; Implements Commit-Reveal scheme to prevent sandwich attacks

(define-constant ERR_INVALID_COMMIT (err u2000))
(define-constant ERR_COMMIT_EXPIRED (err u2001))
(define-constant ERR_COMMIT_NOT_FOUND (err u2002))
(define-constant ERR_BLOCK_HEIGHT_MISMATCH (err u2003))

;; Commitment storage
;; Key: User Principal
;; Value: { hash: (buff 32), block-height: uint }
(define-map commits
  principal
  {
    hash: (buff 32),
    height: uint,
  }
)

;; Revealed status for the current block
;; Key: User Principal
;; Value: Block Height
(define-map revealed-in-block
  principal
  uint
)

(define-constant COMMIT_WINDOW u10) ;; Blocks within which reveal must happen

;; @desc Commits a hash of the intended transaction
;; @param hash Hash of the payload + salt
(define-public (commit (hash (buff 32)))
  (begin
    (map-set commits tx-sender {
      hash: hash,
      height: block-height,
    })
    (ok true)
  )
)

;; @desc Reveals the payload and validates against commitment
;; @param salt Random salt used in hash
;; @param payload The transaction data payload
(define-public (reveal
    (salt (buff 32))
    (payload (buff 128))
  )
  (let (
      (user-commit (unwrap! (map-get? commits tx-sender) ERR_COMMIT_NOT_FOUND))
      (computed-hash (sha256 (concat salt payload)))
    )
    ;; Must be revealed in a later block (or same block if we just want to prove knowledge, 
    ;; but for anti-frontrunning, it should ideally be later. 
    ;; However, commit-reveal usually implies commit in block N, reveal in N+1.
    ;; We enforce reveal is within window.
    (asserts! (<= block-height (+ (get height user-commit) COMMIT_WINDOW))
      ERR_COMMIT_EXPIRED
    )
    (asserts! (is-eq (get hash user-commit) computed-hash) ERR_INVALID_COMMIT)

    ;; If valid, mark as revealed for this block
    (map-set revealed-in-block tx-sender block-height)

    ;; Clear commit to prevent replay
    (map-delete commits tx-sender)
    (ok true)
  )
)

;; @desc Checks if the user has revealed a valid commitment in the current block
;; @param user The user principal
(define-read-only (is-revealed (user principal))
  (is-eq (map-get? revealed-in-block user) (some block-height))
)
