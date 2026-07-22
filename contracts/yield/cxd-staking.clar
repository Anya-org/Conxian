;; cxd-staking.clar
;;
;; Phase 1 CXD staking infrastructure.
;;
;; Rewards are pre-funded CXD. The contract accounts for active stake and
;; pending withdrawals separately so reward claims can never spend principal.
;; Reward rate is denominated in raw CXD base units per burn block. The
;; cumulative reward-per-token value uses REWARD_PRECISION to preserve O(1)
;; proportional accrual without iterating over stakers.
;;
;; The local .cxd-token and .regulatory-adapter references are deliberate:
;; this contract is CXD-specific and must not accept an arbitrary SIP-010
;; token. Trait-parameterizing the token would make that invariant a caller
;; responsibility. Local references are dependency-declared in both Clarinet
;; manifests and do not embed deployed ST/SP principals.

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait regulatory-adapter-trait .core-traits.regulatory-adapter-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u8000)
(define-constant ERR_NON_COMPLIANT u8001)
(define-constant ERR_ZERO_STAKE u8002)
(define-constant ERR_INSUFFICIENT_STAKE u8003)
(define-constant ERR_PAUSED u8004)
(define-constant ERR_PENDING_UNSTAKE u8005)
(define-constant ERR_COOLDOWN u8006)
(define-constant ERR_NOT_FUNDED u8007)
(define-constant ERR_INVALID_RATE u8008)
(define-constant ERR_INVALID_COOLDOWN u8009)
(define-constant ERR_ARITHMETIC u8010)
(define-constant ERR_PRINCIPAL_PROTECTED u8011)
(define-constant ERR_NO_PENDING_UNSTAKE u8012)
(define-constant ERR_TOKEN_CALL u8013)
(define-constant ERR_INSUFFICIENT_BALANCE u8014)

;; --- Bounds and accounting precision ---
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant REWARD_PRECISION u1000000000000) ;; 1e12 fixed-point scale
(define-constant MAX_REWARD_RATE u1000000000000) ;; raw CXD base units/block
(define-constant MIN_COOLDOWN_BLOCKS u1)
(define-constant MAX_COOLDOWN_BLOCKS u1000000)
(define-constant DEFAULT_COOLDOWN_BLOCKS u100)

;; --- Configuration and global accounting ---
(define-data-var admin principal tx-sender)
(define-data-var total-active-stake uint u0)
(define-data-var total-pending-unstake uint u0)
(define-data-var reward-rate uint u0)
(define-data-var cooldown-blocks uint DEFAULT_COOLDOWN_BLOCKS)
(define-data-var staking-paused bool false)
(define-data-var reward-reserve uint u0)
(define-data-var reward-per-token-stored uint u0)
(define-data-var last-update-block uint burn-block-height)

;; Active stake is governance weight. Pending stake remains protected
;; principal but is intentionally excluded from rewards and governance weight.
(define-map positions
  principal
  {
    active-stake: uint,
    reward-per-token-paid: uint,
    accrued-rewards: uint,
    pending-unstake: uint,
    cooldown-end: uint
  }
)

;; --- Defensive arithmetic ---
(define-private (safe-add (left uint) (right uint))
  (if (> left (- MAX_UINT right))
    (err ERR_ARITHMETIC)
    (ok (+ left right))
  )
)

(define-private (safe-multiply (left uint) (right uint))
  (if (or (is-eq left u0) (is-eq right u0))
    (ok u0)
    (if (> left (/ MAX_UINT right))
      (err ERR_ARITHMETIC)
      (ok (* left right))
    )
  )
)

(define-private (safe-add-blocks (base uint) (window uint))
  (if (> window (- MAX_UINT base))
    (err ERR_ARITHMETIC)
    (ok (+ base window))
  )
)

;; --- Authorization and compliance ---
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (check-compliance
    (adapter <regulatory-adapter-trait>)
    (user principal))
  ;; Convert both adapter errors and a negative response into the same closed
  ;; error path. No unwrap-panic is used for an external compliance call.
  (match (contract-call? adapter check-clean-hands-compliance user)
    compliant (if compliant (ok true) (err ERR_NON_COMPLIANT))
    err-code (err ERR_NON_COMPLIANT)
  )
)

(define-private (cxd-transfer
    (token <sip-010-ft-trait>)
    (amount uint)
    (sender principal)
    (recipient principal))
  (match (contract-call? token transfer amount sender recipient none)
    transferred (if transferred (ok true) (err ERR_TOKEN_CALL))
    token-error (err ERR_TOKEN_CALL)
  )
)

