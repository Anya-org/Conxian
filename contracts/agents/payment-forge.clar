;; payment-forge.clar
;; Payment Forge Agent (EXEC-ISO-0402)
;; Bridges ISO 20022 (Institutional) and x402 (Sovereign M2M) Settlement
;; Nakamoto-Aligned (Epoch 3.0 / Clarity 4)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait csf-trait .conxian-csf-trait.trait-csf-liquidity-v1)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_X402_SIG (err u5001))
(define-constant ERR_SETTLEMENT_FAILED (err u5002))
(define-constant ERR_INVALID_X402_PAYLOAD (err u5003))
(define-constant ERR_X402_REPLAY (err u5004))
(define-constant ERR_X402_SIGNER_NOT_REGISTERED (err u5005))
(define-constant ERR_INVALID_X402_PUBKEY (err u5006))
(define-constant ERR_VAULT_NOT_SET (err u5007))

(define-data-var admin principal tx-sender)
(define-data-var fiscal-vault-oracle (optional principal) none)

;; --- Settlement Registry ---
;; Transaction Hash -> ISO 20022 Verification Hash
(define-map settlement-registry (buff 32) (buff 32))

;; --- x402 Signature Registry ---
(define-map x402-signer-pubkeys principal (buff 33))
(define-map x402-consumed-msg-hashes (buff 32) bool)

;; --- Public Functions ---

;; @desc Trigger x402 M2M Settlement
;; Inspired by HTTP 402: Payment Required. AI Agent triggers instant settlement.
(define-public (trigger-x402-settlement (amount uint) (token <sip-010-trait>) (signature (buff 65)))
  (let (
    (vault (unwrap! (var-get fiscal-vault-oracle) ERR_VAULT_NOT_SET))
    (payload {
      amount: amount,
      token: (contract-of token),
      vault: vault,
      requester: tx-sender,
      epoch: burn-block-height,
      forge: (as-contract tx-sender)
    })
    (msg-hash (sha256 (unwrap! (to-consensus-buff? payload) ERR_INVALID_X402_PAYLOAD)))
    (pubkey (unwrap! (map-get? x402-signer-pubkeys tx-sender) ERR_X402_SIGNER_NOT_REGISTERED))
  )
    (begin
      ;; 1. Signature Verification (Temporary: registry-backed, admin-managed pubkeys)
      (asserts! (is-eq (len signature) u65) ERR_INVALID_X402_SIG)
      (asserts! (is-none (map-get? x402-consumed-msg-hashes msg-hash)) ERR_X402_REPLAY)
      (asserts! (secp256k1-verify msg-hash signature pubkey) ERR_INVALID_X402_SIG)
      (map-set x402-consumed-msg-hashes msg-hash true)
      
      ;; 2. Execute Transfer to SFC Vault
      (match (contract-call? token transfer amount tx-sender vault none)
        transfer-ok (begin
          (asserts! transfer-ok ERR_SETTLEMENT_FAILED)
          (print { event: "x402-settlement-executed", amount: amount, token: (contract-of token), actor: tx-sender })
          (ok true)
        )
        transfer-err (begin
          (print { event: "x402-settlement-failed", amount: amount, token: (contract-of token), actor: tx-sender, reason: transfer-err })
          ERR_SETTLEMENT_FAILED
        )
      )
    )
  )
)

;; @desc Authorize ISO 20022 Egress
;; Generates the on-chain "Audit Anchor" for a pacs.008 XML message.
(define-public (authorize-iso-20022-egress (tx-id (buff 32)) (iso-xml-hash (buff 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set settlement-registry tx-id iso-xml-hash)
    (print { event: "iso-20022-authorized", tx-id: tx-id, xml-hash: iso-xml-hash })
    (ok true)
  )
)

;; @desc Settle SBC Obligation
;; Programmatically clears debt for a Sovereign Business Cell via the Fiscal-Vault.
(define-public (settle-sbc-obligation (sbc (string-ascii 32)) (amount uint) (token <sip-010-trait>))
  (let ((vault (unwrap! (var-get fiscal-vault-oracle) ERR_VAULT_NOT_SET)))
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
      (try! (contract-call? vault release-funds-to-sbc sbc amount token))
      (ok true)
    )
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-iso-hash (tx-id (buff 32)))
  (map-get? settlement-registry tx-id)
)

(define-read-only (get-fiscal-vault-oracle)
  (var-get fiscal-vault-oracle)
)

;; --- Admin ---

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-fiscal-vault-oracle (vault principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set fiscal-vault-oracle (some vault))
    (ok true)
  )
)

(define-public (set-x402-signer-pubkey (signer principal) (pubkey (buff 33)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len pubkey) u33) ERR_INVALID_X402_PUBKEY)
    (map-set x402-signer-pubkeys signer pubkey)
    (ok true)
  )
)
