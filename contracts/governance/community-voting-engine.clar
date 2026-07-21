;; community-voting-engine.clar
;; Strategic community governance with escrowed CXVG voting power.
;;
;; This contract deliberately records and settles votes only. It does not
;; execute arbitrary proposal actions or withdraw treasury assets.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; Route names are the canonical contract names registered in
;; operational-treasury. The registry is intentionally the source of truth;
;; no production token or compliance principal is hard-coded here.
(define-constant TOKEN_ROUTE_KEY "cxvg-token")
(define-constant COMPLIANCE_ROUTE_KEY "regulatory-adapter")
(define-constant CURRENT_CONTRACT .community-voting-engine)

;; Error codes
(define-constant ERR_ROUTE_MISSING u2100)
(define-constant ERR_ROUTE_MISMATCH u2101)
(define-constant ERR_TOKEN_CALL_FAILED u2102)
(define-constant ERR_COMPLIANCE_CALL_FAILED u2103)
(define-constant ERR_NON_COMPLIANT u2104)
(define-constant ERR_START_NOT_FUTURE u2105)
(define-constant ERR_INVALID_DURATION u2106)
(define-constant ERR_INVALID_THRESHOLD u2107)
(define-constant ERR_ZERO_SUPPLY u2108)
(define-constant ERR_UNKNOWN_PROPOSAL u2109)
(define-constant ERR_NOT_STARTED u2110)
(define-constant ERR_VOTING_ENDED u2111)
(define-constant ERR_INVALID_AMOUNT u2112)
(define-constant ERR_ALREADY_VOTED u2113)
(define-constant ERR_ALREADY_FINALIZED u2114)
(define-constant ERR_VOTING_ACTIVE u2115)
(define-constant ERR_NOT_FINALIZED u2116)
(define-constant ERR_NOT_VOTED u2117)
(define-constant ERR_ALREADY_CLAIMED u2118)
(define-constant ERR_TOKEN_MISMATCH u2119)
(define-constant ERR_COMPLIANCE_MISMATCH u2120)
(define-constant ERR_SUPPLY_TOO_LARGE u2121)
(define-constant ERR_SNAPSHOT_CAP u2122)

;; Governance limits and basis-point arithmetic. Clarity uint values are
;; bounded at 2^128 - 1, so this cap makes every multiplication by the
;; basis-point denominator provably safe.
(define-constant BPS_DENOMINATOR u10000)
(define-constant MAX_VOTING_DURATION u100000)
(define-constant MAX_SAFE_SUPPLY u34028236692093846346337460743176821)

;; Proposal IDs start at one so u0 remains an unambiguous invalid ID.
(define-data-var next-proposal-id uint u1)

(define-map proposals
  uint
  {
    proposer: principal,
    start-block: uint,
    end-block: uint,
    total-supply-snapshot: uint,
    quorum-bps: uint,
    approval-bps: uint,
    yes-deposited: uint,
    no-deposited: uint,
    finalized: bool,
    passed: bool,
    token: principal,
    compliance: principal
  })

(define-map votes
  { proposal-id: uint, voter: principal }
  {
    amount: uint,
    support: bool,
    claimed: bool
  })

;; --- Fail-closed route and adapter helpers ---

(define-private (verify-token-route (token <sip-010-ft-trait>))
  (let (
      (registered-token
        (unwrap!
          (contract-call? .operational-treasury
            get-protocol-principal TOKEN_ROUTE_KEY)
          (err ERR_ROUTE_MISSING)))
    )
    (asserts!
      (is-eq registered-token (contract-of token))
      (err ERR_ROUTE_MISMATCH))
    (ok true)
  )
)

(define-private (verify-compliance-route (compliance <regulatory-adapter-trait>))
  (let (
      (registered-compliance
        (unwrap!
          (contract-call? .operational-treasury
            get-protocol-principal COMPLIANCE_ROUTE_KEY)
          (err ERR_ROUTE_MISSING)))
    )
    (asserts!
      (is-eq registered-compliance (contract-of compliance))
      (err ERR_ROUTE_MISMATCH))
    (ok true)
  )
)

(define-private (assert-compliant
    (compliance <regulatory-adapter-trait>)
    (user principal))
  (match (contract-call? compliance check-clean-hands-compliance user)
    compliant (if compliant
      (ok true)
      (err ERR_NON_COMPLIANT))
    adapter-error (err ERR_COMPLIANCE_CALL_FAILED)
  )
)

(define-private (read-total-supply (token <sip-010-ft-trait>))
  (match (contract-call? token get-total-supply)
    supply (ok supply)
    token-error (err ERR_TOKEN_CALL_FAILED)
  )
)

(define-private (transfer-checked
    (token <sip-010-ft-trait>)
    (amount uint)
    (sender principal)
    (recipient principal))
  (match (contract-call? token transfer amount sender recipient none)
    transferred (if transferred
      (ok true)
      (err ERR_TOKEN_CALL_FAILED))
    token-error (err ERR_TOKEN_CALL_FAILED)
  )
)

