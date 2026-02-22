;; enhanced-governance-nft.clar
;; Conxian Governance: Council Seats
;; Implements SIP-009 for Governance Seats

(impl-trait .sip-standards.sip-009-nft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_NOT_FOUND u1001)
(define-constant ERR_SEAT_TAKEN u1002)
(define-constant ERR_SOULBOUND u6003)

;; Council IDs
(define-constant COUNCIL_CXD u1) ;; Core Protocol & Architecture
(define-constant COUNCIL_CXVG u2) ;; Risk & Vault Management
(define-constant COUNCIL_CXTR u3) ;; Treasury & Capital Allocation
(define-constant COUNCIL_CXS u4) ;; Staking & Yield Curves
(define-constant COUNCIL_CXLP u5) ;; Liquidity & AMM Weighting

;; Assets
(define-non-fungible-token seat uint)

;; State
(define-data-var last-seat-id uint u0)

;; Seat Metadata
(define-map seat-data
  uint ;; token-id
  {
    council-id: uint,
    voting-power: uint,
    member-type: (string-ascii 20), ;; "human", "autonomous-agent"
    created-at: uint,
  }
)

;; Mapping: Principal -> Council -> Seat ID (Enforce 1 seat per council)
(define-map member-seats
  {
    user: principal,
    council-id: uint,
  }
  uint
)

;; Tracking Total Power per Council
(define-map council-power
  uint
  uint
)

;; Access Control
(define-data-var access-control principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; SIP-009 Interface
(define-read-only (get-last-token-id)
  (ok (var-get last-seat-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? seat token-id))
)

(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    ;; Governance seats are soulbound by default in this version
    ;; Only admin can revoke/transfer via separate admin functions
    (err ERR_SOULBOUND)
  )
)

;; Core Logic

(define-public (mint-seat
    (recipient principal)
    (council-id uint)
    (voting-power uint)
    (member-type (string-ascii 20))
  )
  (let (
      (new-id (+ (var-get last-seat-id) u1))
      (current-power (default-to u0 (map-get? council-power council-id)))
    )
    ;; Check Admin Role via Conxian Access
    (asserts!
      (unwrap! (contract-call? .conxian-access has-role tx-sender u1)
        (err ERR_UNAUTHORIZED)
      )
      (err ERR_UNAUTHORIZED)
    )

    ;; Ensure user doesn't already have a seat on this council
    (asserts!
      (is-none (map-get? member-seats {
        user: recipient,
        council-id: council-id,
      }))
      (err ERR_SEAT_TAKEN)
    )

    (try! (nft-mint? seat new-id recipient))

    (map-set seat-data new-id {
      council-id: council-id,
      voting-power: voting-power,
      member-type: member-type,
      created-at: burn-block-height,
    })

    (map-set member-seats {
      user: recipient,
      council-id: council-id,
    }
      new-id
    )
    (map-set council-power council-id (+ current-power voting-power))
    (var-set last-seat-id new-id)
    (ok new-id)
  )
)

(define-public (burn-seat (seat-id uint))
  (let (
      (owner (unwrap! (nft-get-owner? seat seat-id) (err ERR_NOT_FOUND)))
      (metadata (unwrap! (map-get? seat-data seat-id) (err ERR_NOT_FOUND)))
      (council-id (get council-id metadata))
      (power (get voting-power metadata))
      (current-council-power (default-to u0 (map-get? council-power council-id)))
    )
    (asserts!
      (unwrap! (contract-call? .conxian-access has-role tx-sender u1)
        (err ERR_UNAUTHORIZED)
      )
      (err ERR_UNAUTHORIZED)
    )
    (try! (nft-burn? seat seat-id owner))
    (map-delete seat-data seat-id)
    (map-delete member-seats {
      user: owner,
      council-id: council-id,
    })

    ;; Update Total Power (Protect against underflow though shouldn't happen)
    (if (>= current-council-power power)
      (map-set council-power council-id (- current-council-power power))
      (map-set council-power council-id u0)
    )
    (ok true)
  )
)

;; Read-Only Helpers

(define-read-only (get-seat-power
    (user principal)
    (council-id uint)
  )
  (let ((power (match (map-get? member-seats {
      user: user,
      council-id: council-id,
    })
      seat-id (get voting-power (unwrap-panic (map-get? seat-data seat-id)))
      u0
    )))
    (ok power)
  )
)

(define-read-only (get-total-council-power (council-id uint))
  (let ((power (default-to u0 (map-get? council-power council-id))))
    (ok power)
  )
)

(define-read-only (get-seat-info (seat-id uint))
  (map-get? seat-data seat-id)
)
