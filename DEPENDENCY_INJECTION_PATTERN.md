# Dependency Injection Pattern for Conxian Contracts

## Pattern Overview

Standardized approach for breaking circular dependencies using optional contract references and post-deployment configuration.

## Core Pattern Template

### 1. Optional Contract References
```clarity
;; Store contract references as optional principals
(define-data-var target-contract (optional principal) none)
(define-data-var system-integration-enabled bool false)
(define-data-var initialization-complete bool false)
```

### 2. Admin Configuration Functions
```clarity
;; Owner-only configuration after deployment
(define-public (set-target-contract (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set target-contract (some contract-address))
    (ok true)))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get target-contract)) (err ERR_NOT_CONFIGURED))
    (var-set system-integration-enabled true)
    (ok true)))
```

### 3. Safe Contract Calls with Fallbacks
```clarity
;; Protected contract calls with graceful degradation
(define-private (call-target-contract-safely (function-name (string-ascii 64)) (default-value uint))
  (if (and (var-get system-integration-enabled) (is-some (var-get target-contract)))
    (match (var-get target-contract)
      contract-ref 
        (match (contract-call? contract-ref function-name)
          success success
          error default-value)
      default-value)
    default-value))
```

### 4. Initialization Check Pattern
```clarity
;; Verify all dependencies are configured
(define-read-only (is-fully-initialized)
  (and 
    (is-some (var-get target-contract))
    (var-get system-integration-enabled)
    (var-get initialization-complete)))

(define-public (complete-initialization)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get target-contract)) (err ERR_NOT_CONFIGURED))
    (var-set initialization-complete true)
    (ok true)))
```

## Contract-Specific Implementation Plans

### cxd-token.clar Refactoring
**Current Issues:**
- Direct calls to protocol-invariant-monitor
- Direct calls to token-emission-controller  
- Direct calls to revenue-distributor

**Solution:**
```clarity
;; Replace direct calls with optional references
(define-data-var protocol-monitor (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var revenue-distributor (optional principal) none)
(define-data-var staking-contract (optional principal) none)

;; Safe system pause check with fallback
(define-read-only (is-system-paused)
  (if (and (var-get system-integration-enabled) (is-some (var-get protocol-monitor)))
    (match (var-get protocol-monitor)
      monitor-ref
        (match (contract-call? monitor-ref is-protocol-paused)
          paused paused
          error false)
      false)
    false))
```

### protocol-invariant-monitor.clar Refactoring
**Current Issues:**
- Direct calls to multiple token contracts
- Circular dependency with cxd-token

**Solution:**
```clarity
;; Optional token contract references
(define-data-var cxd-token-ref (optional principal) none)
(define-data-var emission-controller-ref (optional principal) none)
(define-data-var revenue-distributor-ref (optional principal) none)

;; Safe supply check with graceful degradation
(define-private (check-supply-conservation)
  (if (var-get system-integration-enabled)
    (match (var-get cxd-token-ref)
      token-ref
        (match (contract-call? token-ref get-total-supply)
          supply (ok supply)
          error (ok u0))
      (ok u0))
    (ok u0)))
```

### token-emission-controller.clar Enhancement
**Existing Good Patterns:**
- Already has `set-token-contracts` function
- Uses optional principal variables

**Improvements Needed:**
```clarity
;; Add initialization state tracking
(define-data-var all-contracts-configured bool false)

(define-public (validate-configuration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get cxd-contract)) (err ERR_CXD_NOT_SET))
    (asserts! (is-some (var-get cxvg-contract)) (err ERR_CXVG_NOT_SET))
    (var-set all-contracts-configured true)
    (ok true)))
```

## Event-Driven Communication Template

