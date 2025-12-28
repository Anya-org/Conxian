;; conxian-exit-queue.clar
;; Manages the "Pending Exit" queue for sBTC withdrawals.

;; --- Traits ---
(use-trait sip-009-nft .traits.sip-009-nft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_TICKET_NOT_FOUND (err u4002))
(define-constant ERR_NOT_TICKET_OWNER (err u4003))

(define-constant TICKET_ASSET "ExitTicket-NFT")

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)
(define-map pending-exits uint { amount: uint, user: principal, timestamp: uint })

;; --- NFT Definition ---
(define-non-fungible-token ExitTicket-NFT uint)

;; --- Public Functions ---

(define-public (request-fast-exit (amount uint))
  (begin
    ;; 1. Lock user's sBTC in the vault (simulated here)
    ;; In a real implementation, this would involve a contract-call to the vault
    (print { event: "sbtc-locked", user: tx-sender, amount: amount })

    ;; 2. Mint ExitTicket-NFT
    (let ((ticket-id (var-get last-token-id)))
      (try! (nft-mint? ExitTicket-NFT ticket-id tx-sender))
      (map-set pending-exits ticket-id { amount: amount, user: tx-sender, timestamp: block-height })
      (var-set last-token-id (+ ticket-id u1))

      (print {
        event: "exit-ticket-minted",
        user: tx-sender,
        ticket-id: ticket-id,
      })
      (ok ticket-id)
    )
  )
)

(define-public (claim-completed-exit (ticket-id uint))
  (begin
    (let ((exit-info (unwrap! (map-get? pending-exits ticket-id) ERR_TICKET_NOT_FOUND)))
      ;; 1. Burn the NFT. This implicitly verifies that tx-sender is the owner.
      (try! (nft-burn? ExitTicket-NFT ticket-id tx-sender))

      ;; 2. Send BTC to the current owner of the NFT (which is tx-sender)
      ;; This is a simulated transfer event
      (print {
        event: "btc-transfer",
        to: tx-sender,
        amount: (get amount exit-info),
      })

      (map-delete pending-exits ticket-id)
      (ok true)
    )
  )
)

;; --- SIP-009 NFT Trait Implementation ---

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://conxian.io/api/nft/exit-ticket/{id}"))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? ExitTicket-NFT token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (nft-transfer? ExitTicket-NFT token-id sender recipient)
  )
)