(define-private (cxd-balance
    (token <sip-010-ft-trait>)
    (owner principal))
  (match (contract-call? token get-balance owner)
    balance (ok balance)
    token-error (err ERR_TOKEN_CALL)
  )
)

;; --- Position and reward accounting ---
(define-private (position-of (user principal))
  (default-to
    {
      active-stake: u0,
      reward-per-token-paid: u0,
      accrued-rewards: u0,
      pending-unstake: u0,
      cooldown-end: u0
    }
    (map-get? positions user)
  )
)

(define-private (calculate-reward-per-token)
  (let (
    (active-stake (var-get total-active-stake))
    (elapsed (- burn-block-height (var-get last-update-block)))
    (rate (var-get reward-rate))
  )
    (if (or (is-eq active-stake u0) (is-eq elapsed u0) (is-eq rate u0))
      (ok (var-get reward-per-token-stored))
      (let (
        (rate-time (try! (safe-multiply rate elapsed)))
        (scaled-rewards (try! (safe-multiply rate-time REWARD_PRECISION)))
        (increment (/ scaled-rewards active-stake))
      )
        (safe-add (var-get reward-per-token-stored) increment)
      )
    )
  )
)

(define-private (calculate-earned (position {
    active-stake: uint,
    reward-per-token-paid: uint,
    accrued-rewards: uint,
    pending-unstake: uint,
    cooldown-end: uint
  }) (current-reward-per-token uint))
  (let (
    (paid (get reward-per-token-paid position))
    (active-stake (get active-stake position))
  )
    (if (< current-reward-per-token paid)
      (err ERR_ARITHMETIC)
      (let (
        (reward-delta (- current-reward-per-token paid))
        (weighted-delta (try! (safe-multiply active-stake reward-delta)))
        (new-rewards (/ weighted-delta REWARD_PRECISION))
      )
        (safe-add (get accrued-rewards position) new-rewards)
      )
    )
  )
)

(define-private (checkpoint-global)
  (let ((current-reward-per-token (try! (calculate-reward-per-token))))
    (var-set reward-per-token-stored current-reward-per-token)
    (var-set last-update-block burn-block-height)
    (ok current-reward-per-token)
  )
)

(define-private (checkpoint-user (user principal))
  (let (
    (current-reward-per-token (try! (checkpoint-global)))
    (position (position-of user))
    (new-rewards (try! (calculate-earned position current-reward-per-token)))
  )
    (map-set positions user {
      active-stake: (get active-stake position),
      reward-per-token-paid: current-reward-per-token,
      accrued-rewards: new-rewards,
      pending-unstake: (get pending-unstake position),
      cooldown-end: (get cooldown-end position)
    })
    (ok true)
  )
)

(define-private (protected-principal)
  (safe-add (var-get total-active-stake) (var-get total-pending-unstake))
)

;; --- User actions ---

;; @desc Stake CXD and add it to active reward/governance weight.
(define-public (stake (amount uint))
  (begin
    (asserts! (not (var-get staking-paused)) (err ERR_PAUSED))
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (try! (check-compliance .regulatory-adapter tx-sender))
    (let ((balance (try! (cxd-balance .cxd-token tx-sender))))
      (asserts! (>= balance amount) (err ERR_INSUFFICIENT_BALANCE))
    )
    (try! (checkpoint-user tx-sender))
    (let (
      (position (position-of tx-sender))
      (new-active-stake (try! (safe-add (get active-stake position) amount)))
      (new-total-active-stake (try! (safe-add (var-get total-active-stake) amount)))
    )
      ;; The static local token call is the CXD-only enforcement boundary.
      (try! (cxd-transfer .cxd-token amount tx-sender (as-contract tx-sender)))
      (var-set total-active-stake new-total-active-stake)
      (map-set positions tx-sender {
        active-stake: new-active-stake,
        reward-per-token-paid: (get reward-per-token-paid position),
        accrued-rewards: (get accrued-rewards position),
        pending-unstake: (get pending-unstake position),
        cooldown-end: (get cooldown-end position)
      })
      (print {
        event: "cxd-stake",
        user: tx-sender,
        amount: amount,
        active-stake: new-active-stake,
        block: burn-block-height
      })
      (ok true)
    )
  )
)

