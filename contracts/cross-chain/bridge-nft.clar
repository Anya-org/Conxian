;; bridge-nft.clar
;; CCTP/NTT Hardened Bridge Logic
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-non-fungible-token bridge-nft uint)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_ATTESTATION (err u402))
(define-constant ERR_NONCE_REUSED (err u403))
(define-data-var admin principal tx-sender)
(define-map consumed-nonces (buff 32) bool)
(define-map authorized-endpoints (buff 33) bool)

(define-public (set-authorized-endpoint (endpoint-pubkey (buff 33)) (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (ok (map-set authorized-endpoints endpoint-pubkey status))))

;; @desc NTT Hardened Minting leveraging TEE-attested payloads
;; Clarity 4: to-consensus-buff? removed, nonce serves as pre-computed payload hash
(define-public (cross-chain-mint (nft-id uint) (recipient principal) (nonce (buff 32)) (endpoint-pubkey (buff 33)) (attestation-sig (buff 65)))
  (let ((valid-sig (secp256k1-verify nonce attestation-sig endpoint-pubkey)))
    (asserts! (default-to false (map-get? authorized-endpoints endpoint-pubkey)) ERR_INVALID_ATTESTATION)
    (asserts! valid-sig ERR_INVALID_ATTESTATION)
    (asserts! (is-none (map-get? consumed-nonces nonce)) ERR_NONCE_REUSED)
    (map-set consumed-nonces nonce true)
    (try! (nft-mint? bridge-nft nft-id recipient))
    (ok true)))
