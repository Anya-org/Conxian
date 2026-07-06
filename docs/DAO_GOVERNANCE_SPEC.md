# Conxian DAO Governance Specification
> Clarity-version: 4 | For: Conxian Protocol | Generated: 2026-07-06

## Overview

This document specifies the DAO governance architecture for Conxian, implementing the decentralized governance model per the Conxian Unified Theory v2.0 Phase 3 transition.

---

## 1. Governance Architecture

### 1.1 Three-Tier Permission Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Governance Hierarchy                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  TIER 1: IMMUTABLE (Cannot be changed by any governance)           │
│  ═══════════════════════════════════════════════════════════════   │
│  • Token supply cap (1,000,000,000 CXVG)                           │
│  • Core tokenomics constants (% per epoch, halving schedule)       │
│  • Upgrade mechanism type (Registry Pattern)                       │
│  • Treasury multisig threshold (3-of-5)                            │
│  • DAO proposal type restrictions                                   │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  TIER 2: GOVERNANCE-CONTROLLED (Requires on-chain vote)             │
│  ════════════════════════════════════════════════════════════════   │
│  • Operational parameters (fee thresholds, yield caps)              │
│  • New contract deployments (via Registry Pattern)                 │
│  • Treasury disbursements (up to 1M STX per proposal)             │
│  • Emergency pause activation (with 24h timelock)                   │
│  • Multisig signer replacement (with 48h timelock)                 │
│                                                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  TIER 3: OPERATOR-CONTROLLED (DAO can override)                    │
│  ════════════════════════════════════════════════════════════════   │
│  • Daily parameter tuning (within Tier 2 bounds)                   │
│  • Bug fixes via migration (with 12h timelock)                      │
│  • Performance optimizations                                        │
│  • Oracle updates                                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Voting Power Distribution

```clarity
;; veCXVG: Voting Escrow CXVG (Aerodrome-inspired)
;; Lock CXVG for up to 4 years to gain voting power

(define-constant MAX_LOCK_DURATION u10519200) ;; 4 years in blocks
(define-constant MIN_LOCK_DURATION u14400)     ;; ~1 month

(define-map ve_balances
  principal
  {
    balance: uint,
    unlock_time: uint,
    last_update: uint
  }
)

(define-read-only (get-voting-power (owner principal))
  (match (map-get? ve_balances owner)
    ve
    (let ((remaining-time (- (get unlock_time ve) stacks-block-height)))
      (if (> remaining-time u0)
        (/ (* (get balance ve) remaining-time) MAX_LOCK_DURATION)
        u0
      ))
    u0
  )
)
```

---

## 2. Proposal System

### 2.1 Proposal Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                       Proposal Lifecycle                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [CREATED] ──▶ [VOTING] ──▶ [TIMELOCK] ──▶ [EXECUTION] ──▶ [DONE] │
│       │            │             │              │                    │
│       │            │             │              ▼                    │
│       │            │             │         [FAILED]                  │
│       │            │             │              │                    │
│       │            │             └──────────────┘                    │
│       │            │                                                   │
│       │            ▼                                                   │
│       │      [DEFEATED] ─────────────────────────────────────────▶    │
│       │                                                             │
│       ▼                                                             │
│  [CANCELLED]                                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

States:
- CREATED: Proposal submitted, voting not started
- VOTING: Active voting period (72 hours)
- TIMELOCK: Post-vote delay before execution (24 hours for Tier 2)
- EXECUTION: Actions being executed
- DONE: Successfully completed
- FAILED: Execution failed or vetoed
- DEFEATED: Did not meet quorum
- CANCELLED: Withdrawn by proposer
```

### 2.2 Proposal Types

```clarity
;; Proposal type constants
(define-constant PROPOSAL_TYPE_PARAMETER u1)
(define-constant PROPOSAL_TYPE_TREASURY u2)
(define-constant PROPOSAL_TYPE_EMERGENCY u3)
(define-constant PROPOSAL_TYPE_UPGRADE u4)
(define-constant PROPOSAL_TYPE_GOVERNANCE u5)