;; @desc Request an unstake; active stake and governance weight decrease now.
(define-public (request-unstake (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (try! (checkpoint-user tx-sender))
    (let (
      (position (position-of tx-sender))
      (active-stake (get active-stake position))
      (pending-unstake (get pending-unstake position))
    )
      (asserts! (is-eq pending-unstake u0) (err ERR_PENDING_UNSTAKE))
      (asserts! (>= active-stake amount) (err ERR_INSUFFICIENT_STAKE))
      (let (
        (cooldown-end (try! (safe-add-blocks burn-block-height (var-get cooldown-blocks))))
        (new-total-pending (try! (safe-add (var-get total-pending-unstake) amount)))
      )
        (var-set total-active-stake (- (var-get total-active-stake) amount))
        (var-set total-pending-unstake new-total-pending)
        (map-set positions tx-sender {
          active-stake: (- active-stake amount),
          reward-per-token-paid: (get reward-per-token-paid position),
          accrued-rewards: (get accrued-rewards position),
          pending-unstake: amount,
          cooldown-end: cooldown-end
        })
        (print {
          event: "cxd-unstake-requested",
          user: tx-sender,
          amount: amount,
          active-stake: (- active-stake amount),
          cooldown-end: cooldown-end,
          block: burn-block-height
        })
        (ok true)
      )
    )
  )
)

;; @desc Complete the caller's one pending unstake after its cooldown.
(define-public (complete-unstake)
  (let (
    (user tx-sender)
    (position (position-of tx-sender))
  )
    (let (
      (pending-unstake (get pending-unstake position))
      (cooldown-end (get cooldown-end position))
    )
      (asserts! (> pending-unstake u0) (err ERR_NO_PENDING_UNSTAKE))
      (asserts! (>= burn-block-height cooldown-end) (err ERR_COOLDOWN))
      (try! (checkpoint-user tx-sender))
      ;; Keep the original user principal outside as-contract. Inside the
      ;; context switch tx-sender is the staking contract, which owns CXD.
      (try! (as-contract (cxd-transfer .cxd-token pending-unstake tx-sender user)))
      (var-set total-pending-unstake (- (var-get total-pending-unstake) pending-unstake))
      (let ((updated-position (position-of user)))
        (map-set positions user {
          active-stake: (get active-stake updated-position),
          reward-per-token-paid: (get reward-per-token-paid updated-position),
          accrued-rewards: (get accrued-rewards updated-position),
          pending-unstake: u0,
          cooldown-end: u0
        })
      )
      (print {
        event: "cxd-unstake-completed",
        user: tx-sender,
        amount: pending-unstake,
        block: burn-block-height
      })
      (ok pending-unstake)
    )
  )
)

(define-private (claim-rewards-for (user principal))
  (begin
    (try! (checkpoint-user user))
    (let (
      (position (position-of user))
      (rewards (get accrued-rewards position))
    )
      (if (is-eq rewards u0)
        (ok u0)
        (let (
          (protected (try! (protected-principal)))
          (balance (try! (cxd-balance .cxd-token (as-contract tx-sender))))
          (reserve (var-get reward-reserve))
        )
          ;; Both the tracked reserve and the live token balance must cover
          ;; the claim. The live balance check subtracts all protected
          ;; principal before any reward can leave the contract.
          (asserts! (>= reserve rewards) (err ERR_NOT_FUNDED))
          (asserts! (>= balance protected) (err ERR_PRINCIPAL_PROTECTED))
          (asserts! (>= (- balance protected) rewards) (err ERR_NOT_FUNDED))
          (var-set reward-reserve (- reserve rewards))
          (map-set positions user {
            active-stake: (get active-stake position),
            reward-per-token-paid: (get reward-per-token-paid position),
            accrued-rewards: u0,
            pending-unstake: (get pending-unstake position),
            cooldown-end: (get cooldown-end position)
          })
          (try! (as-contract (cxd-transfer .cxd-token rewards tx-sender user)))
          (print {
            event: "cxd-rewards-claimed",
            user: user,
            amount: rewards,
            block: burn-block-height
          })
          (ok rewards)
        )
      )
    )
  )
)

;; @desc Claim the caller's accrued, pre-funded CXD rewards.
(define-public (claim-rewards)
  (claim-rewards-for tx-sender)
)

;; @desc Compatibility alias for the historical reward claim entry point.
(define-public (get-reward)
  (claim-rewards-for tx-sender)
)

;; --- Admin actions ---

;; @desc Set the raw CXD reward rate per burn block.
(define-public (set-reward-rate (rate uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (<= rate MAX_REWARD_RATE) (err ERR_INVALID_RATE))
    (try! (checkpoint-global))
    (var-set reward-rate rate)
    (print { event: "cxd-reward-rate-updated", rate: rate, block: burn-block-height })
    (ok true)
  )
)

;; @desc Set the burn-block cooldown for future unstake requests.
(define-public (set-cooldown-blocks (blocks uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (and (>= blocks MIN_COOLDOWN_BLOCKS) (<= blocks MAX_COOLDOWN_BLOCKS)) (err ERR_INVALID_COOLDOWN))
    (var-set cooldown-blocks blocks)
    (print { event: "cxd-cooldown-updated", cooldown-blocks: blocks, block: burn-block-height })
    (ok true)
  )
)

;; @desc Pause or resume new staking. Claims and completed withdrawals remain open.
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set staking-paused paused)
    (print { event: "cxd-staking-pause-updated", paused: paused, block: burn-block-height })
    (ok true)
  )
)