;; --- Proposal lifecycle ---

;; @desc Creates a future, bounded proposal and snapshots CXVG supply.
;; @param start-block: First Stacks block at which voting is permitted.
;; @param end-block: Exclusive end block for voting.
;; @param quorum-bps: Minimum escrow participation as basis points of the snapshot.
;; @param approval-bps: Minimum yes share as basis points of participation.
;; @param token: SIP-010 token route supplied by the caller.
;; @param compliance: Regulatory adapter route supplied by the caller.
;; @return The monotonic proposal ID.
;;
;; The token and compliance trait parameters are intentional: principals read
;; from operational-treasury cannot be used as arbitrary contract-call targets.
;; The supply snapshot fixes the aggregate denominator, not each wallet's
;; balance. Tokens acquired after creation may vote during the window, but the
;; total escrow for the proposal cannot exceed this snapshot.
(define-public (create-proposal
    (start-block uint)
    (end-block uint)
    (quorum-bps uint)
    (approval-bps uint)
    (token <sip-010-ft-trait>)
    (compliance <regulatory-adapter-trait>))
  (let (
      (current-block stacks-block-height)
      (proposal-id (var-get next-proposal-id))
      (token-principal (contract-of token))
      (compliance-principal (contract-of compliance))
    )
    (begin
      (try! (verify-token-route token))
      (try! (verify-compliance-route compliance))
      (try! (assert-compliant compliance tx-sender))

      (asserts! (> start-block current-block) (err ERR_START_NOT_FUTURE))
      (asserts! (> end-block start-block) (err ERR_INVALID_DURATION))
      (asserts!
        (<= (- end-block start-block) MAX_VOTING_DURATION)
        (err ERR_INVALID_DURATION))
      (asserts!
        (and
          (> quorum-bps u0)
          (<= quorum-bps BPS_DENOMINATOR)
          (> approval-bps u0)
          (<= approval-bps BPS_DENOMINATOR))
        (err ERR_INVALID_THRESHOLD))

      (let ((total-supply (try! (read-total-supply token))))
        (asserts! (> total-supply u0) (err ERR_ZERO_SUPPLY))
        (asserts! (<= total-supply MAX_SAFE_SUPPLY) (err ERR_SUPPLY_TOO_LARGE))

        (map-set proposals proposal-id {
          proposer: tx-sender,
          start-block: start-block,
          end-block: end-block,
          total-supply-snapshot: total-supply,
          quorum-bps: quorum-bps,
          approval-bps: approval-bps,
          yes-deposited: u0,
          no-deposited: u0,
          finalized: false,
          passed: false,
          token: token-principal,
          compliance: compliance-principal
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (print {
          event: "community-proposal-created",
          proposal-id: proposal-id,
          proposer: tx-sender,
          start-block: start-block,
          end-block: end-block,
          total-supply-snapshot: total-supply,
          quorum-bps: quorum-bps,
          approval-bps: approval-bps,
          token: token-principal,
          compliance: compliance-principal
        })
        (ok proposal-id)
      )
    )
  )
)

;; @desc Escrows a single immutable CXVG vote during the active window.
;; @param proposal-id: Proposal being voted on.
;; @param support: True for yes, false for no.
;; @param amount: Nonzero CXVG amount transferred into this contract.
;; @param token: SIP-010 token route supplied by the caller.
;; @param compliance: Regulatory adapter route supplied by the caller.
;; @return True after the escrow and vote record are committed.
(define-public (vote
    (proposal-id uint)
    (support bool)
    (amount uint)
    (token <sip-010-ft-trait>)
    (compliance <regulatory-adapter-trait>))
  (let (
      (proposal
        (unwrap! (map-get? proposals proposal-id) (err ERR_UNKNOWN_PROPOSAL)))
      (current-block stacks-block-height)
      (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
      (participation
        (+ (get yes-deposited proposal) (get no-deposited proposal)))
    )
    (begin
      (asserts! (>= current-block (get start-block proposal)) (err ERR_NOT_STARTED))
      (asserts! (< current-block (get end-block proposal)) (err ERR_VOTING_ENDED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (is-none existing-vote) (err ERR_ALREADY_VOTED))

      (asserts!
        (is-eq (get token proposal) (contract-of token))
        (err ERR_TOKEN_MISMATCH))
      (asserts!
        (is-eq (get compliance proposal) (contract-of compliance))
        (err ERR_COMPLIANCE_MISMATCH))
      (try! (verify-token-route token))
      (try! (verify-compliance-route compliance))
      (try! (assert-compliant compliance tx-sender))

      ;; Every successful vote preserves the invariant that cumulative escrow
      ;; is at most the immutable proposal supply snapshot. Compare against
      ;; remaining capacity before transfer so the addition cannot overflow.
      (asserts!
        (<= participation (get total-supply-snapshot proposal))
        (err ERR_SNAPSHOT_CAP))
      (asserts!
        (<= amount (- (get total-supply-snapshot proposal) participation))
        (err ERR_SNAPSHOT_CAP))

      ;; The token's SIP-010 sender check binds this transfer to the voter;
      ;; the recipient is this contract under the current contract context.
      (try! (transfer-checked token amount tx-sender CURRENT_CONTRACT))

      (map-set votes { proposal-id: proposal-id, voter: tx-sender } {
        amount: amount,
        support: support,
        claimed: false
      })
      (map-set proposals proposal-id
        (merge proposal {
          yes-deposited: (if support
            (+ (get yes-deposited proposal) amount)
            (get yes-deposited proposal)),
          no-deposited: (if support
            (get no-deposited proposal)
            (+ (get no-deposited proposal) amount))
        }))
      (print {
        event: "community-vote-cast",
        proposal-id: proposal-id,
        voter: tx-sender,
        support: support,
        amount: amount,
        escrowed: true
      })
      (ok true)
    )
  )
)

;; @desc Finalizes a proposal once its exclusive voting window has ended.
;; @param proposal-id: Proposal to finalize.
;; @return Whether quorum, approval, and strict yes-over-no tie rules passed.
(define-public (finalize-proposal (proposal-id uint))
  (let (
      (proposal
        (unwrap! (map-get? proposals proposal-id) (err ERR_UNKNOWN_PROPOSAL)))
      (participation
        (+ (get yes-deposited proposal) (get no-deposited proposal)))
    )
    (begin
      (asserts! (>= stacks-block-height (get end-block proposal)) (err ERR_VOTING_ACTIVE))
      (asserts! (not (get finalized proposal)) (err ERR_ALREADY_FINALIZED))

      (let (
          (quorum-reached
            (and
              (> (get total-supply-snapshot proposal) u0)
              (>=
                (* participation BPS_DENOMINATOR)
                (* (get total-supply-snapshot proposal) (get quorum-bps proposal)))))
          (approval-reached
            (and
              (> participation u0)
              (>=
                (* (get yes-deposited proposal) BPS_DENOMINATOR)
                (* participation (get approval-bps proposal)))))
          (passed
            (and
              quorum-reached
              approval-reached
              (> (get yes-deposited proposal) (get no-deposited proposal))))
        )
        (map-set proposals proposal-id
          (merge proposal { finalized: true, passed: passed }))
        (print {
          event: "community-proposal-finalized",
          proposal-id: proposal-id,
          participation: participation,
          yes-deposited: (get yes-deposited proposal),
          no-deposited: (get no-deposited proposal),
          quorum-reached: quorum-reached,
          approval-reached: approval-reached,
          passed: passed
        })
        (ok passed)
      )
    )
  )
)

;; @desc Returns a voter's escrow after finalization, once only.
;; @param proposal-id: Proposal containing the vote.
;; @param token: SIP-010 token route supplied by the caller.
;; @return The claimed CXVG amount.
(define-public (claim-stake
    (proposal-id uint)
    (token <sip-010-ft-trait>))
  (let (
      (proposal
        (unwrap! (map-get? proposals proposal-id) (err ERR_UNKNOWN_PROPOSAL)))
      (vote-record
        (unwrap!
          (map-get? votes { proposal-id: proposal-id, voter: tx-sender })
          (err ERR_NOT_VOTED)))
      (voter tx-sender)
    )
    (begin
      (asserts! (get finalized proposal) (err ERR_NOT_FINALIZED))
      ;; Claims validate the immutable token principal recorded with the
      ;; proposal. The current treasury route may rotate after escrow or
      ;; finalization; historical claims must remain live through the
      ;; proposal's original token contract.
      (asserts! (is-eq (get token proposal) (contract-of token)) (err ERR_TOKEN_MISMATCH))
      (asserts! (not (get claimed vote-record)) (err ERR_ALREADY_CLAIMED))

      (try!
        (as-contract
          (transfer-checked token
            (get amount vote-record)
            tx-sender
            voter)))
      (map-set votes { proposal-id: proposal-id, voter: tx-sender }
        (merge vote-record { claimed: true }))
      (print {
        event: "community-stake-claimed",
        proposal-id: proposal-id,
        voter: tx-sender,
        amount: (get amount vote-record),
        passed: (get passed proposal)
      })
      (ok (get amount vote-record))
    )
  )
)

;; --- Read-only audit and integration getters ---

;; @desc Returns stored proposal state, including escrow totals and outcome.
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

;; @desc Returns a principal's immutable vote and claim state.
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter }))

;; @desc Returns the next proposal ID that will be allocated.
(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id))

;; @desc Returns the maximum supply accepted for safe basis-point arithmetic.
(define-read-only (get-max-safe-supply)
  MAX_SAFE_SUPPLY)

;; @desc Reads a protocol route directly from operational-treasury.
(define-read-only (get-route (key (string-ascii 50)))
  (contract-call? .operational-treasury get-protocol-principal key))