;; Tier restrictions
(define-constant TIER2_TYPES (list PROPOSAL_TYPE_PARAMETER PROPOSAL_TYPE_TREASURY PROPOSAL_TYPE_EMERGENCY PROPOSAL_TYPE_UPGRADE))
(define-constant TIER3_TYPES (list PROPOSAL_TYPE_PARAMETER)) ;; Only parameter changes

(define-map proposals
  uint
  {
    proposal_type: uint,
    tier: uint,
    title: (string-ascii 64),
    description: (string-utf8 512),
    proposer: principal,
    created_at: uint,
    voting_ends: uint,
    timelock_ends: uint,
    votes_for: uint,
    votes_against: uint,
    status: (string-ascii 16),
    actions: (list 10 { target: principal, calldata: (buff 1024) }),
    discussion_url: (optional (string-ascii 128))
  }
)
```

### 2.3 Proposal Creation

```clarity
(define-public (create-proposal
  (proposal_type uint)
  (title (string-ascii 64))
  (description (string-utf8 512))
  (actions (list 10 { target: principal, calldata: (buff 1024) }))
  (discussion_url (optional (string-ascii 128)))
)
  (let (
    (voter-balance (get-voting-power tx-sender))
    (min-balance (if (is-eq proposal_type PROPOSAL_TYPE_EMERGENCY)
      u10000000000   ;; 10M veCXVG for emergency
      u1000000000    ;; 1M veCXVG for standard
    ))
    (timelock (if (is-eq proposal_type PROPOSAL_TYPE_EMERGENCY)
      u432           ;; 72h for emergency
      u144           ;; 24h for standard
    ))
    (proposal-id (+ (var-get proposal-count) u1))
  )
    ;; Validation
    (asserts! (>= voter-balance min-balance) ERR_INSUFFICIENT_BALANCE)
    (asserts! (or 
      (is-some (index-of TIER2_TYPES proposal_type))
      (is-some (index-of TIER3_TYPES proposal_type))
    ) ERR_INVALID_PROPOSAL_TYPE)
    
    ;; Create proposal
    (map-set proposals proposal-id {
      proposal_type: proposal_type,
      tier: (if (is-some (index-of TIER2_TYPES proposal_type)) u2 u3),
      title: title,
      description: description,
      proposer: tx-sender,
      created_at: stacks-block-height,
      voting_ends: (+ stacks-block-height u432), ;; 72h voting
      timelock_ends: u0,
      votes_for: u0,
      votes_against: u0,
      status: "voting",
      actions: actions,
      discussion_url: discussion_url
    })
    
    (var-set proposal-count proposal-id)
    (ok proposal-id)
  )
)
```

---

## 3. Voting Mechanism

### 3.1 Quorum Requirements

| Proposal Type | Quorum | Veto Threshold | Timelock |
|--------------|--------|----------------|----------|
| Tier 2 Parameter | 5% of supply | 10% against | 24 hours |
| Tier 2 Treasury | 10% of supply | 15% against | 48 hours |
| Tier 2 Emergency | 15% of supply | 20% against | 12 hours |
| Tier 2 Upgrade | 15% of supply | 20% against | 72 hours |
| Tier 3 Parameter | 2% of supply | 10% against | 12 hours |

```clarity
;; Total supply assumed: 1,000,000,000 CXVG
(define-constant SUPPLY_TOTAL u1000000000000000000) ;; 1B with 18 decimals
(define-constant QUORUM_5PCT u50000000000000000)    ;; 50M
(define-constant QUORUM_10PCT u100000000000000000)  ;; 100M
(define-constant QUORUM_15PCT u150000000000000000)  ;; 150M
(define-constant QUORUM_2PCT u20000000000000000)    ;; 20M

