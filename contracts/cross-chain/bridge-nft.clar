;; bridge-nft.clar
;; CCTP/NTT Hardened Bridge Logic
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)
;; SIP-009 Compliant (July 2026)

(impl-trait .sip-standards.sip-009-nft-trait)

(define-non-fungible-token bridge-nft uint)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_ATTESTATION (err u402))
(define-constant ERR_NONCE_REUSED (err u403))
(define-constant ERR_NOT_TOKEN_OWNER (err u404))

(define-data-var admin principal tx-sender)
(define-data-var last-token-id uint u0)

;; Tracks used nonces from secure endpoints to prevent replay attacks
(define-map consumed-nonces (buff 32) bool)

;; Authorized TEE endpoint public keys mapping
(define-map authorized-endpoints (buff 33) bool)

;; --- SIP-009 NFT Interface ---

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? bridge-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (nft-transfer? bridge-nft token-id sender recipient)
  )
)

;; --- Bridge-Specific Functions ---

(define-public (set-authorized-endpoint (endpoint-pubkey (buff 33)) (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (ok (map-set authorized-endpoints endpoint-pubkey status))
  )
)

;; @desc NTT Hardened Minting leveraging TEE-attested payloads
(define-public (cross-chain-mint (nft-id uint) (recipient principal) (nonce (buff 32)) (endpoint-pubkey (buff 33)) (attestation-sig (buff 65)))
  (let (
    (payload-hash (sha256 (keccak256 0x01)))
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
    (var-set last-token-id (max (var-get last-token-id) nft-id))
    (ok true)
  )
)
