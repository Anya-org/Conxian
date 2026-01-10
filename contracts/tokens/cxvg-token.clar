;; cxvg-token.clar
;; Conxian Voting Token (CXVG)
;; Tier 0 Compliance: "Clean-Hands" Enforcement on Transfer
;; Represents governance power in the 5-Tier DAO.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NON_COMPLIANT (err u1001))

;; Data Vars
(define-data-var token-name (string-ascii 32) "Conxian Voting Token")
(define-data-var token-symbol (string-ascii 10) "CXVG")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal tx-sender)

;; Token
(define-fungible-token cxvg)

;; Delegation Maps
(define-map delegates
  principal
  principal
)
;; user -> delegatee
(define-map votes-delegated-to
  principal
  uint
)
;; user -> total votes delegated to them

;; Authorization
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Compliance Check
(define-private (check-compliance (user principal))
  (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
    (if (is-ok compliance-status)
      true
      false
    )
  )
)

;; --- Delegation Logic ---

(define-private (get-delegated-votes (user principal))
  (default-to u0 (map-get? votes-delegated-to user))
)

(define-private (increase-delegated-votes
    (delegatee principal)
    (amount uint)
  )
  (map-set votes-delegated-to delegatee
    (+ (get-delegated-votes delegatee) amount)
  )
)

(define-private (decrease-delegated-votes
    (delegatee principal)
    (amount uint)
  )
  (let ((current-votes (get-delegated-votes delegatee)))
    (if (>= current-votes amount)
      (map-set votes-delegated-to delegatee (- current-votes amount))
      (map-set votes-delegated-to delegatee u0)
    )
  )
)

;; Updates delegation power when tokens move
(define-private (move-delegation
    (sender principal)
    (recipient principal)
    (amount uint)
  )
  (begin
    ;; If sender delegates, decrease delegatee's power
    (match (map-get? delegates sender)
      delegatee
      (decrease-delegated-votes delegatee amount)
      true ;; Do nothing if not delegating
    )
    ;; If recipient delegates, increase delegatee's power
    (match (map-get? delegates recipient)
      delegatee (increase-delegated-votes delegatee amount)
      true
    )
  )
)

;; Public Delegation Functions

;; @desc Delegate voting power to another address
(define-public (delegate (delegatee principal))
  (let (
      (delegator tx-sender)
      (balance (ft-get-balance cxvg delegator))
    )
    (asserts! (check-compliance delegator) ERR_NON_COMPLIANT)
    (asserts! (check-compliance delegatee) ERR_NON_COMPLIANT)
    (asserts! (not (is-eq delegator delegatee)) ERR_UNAUTHORIZED)
    ;; Cannot delegate to self (undelegate instead)

    ;; Remove old delegation
    (match (map-get? delegates delegator)
      old-delegatee (decrease-delegated-votes old-delegatee balance)
      true
    )

    ;; Set new delegation
    (map-set delegates delegator delegatee)
    (increase-delegated-votes delegatee balance)

    (print {
      event: "delegate",
      delegator: delegator,
      delegatee: delegatee,
      amount: balance,
    })
    (ok true)
  )
)

;; @desc Revoke delegation (Self-Representation)
(define-public (revoke-delegation)
  (let (
      (delegator tx-sender)
      (balance (ft-get-balance cxvg delegator))
    )
    (match (map-get? delegates delegator)
      delegatee
      (begin
        (decrease-delegated-votes delegatee balance)
        (map-delete delegates delegator)
        (print {
          event: "revoke-delegation",
          delegator: delegator,
          old-delegatee: delegatee,
        })
        (ok true)
      )
      (err ERR_NOT_DELEGATING) ;; ERR_NOT_DELEGATING
    )
  )
)

;; @desc Get current voting power (Balance + Delegated In - Delegated Out)
(define-read-only (get-voting-power (user principal))
  (let (
      (balance (ft-get-balance cxvg user))
      (delegated-in (get-delegated-votes user))
      (is-delegating (is-some (map-get? delegates user)))
    )
    (if is-delegating
      delegated-in ;; If delegating, own balance doesn't count for self
      (+ balance delegated-in)
    )
  )
)

(define-read-only (get-delegate (user principal))
  (map-get? delegates user)
)

;; SIP-010 Interface
(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)

    ;; Enforce Clean Hands
    (asserts! (check-compliance sender) ERR_NON_COMPLIANT)
    (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)

    (try! (ft-transfer? cxvg amount sender recipient))

    ;; Adjust Voting Power
    (move-delegation sender recipient amount)

    (match memo
      to-print (print to-print)
      0x
    )
    (ok true)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance cxvg who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply cxvg))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Core Privileged Functions
;; Minting is restricted to the Protocol Coordinator or Emission Controller
(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    ;; Access Control: Only specific modules can mint
    (asserts!
      (or
        (is-owner)
        (is-eq tx-sender .token-system-coordinator)
        (is-eq tx-sender .token-emission-controller)
      )
      ERR_UNAUTHORIZED
    )

    (try! (ft-mint? cxvg amount recipient))

    ;; Update delegation power if recipient is delegating
    (match (map-get? delegates recipient)
      delegatee (increase-delegated-votes delegatee amount)
      true
    )
    (ok true)
  )
)

(define-public (burn
    (amount uint)
    (sender principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)

    (try! (ft-burn? cxvg amount sender))

    ;; Update delegation power if sender is delegating
    (match (map-get? delegates sender)
      delegatee (decrease-delegated-votes delegatee amount)
      true
    )
    (ok true)
  )
)

;; Admin
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)
  )
)