(define-private (get-quorum-threshold (proposal_type uint))
  (cond
    ((is-eq proposal_type PROPOSAL_TYPE_EMERGENCY) QUORUM_15PCT)
    ((is-eq proposal_type PROPOSAL_TYPE_UPGRADE) QUORUM_15PCT)
    ((is-eq proposal_type PROPOSAL_TYPE_TREASURY) QUORUM_10PCT)
    ((is-eq proposal_type PROPOSAL_TYPE_PARAMETER) QUORUM_5PCT)
    true QUORUM_2PCT
  )
)
```

### 3.2 Voting

```clarity
(define-map votes
  { proposal_id: uint, voter: principal }
  {
    for: bool,
    weight: uint,
    timestamp: uint
  }
)

(define-public (vote (proposal_id uint) (support bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal_id) ERR_NOT_FOUND))
    (voter-balance (get-voting-power tx-sender))
    (current-vote (map-get? votes { proposal_id: proposal_id, voter: tx-sender }))
  )
    ;; Validation
    (asserts! (is-eq (get status proposal) "voting") ERR_NOT_VOTING)
    (asserts! (< stacks-block-height (get voting_ends proposal)) ERR_VOTING_ENDED)
    (asserts! (> voter-balance u0) ERR_NO_VOTING_POWER)
    
    ;; Update or create vote
    (if (is-some current-vote)
      (let ((existing (unwrap! current-vote ERR_VOTE_EXISTS)))
        ;; Update vote totals
        (map-set proposals proposal_id
          (merge proposal {
            votes_for: (- (get votes_for proposal) (get weight existing)),
            votes_against: (- (get votes_against proposal) (get weight existing))
          })
        )
        (map-set votes { proposal_id: proposal_id, voter: tx-sender }
          { for: support, weight: voter-balance, timestamp: stacks-block-height }
        )
      )
      (map-set votes { proposal_id: proposal_id, voter: tx-sender }
        { for: support, weight: voter-balance, timestamp: stacks-block-height }
      )
    )
    
    ;; Update proposal totals
    (map-set proposals proposal_id
      (merge proposal {
        votes_for: (if support (+ (get votes_for proposal) voter-balance) (get votes_for proposal)),
        votes_against: (if (not support) (+ (get votes_against proposal) voter-balance) (get votes_against proposal))
      })
    )
    
    (ok true)
  )
)
```

### 3.3 Vote Gauging

```clarity
;; Vote gating: Large holders must split votes across time
(define-public (vote-with-timelock (proposal_id uint) (support bool) (lock-duration uint))
  (let ((voter-balance (get-voting-power tx-sender)))
    (asserts! (<= lock-duration MAX_LOCK_DURATION) ERR_INVALID_LOCK)
    
    ;; Calculate gated weight (50% unlocked immediately, 50% locked)
    (let ((immediate-weight (/ voter-balance u2))
          (gated-weight (/ voter-balance u2)))
      
      ;; Cast immediate vote
      (try! (internal-vote proposal_id support immediate-weight))
      
      ;; Create timelocked vote
      (map-set timelocked-votes 
        { proposal_id: proposal_id, voter: tx-sender, unlock-height: (+ stacks-block-height lock-duration) }
        { support: support, weight: gated-weight }
      )
      
      (ok true)
    )
  )
)
```

---

## 4. Timelock & Execution

### 4.1 Timelock Enforcement

```clarity
(define-public (queue-for-execution (proposal_id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal_id) ERR_NOT_FOUND))
    (timelock-duration (get-timelock-for-type (get proposal_type proposal)))
  )
    ;; Validation
    (asserts! (is-eq (get status proposal) "voting") ERR_NOT_VOTING)
    (asserts! (>= stacks-block-height (get voting_ends proposal)) ERR_VOTING_ACTIVE)
    (asserts! 
      (>= (get votes_for proposal) (get-quorum-threshold (get proposal_type proposal)))
      ERR_NO_QUORUM
    )
    (asserts!
      (< (get votes_against proposal) (/ (get votes_for proposal) u2)) ;; < 50% veto
      ERR_VETOED
    )
    
    ;; Update to queued
    (map-set proposals proposal_id
      (merge proposal {
        status: "queued",
        timelock_ends: (+ stacks-block-height timelock-duration)
      })
    )
    
    (ok true)
  )
)
```

### 4.2 Execution

```clarity
(define-public (execute-proposal (proposal_id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal_id) ERR_NOT_FOUND))
    (timelock-duration (get-timelock-for-type (get proposal_type proposal)))
  )
    ;; Validation
    (asserts! (is-eq (get status proposal) "queued") ERR_NOT_QUEUED)
    (asserts! 
      (>= stacks-block-height (get timelock_ends proposal))
      ERR_TIMELOCK_ACTIVE
    )
    
    ;; Process timelocked votes
    (try! (process-timelocked-votes proposal_id))
    
    ;; Final quorum check after timelocked votes
    (asserts!
      (>= (get votes_for proposal) (get-quorum-threshold (get proposal_type proposal)))
      ERR_NO_QUORUM
    )
    
    ;; Execute actions
    (try! (execute-actions (get actions proposal) tx-sender))
    
    ;; Update status
    (map-set proposals proposal_id
      (merge proposal { status: "executed" })
    )
    
    (ok true)
  )
)

