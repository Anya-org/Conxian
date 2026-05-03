;; signed-data-base.clar
;; Conxian Protocol Standard Contract

;; signed-data-base.clar
;; Storage for Oracle and Off-Chain Data Signatures
;; Acts as a Data Availability layer for governance

(define-constant ERR_UNAUTHORIZED u1000)

;; Data Storage
(define-map signed-data
    (buff 32) ;; Data Hash
    {
        signer: principal,
        timestamp: uint,
        data-uri: (string-ascii 256)
    }
)

(define-data-var oracle-feed principal tx-sender)

;; Read
(define-read-only (get-data-info (hash (buff 32)))
    (map-get? signed-data hash)
)

;; Write

;; @desc Store data
;; @returns (response bool uint)
(define-public (store-data (hash (buff 32)) (uri (string-ascii 256)))
    (begin
        ;; Anyone can store but we track the signer
        (map-set signed-data hash {
            signer: tx-sender,
            timestamp: burn-block-height,
            data-uri: uri
        })
        (print { event: "data-stored", hash: hash, signer: tx-sender })
        (ok true)
    )
)
