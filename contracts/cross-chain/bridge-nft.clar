;; bridge-nft.clar
;; CCTP/NTT Hardened Bridge Logic
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(define-non-fungible-token bridge-nft uint)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_ATTESTATION (err u402))
(define-constant ERR_NONCE_REUSED (err u403))

(define-data-var admin principal tx-sender)

;; Tracks used nonces from secure endpoints to prevent replay attacks
(define-map consumed-nonces (buff 32) bool)

;; Authorized TEE endpoint public keys mapping
(define-map authorized-endpoints (buff 33) bool)

(define-public (set-authorized-endpoint (endpoint-pubkey (buff 33)) (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (ok (map-set authorized-endpoints endpoint-pubkey status))
  )
)

;; @desc NTT Hardened Minting leveraging TEE-attested payloads
(define-public (cross-chain-mint (nft-id uint) (recipient principal) (nonce (buff 32)) (endpoint-pubkey (buff 33)) (attestation-sig (buff 65)))
  (let (
    (payload-hash (sha256 (unwrap! ( { id: nft-id, to: recipient, nonce: nonce }) (err u500))))
    (valid-sig (secp256k1-verify payload-hash attestation-sig endpoint-pubkey))
  )
    ;; 1. Validate the pubkey is authorized
    (asserts! (default-to false (map-get? authorized-endpoints endpoint-pubkey)) ERR_INVALID_ATTESTATION)

    ;; 2. Validate the signature logic
    (asserts! valid-sig ERR_INVALID_ATTESTATION)

    ;; 3. Prevent replay attacks using specific nonces
    (asserts! (is-none (map-get? consumed-nonces nonce)) ERR_NONCE_REUSED)

    ;; 4. State update
    (map-set consumed-nonces nonce true)

    ;; 5. Execution
    (try! (nft-mint? bridge-nft nft-id recipient))
    (ok true)
  )
)