### Event Definition Pattern
```clarity
;; Event counter for unique identification
(define-data-var event-counter uint u0)

;; Standard event structure
(define-constant EVENT_TOKEN_MINT "token-mint")
(define-constant EVENT_TOKEN_BURN "token-burn")
(define-constant EVENT_STAKING_ACTION "staking-action")
(define-constant EVENT_REVENUE_DISTRIBUTION "revenue-distribution")

;; Emit structured events instead of direct calls
(define-private (emit-token-mint-event (recipient principal) (amount uint))
  (let ((event-id (+ (var-get event-counter) u1)))
    (var-set event-counter event-id)
    (print {
      event-type: EVENT_TOKEN_MINT,
      contract: (as-contract tx-sender),
      recipient: recipient,
      amount: amount,
      block-height: block-height,
      event-id: event-id,
      timestamp: (unwrap-panic (get-block-info? time block-height))
    })
    event-id))

(define-private (emit-token-burn-event (user principal) (amount uint))
  (let ((event-id (+ (var-get event-counter) u1)))
    (var-set event-counter event-id)
    (print {
      event-type: EVENT_TOKEN_BURN,
      contract: (as-contract tx-sender),
      user: user,
      amount: amount,
      block-height: block-height,
      event-id: event-id,
      timestamp: (unwrap-panic (get-block-info? time block-height))
    })
    event-id))
```

### Event Listener Pattern
```clarity
;; Authorized event sources for security
(define-map authorized-event-sources principal bool)

(define-public (authorize-event-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set authorized-event-sources source true)
    (ok true)))

;; Process events from authorized sources
(define-public (process-token-mint-event 
  (recipient principal) 
  (amount uint) 
  (event-id uint) 
  (source-contract principal))
  (begin
    (asserts! (default-to false (map-get? authorized-event-sources source-contract)) 
              (err ERR_UNAUTHORIZED))
    ;; Process the mint event without direct contract dependency
    (try! (update-mint-metrics recipient amount))
    (try! (record-event-processed event-id))
    (ok true)))

(define-public (process-token-burn-event 
  (user principal) 
  (amount uint) 
  (event-id uint) 
  (source-contract principal))
  (begin
    (asserts! (default-to false (map-get? authorized-event-sources source-contract)) 
              (err ERR_UNAUTHORIZED))
    ;; Process the burn event without direct contract dependency
    (try! (update-burn-metrics user amount))
    (try! (record-event-processed event-id))
    (ok true)))
```

### Event Processing Queue Pattern
```clarity
;; Event processing queue for reliable handling
(define-map pending-events
  uint ;; event-id
  {
    event-type: (string-ascii 32),
    source-contract: principal,
    data: (buff 512),
    processed: bool,
    retry-count: uint
  })

(define-data-var next-event-id uint u1)

(define-public (queue-event-for-processing 
  (event-type (string-ascii 32))
  (data (buff 512)))
  (let ((event-id (var-get next-event-id)))
    (map-set pending-events event-id {
      event-type: event-type,
      source-contract: tx-sender,
      data: data,
      processed: false,
      retry-count: u0
    })
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (process-queued-event (event-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (match (map-get? pending-events event-id)
      event-data
        (if (get processed event-data)
          (err ERR_ALREADY_PROCESSED)
          (begin
            ;; Process based on event type
            (try! (handle-event-by-type event-data))
            (map-set pending-events event-id 
              (merge event-data { processed: true }))
            (ok true)))
      (err ERR_NOT_FOUND))))
```

## Deployment Sequence

### Phase 1: Individual Contract Deployment
```bash
# Deploy contracts without dependencies
clarinet deployments apply --contracts="traits,tokens,enhanced" --no-integration

# Each contract starts with:
# - system-integration-enabled: false
# - all contract references: none
# - basic functionality only
```

### Phase 2: Configuration
```bash
# Configure contract references
clarinet console --execute="
(contract-call? .cxd-token set-protocol-monitor .protocol-invariant-monitor)
(contract-call? .cxd-token set-emission-controller .token-emission-controller)
(contract-call? .protocol-invariant-monitor set-cxd-token .cxd-token)
"
```

### Phase 3: System Activation
```bash
# Enable system integration
clarinet console --execute="
(contract-call? .cxd-token enable-system-integration)
(contract-call? .protocol-invariant-monitor enable-system-integration)
(contract-call? .token-emission-controller validate-configuration)
"
```

## Benefits of This Pattern

1. **No Circular Dependencies**: Contracts deploy independently
2. **Graceful Degradation**: Functions work without integration
3. **Flexible Configuration**: Post-deployment contract linking
4. **Event-Driven Communication**: Reduces tight coupling
5. **Initialization Verification**: Clear system state tracking
6. **Owner-Controlled**: Admin-only configuration functions

## Next Implementation Steps

1. Refactor cxd-token with dependency injection pattern
2. Update protocol-invariant-monitor with optional references
3. Enhance token-emission-controller initialization
4. Implement event-driven communication
5. Create deployment automation scripts
