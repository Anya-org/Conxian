# Verification Guide

This guide helps you verify the AutoVault DeFi system locally (Clarinet) and on Stacks testnet.

- Vault: `stacks/contracts/vault.clar`
- Timelock: `stacks/contracts/timelock.clar`
- DAO: `stacks/contracts/dao.clar`
- Traits: `stacks/contracts/traits/*.clar`

## 1) Compile check

From `stacks/`:

```bash
clarinet check
```

Expected: all contracts checked successfully.

## 2) Local console verification

Start console in `stacks/`:

```bash
clarinet console
```

Run the following in the console:

```clj
;; Mint dev tokens and approve vault
(contract-call? .mock-ft mint tx-sender u1000000)
(contract-call? .mock-ft approve .vault u500000)

;; Deposit and check balance
(contract-call? .vault deposit u100000)
(contract-call? .vault get-balance tx-sender)

;; Withdraw and verify
(contract-call? .vault withdraw u20000)
```

## 3) Timelock governance (v1 static target)

```clj
;; Make timelock the admin of vault
(contract-call? .vault set-admin .timelock)

;; Queue a pause
(contract-call? .timelock queue-set-paused true)

;; Mine >= min-delay blocks
(advance-chain-tip u20)

;; Execute
(contract-call? .timelock execute-set-paused u0)

;; Verify paused state
(contract-call? .vault get-paused)
```

## 4) Timelock governance v2 (dynamic target via trait)

The timelock has v2 execute functions that accept a trait-typed parameter implementing `vault-admin-trait`. This allows dynamic targeting without static `.vault` references.

- Trait: `stacks/contracts/traits/vault-admin-trait.clar`
- Vault implements the trait via `impl-trait`.

Example dynamic executions (after queueing via the usual `queue-*` entrypoints):

```clj
;; Execute against a dynamic target
;; Replace `.vault` with any contract implementing vault-admin-trait
(define-constant target .vault)

(contract-call? .timelock execute-set-fees-v2 u0 target)
(contract-call? .timelock execute-set-paused-v2 u1 target)
(contract-call? .timelock execute-set-global-cap-v2 u2 target)
(contract-call? .timelock execute-set-user-cap-v2 u3 target)
(contract-call? .timelock execute-set-rate-limit-v2 u4 target)
(contract-call? .timelock execute-set-token-v2 u5 target)
(contract-call? .timelock execute-withdraw-reserve-v2 u6 target)
(contract-call? .timelock execute-set-treasury-v2 u7 target)
(contract-call? .timelock execute-set-fee-split-bps-v2 u8 target)
(contract-call? .timelock execute-withdraw-treasury-v2 u9 target)
(contract-call? .timelock execute-set-auto-fees-v2 u10 target)
```

Notes:
- Queue functions remain unchanged and store parameters and eta.
- Trait references cannot be stored; we pass the target contract implementing the trait to `execute-*-v2` at execution time.

## 5) Testnet verification (read-only)

Use the Hiro API. Examples with `scripts/call-read.sh`:

```bash
# Fees
CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-fees ./scripts/call-read.sh | jq
# Paused
CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-paused ./scripts/call-read.sh | jq
# Balance (principal arg as CV hex)
ARGS_JSON='["0x{cv-hex}"]' CONTRACT_ADDR=SP... CONTRACT_NAME=vault FN=get-balance ./scripts/call-read.sh | jq
```

## 6) Verification script

```bash
./scripts/verify.sh
```

It runs `clarinet check` and prints the guided steps above.

## 7) Sanity checklist

- Vault deposits/withdrawals succeed; balances and reserves update.
- Timelock queues return ids; executes after `min-delay` succeed.
- v2 executions work with a trait-typed target (`vault-admin-trait`).
- DAO `propose-*` use static `.timelock` and compute threshold via `.gov-token` by design; future work may adapt DAO similarly with traits if needed.