(define-private (execute-actions (actions (list 10 { target: principal, calldata: (buff 1024) })) (caller principal))
  (fold execute-single-action actions (ok true)
    (lambda (result action)
      (and result
        (contract-call? (get target action) (get calldata action))
      )
    )
  )
)
```

---

## 5. Treasury Management

### 5.1 Treasury Limits

```clarity
;; Tier 2 treasury limits
(define-constant MAX_SINGLE_PROPOSAL u1000000000000)    ;; 1M STX
(define-constant MAX_MONTHLY_TREASURY u5000000000000)   ;; 5M STX/month
(define-constant TREASURY_BALANCE_KEY "treasury-balance")

(define-map monthly-treasury-spend
  uint  ;; Month index
  uint  ;; Total spent
)
```

### 5.2 Treasury Proposal

```clarity
(define-public (create-treasury-proposal
  (recipient principal)
  (amount uint)
  (title (string-ascii 64))
  (description (string-utf8 512))
)
  (let (
    (current-month (/ stacks-block-height u4320)) ;; ~1 month
    (monthly-spent (default-to u0 (map-get? monthly-treasury-spend current-month)))
    (proposal-id (+ (var-get proposal-count) u1))
  )
    ;; Validation
    (asserts! (<= amount MAX_SINGLE_PROPOSAL) ERR_AMOUNT_TOO_LARGE)
    (asserts! 
      (<= (+ monthly-spent amount) MAX_MONTHLY_TREASURY)
      ERR_MONTHLY_LIMIT_EXCEEDED
    )
    (asserts! (not (is-eq recipient tx-sender)) ERR_SELF_TRANSFER)
    
    ;; Create proposal
    (map-set proposals proposal-id {
      proposal_type: PROPOSAL_TYPE_TREASURY,
      tier: u2,
      title: title,
      description: description,
      proposer: tx-sender,
      created_at: stacks-block-height,
      voting_ends: u0,
      timelock_ends: u0,
      votes_for: u0,
      votes_against: u0,
      status: "treasury",
      actions: (list
        {
          target: .treasury,
          calldata: (unwrap! (to-cons-buff? (tuple (recipient recipient) (amount amount))) ERR_INVALID_CALLDATA)
        }
      ),
      discussion_url: none
    })
    
    (var-set proposal-count proposal-id)
    (ok proposal-id)
  )
)
```

---

## 6. Emergency Controls

### 6.1 Emergency Pause

```clarity
;; Guardian multisig can trigger emergency pause without voting
(define-map emergency-pause
  {
    activator: principal,
    reason: (string-utf8 256)
  }
  uint  ;; Block when activated
)

