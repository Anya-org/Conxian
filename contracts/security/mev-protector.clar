;; mev-protector.clar
;; Implements Commit-Reveal scheme to prevent sandwich attacks

(define-constant ERR_INVALID_COMMIT u2000)
(define-constant ERR_COMMIT_EXPIRED u2001)
(define-constant ERR_COMMIT_NOT_FOUND u2002)
(define-constant ERR_BLOCK_HEIGHT_MISMATCH u2003)

;; Commitment storage
(define-map commits principal { hash: (buff 32), height: uint })

;; Revealed status for the current block
(define-map revealed-in-block principal uint)

(define-map auction-bids { block: uint, user: principal } { payload: (buff 128), bid: uint })

(define-constant COMMIT_WINDOW u10)

;; @desc Commits a hash of the intended transaction
(define-public (commit (hash (buff 32)))
  (begin
    (map-set commits tx-sender { hash: hash, height: block-height })
    (ok true)
  )
)

;; @desc Reveals the payload and validates against commitment
(define-public (reveal (salt (buff 32)) (payload (buff 128)))
  (let (
      (user-commit (unwrap! (map-get? commits tx-sender) (err ERR_COMMIT_NOT_FOUND)))
      (computed-hash (contract-call? .encoding hash-data (concat salt payload)))
    )
    (asserts! (<= block-height (+ (get height user-commit) COMMIT_WINDOW)) (err ERR_COMMIT_EXPIRED))
    (asserts! (is-eq (get hash user-commit) computed-hash) (err ERR_INVALID_COMMIT))

    (map-set revealed-in-block tx-sender block-height)
    (map-delete commits tx-sender)
    (ok payload)
  )
)

(define-public (submit-bid (payload (buff 128)) (bid uint))
    (begin
        (asserts! (is-revealed tx-sender) (err ERR_COMMIT_NOT_FOUND))
        (map-set auction-bids { block: block-height, user: tx-sender } { payload: payload, bid: bid })
        (ok true)
    )
)

(define-public (process-auction (block uint))
    (let ((bids (map-get? auction-bids { block: block, user: tx-sender })))
        (match bids
            bid (ok true)
            (err ERR_COMMIT_NOT_FOUND)
        )
    )
)

;; @desc Checks if the user has revealed a valid commitment in the current block
(define-read-only (is-revealed (user principal))
  (is-eq (map-get? revealed-in-block user) (some block-height))
)
