;; community-governance-token.clar
;; Conxian PaaS Standard: Community Governance Token Template
;; Standard SIP-010 Token with Governance Checkpoints (Vote Weighting)
;; Tier 0: "Hands-Off" DAO Token

(impl-trait .sip-standards.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_NOT_TOKEN_OWNER (err u1001))
(define-constant ERR_NON_COMPLIANT (err u1002))

;; Data Vars
(define-data-var token-name (string-ascii 32) "Community Governance Token")
(define-data-var token-symbol (string-ascii 10) "CGT")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal tx-sender)

;; Token
(define-fungible-token cgt)

;; Delegation Maps
(define-map delegates principal principal) ;; user -> delegatee
(define-map votes-delegated-to principal uint) ;; user -> total votes delegated to them

;; Authorization
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Compliance
(define-private (check-compliance (user principal))
    (let ((compliance-status (contract-call? .regulatory-adapter check-clean-hands-compliance user)))
        (if (is-ok compliance-status) true false)
    )
)

;; --- Delegation Logic ---

(define-private (get-delegated-votes (user principal))
    (default-to u0 (map-get? votes-delegated-to user))
)

(define-private (increase-delegated-votes (delegatee principal) (amount uint))
    (map-set votes-delegated-to delegatee (+ (get-delegated-votes delegatee) amount))
)

(define-private (decrease-delegated-votes (delegatee principal) (amount uint))
    (let ((current-votes (get-delegated-votes delegatee)))
        (if (>= current-votes amount)
            (map-set votes-delegated-to delegatee (- current-votes amount))
            (map-set votes-delegated-to delegatee u0)
        )
    )
)

;; Updates delegation power when tokens move
(define-private (move-delegation (sender principal) (recipient principal) (amount uint))
    (begin
        ;; If sender delegates, decrease delegatee's power
        (match (map-get? delegates sender)
            delegatee (decrease-delegated-votes delegatee amount)
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
        (balance (ft-get-balance cgt delegator))
    )
        (asserts! (check-compliance delegator) ERR_NON_COMPLIANT)
        (asserts! (check-compliance delegatee) ERR_NON_COMPLIANT)
        (asserts! (not (is-eq delegator delegatee)) ERR_UNAUTHORIZED) ;; Cannot delegate to self (undelegate instead)

        ;; Remove old delegation
        (match (map-get? delegates delegator)
            old-delegatee (decrease-delegated-votes old-delegatee balance)
            true
        )

        ;; Set new delegation
        (map-set delegates delegator delegatee)
        (increase-delegated-votes delegatee balance)
        
        (print { event: "delegate", delegator: delegator, delegatee: delegatee, amount: balance })
        (ok true)
    )
)

;; @desc Revoke delegation (Self-Representation)
(define-public (revoke-delegation)
    (let (
        (delegator tx-sender)
        (balance (ft-get-balance cgt delegator))
    )
        (match (map-get? delegates delegator)
            delegatee 
            (begin
                (decrease-delegated-votes delegatee balance)
                (map-delete delegates delegator)
                (print { event: "revoke-delegation", delegator: delegator, old-delegatee: delegatee })
                (ok true)
            )
            (err u1003) ;; ERR_NOT_DELEGATING
        )
    )
)

;; @desc Get current voting power (Balance + Delegated In - Delegated Out)
(define-read-only (get-voting-power (user principal))
    (let (
        (balance (ft-get-balance cgt user))
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
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
        
        ;; Enforce Clean Hands Compliance for Sender AND Recipient
        (asserts! (check-compliance sender) ERR_NON_COMPLIANT)
        (asserts! (check-compliance recipient) ERR_NON_COMPLIANT)

        (try! (ft-transfer? cgt amount sender recipient))
        
        ;; Adjust Voting Power
        (move-delegation sender recipient amount)

        (match memo to-print (print to-print) 0x)
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
    (ok (ft-get-balance cgt who))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply cgt))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Governance / Minting
;; Only the owner (DAO/Timelock) can mint
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (try! (ft-mint? cgt amount recipient))
        
        ;; Update delegation power if recipient is delegating
        (match (map-get? delegates recipient)
            delegatee (increase-delegated-votes delegatee amount)
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