(define-public (emergency-pause (reason (string-utf8 256)))
  (let (
    (caller-role (get-role tx-sender))
  )
    ;; Validation: Must be guardian or admin
    (asserts! 
      (or (is-eq caller-role ROLE_GUARDIAN) (is-eq caller-role ROLE_ADMIN))
      ERR_UNAUTHORIZED
    )
    
    ;; Set pause
    (var-set paused true)
    
    ;; Log emergency
    (map-set emergency-pause 
      { activator: tx-sender, reason: reason }
      stacks-block-height
    )
    
    ;; Emit event
    (print {
      event: "emergency-pause",
      activator: tx-sender,
      reason: reason,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Unpause requires DAO vote (not emergency)
(define-public (unpause)
  (let (
    (proposal (unwrap! (map-get? proposals (var-get proposal-count)) ERR_NOT_FOUND))
  )
    (asserts! (is-eq (get proposal_type proposal) PROPOSAL_TYPE_EMERGENCY) ERR_NOT_EMERGENCY)
    (asserts! (is-eq (get status proposal) "executed") ERR_NOT_EXECUTED)
    
    (var-set paused false)
    (ok true)
  )
)
```

---

## 7. veCXVG (Voting Escrow) Implementation

### 7.1 Lock Mechanism

```clarity
(define-public (create-lock (amount uint) (duration uint))
  (let (
    (existing-lock (map-get? ve_balances tx-sender))
    (min-duration MIN_LOCK_DURATION)
    (max-duration MAX_LOCK_DURATION)
    (end-time (+ stacks-block-height duration))
  )
    ;; Validation
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= duration min-duration) ERR_LOCK_TOO_SHORT)
    (asserts! (<= duration max-duration) ERR_LOCK_TOO_LONG)
    (asserts! 
      (or (is-none existing-lock) (< (get unlock_time existing-lock) stacks-block-height))
      ERR_EXISTING_LOCK
    )
    
    ;; Transfer CXVG to voting contract
    (try! (contract-call? .cxvg transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Create lock
    (map-set ve_balances tx-sender {
      balance: amount,
      unlock_time: end-time,
      last_update: stacks-block-height
    })
    
    (print {
      event: "create-lock",
      user: tx-sender,
      amount: amount,
      unlock_time: end-time
    })
    
    (ok end-time)
  )
)
```

### 7.2 Increase Lock

```clarity
(define-public (increase-amount (amount uint))
  (let ((existing-lock (unwrap! (map-get? ve_balances tx-sender) ERR_NO_LOCK)))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    
    ;; Transfer additional CXVG
    (try! (contract-call? .cxvg transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update lock
    (map-set ve_balances tx-sender
      (merge existing-lock {
        balance: (+ (get balance existing-lock) amount)
      })
    )
    
    (ok true)
  )
)

(define-public (extend-duration (additional-duration uint))
  (let (
    (existing-lock (unwrap! (map-get? ve_balances tx-sender) ERR_NO_LOCK))
    (new-end (+ (get unlock_time existing-lock) additional-duration))
  )
    (asserts! (<= new-end (+ stacks-block-height MAX_LOCK_DURATION)) ERR_LOCK_TOO_LONG)
    
    (map-set ve_balances tx-sender
      (merge existing-lock { unlock_time: new-end })
    )
    
    (ok true)
  )
)
```

---

## 8. Source Evidence

- [Stacks SIP Process](https://github.com/stacksgov/sips)
- [Nakamoto Voting Guide](https://stacks.org/nakamoto-voting-guide)
- [DAO-DAO (CosmWasm)](https://github.com/DA0-DA0/dao-contracts)
- [Velocity DAO (Clarity)](https://github.com/SaadTahir28/Velocity-DAO-Clarity)
- [Aerodrome veAERO](https://docs.aerodrome.co/veAERO)
- [CertiK Clarity Best Practices](https://www.certik.com/resources/blog/clarity-best-practices-and-checklist)

---

## 9. Implementation Checklist

- [ ] Deploy veCXVG contract
- [ ] Implement proposal factory
- [ ] Create voting mechanism
- [ ] Add timelock enforcement
- [ ] Implement treasury management
- [ ] Create emergency pause
- [ ] Add role-based permissions
- [ ] Write comprehensive tests
- [ ] External security audit
- [ ] Mainnet deployment plan

---

*Generated per Conxian Unified Theory v2.0 Phase 3 transition*
*For issues #462, #463, #465, #469, #470*