;; @desc Transfer administrative configuration authority.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (print { event: "cxd-staking-admin-updated", admin: new-admin, block: burn-block-height })
    (ok true)
  )
)

;; @desc Pre-fund the contract's tracked CXD reward reserve.
(define-public (fund-rewards (amount uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_ZERO_STAKE))
    (let ((new-reserve (try! (safe-add (var-get reward-reserve) amount))))
      (try! (cxd-transfer .cxd-token amount tx-sender (as-contract tx-sender)))
      (var-set reward-reserve new-reserve)
      (print {
        event: "cxd-rewards-funded",
        funder: tx-sender,
        amount: amount,
        reward-reserve: new-reserve,
        block: burn-block-height
      })
      (ok true)
    )
  )
)

;; --- Read-only queries ---

;; @desc Return the current cumulative reward-per-token accumulator.
(define-read-only (reward-per-token)
  (calculate-reward-per-token)
)

;; @desc Explicit alias for integrations that prefer a getter-style name.
(define-read-only (get-reward-per-token)
  (calculate-reward-per-token)
)

;; @desc Return a user's accrued reward amount through the current block.
(define-read-only (earned (account principal))
  (let (
    (current-reward-per-token (try! (calculate-reward-per-token)))
    (position (position-of account))
  )
    (ok (try! (calculate-earned position current-reward-per-token)))
  )
)

;; @desc Explicit alias for the earned-reward query.
(define-read-only (get-earned (account principal))
  (let (
    (current-reward-per-token (try! (calculate-reward-per-token)))
    (position (position-of account))
  )
    (ok (try! (calculate-earned position current-reward-per-token)))
  )
)

;; @desc Return the full tracked position, or none before first interaction.
(define-read-only (get-position (user principal))
  (map-get? positions user)
)

;; @desc Return active stake, kept as a compatibility alias for old callers.
(define-read-only (get-user-balance (user principal))
  (ok (get active-stake (position-of user)))
)

;; @desc Active stake is the caller's governance weight.
(define-read-only (get-governance-weight (user principal))
  (get active-stake (position-of user))
)

;; @desc Return the tracked reserve. Claims additionally check live balance
;; after subtracting active and pending principal.
(define-read-only (get-available-reward-reserve)
  (ok (var-get reward-reserve))
)

;; @desc Return global staking, reward, reserve, and cooldown statistics.
(define-read-only (get-staking-stats)
  {
    total-staked: (var-get total-active-stake),
    total-active-stake: (var-get total-active-stake),
    total-pending-unstake: (var-get total-pending-unstake),
    reward-rate: (var-get reward-rate),
    reward-reserve: (var-get reward-reserve),
    staking-paused: (var-get staking-paused),
    cooldown-blocks: (var-get cooldown-blocks),
    reward-per-token: (match (calculate-reward-per-token)
      current current
      arithmetic-error (var-get reward-per-token-stored)
    ),
    last-update-block: (var-get last-update-block)
  }
)

;; @desc Return current administrative and configuration values.
(define-read-only (get-config)
  {
    admin: (var-get admin),
    reward-rate: (var-get reward-rate),
    cooldown-blocks: (var-get cooldown-blocks),
    staking-paused: (var-get staking-paused),
    reward-reserve: (var-get reward-reserve)
  }
)
