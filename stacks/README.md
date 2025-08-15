# AutoVault Stacks DeFi Scaffold

Minimal Stacks (Clarity) DeFi prototype using a simple vault contract.

## Layout

- `contracts/vault.clar` — Minimal vault with per-user accounting
- `contracts/traits/sip-010-trait.clar` — SIP-010 trait
- `contracts/mock-ft.clar` — Mock SIP-010 fungible token (dev only)
- `contracts/timelock.clar` — Minimal timelock governance for admin actions

## Requirements

- Clarinet CLI
  - macOS: `brew install hirosystems/tap/clarinet`
  - Linux: `curl -sSfL <https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-installer.sh> | sh`
  - Or download from: [Hiro Clarinet releases](https://github.com/hirosystems/clarinet/releases)
- Deno (required for `clarinet test`)
  - Linux/macOS: `curl -fsSL https://deno.land/install.sh | sh`
  - Ensure `~/.deno/bin` is on your PATH

## Quick start

```bash
# From stacks/ directory
clarinet --version
clarinet check
clarinet console
```

Inside the console, you can call contract functions:

```clj
(contract-call? .vault deposit u100)
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault withdraw u50)
```

## Tokenized flow with mock FT (dev)

```clj
;; 1) Mint tokens to yourself (tx-sender)
(contract-call? .mock-ft mint tx-sender u1000000)

;; 2) Approve the vault to spend tokens on your behalf
(contract-call? .mock-ft approve .vault u500000)

;; 3) Deposit (vault pulls tokens via transfer-from)
(contract-call? .vault deposit u100000)

;; 4) Inspect state
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault get-total-balance)
(contract-call? .vault get-protocol-reserve)

;; 5) Withdraw
(contract-call? .vault withdraw u20000)
```

Risk controls in `vault`:

- `set-paused`, `set-global-cap`, `set-user-cap`
- `set-rate-limit enabled cap-per-block`
- Fees: `set-fees deposit-bps withdraw-bps`
- Admin reserve withdrawal: `withdraw-reserve to amount`

## Timelock governance (optional)

Timelock queues admin actions and executes after a delay. To use:

1. Make timelock the admin of `vault`:
  ```clj
  ;; called by current admin (deployer)
  (contract-call? .vault set-admin .timelock)
  ```
2. Queue an action (e.g., set fees):
  ```clj
  (contract-call? .timelock queue-set-fees u50 u20) ;; returns id
  ```
3. After `min-delay` blocks, execute:
  ```clj
  (contract-call? .timelock execute-set-fees u0)
  ```

You can adjust the delay:

```clj
(contract-call? .timelock set-min-delay u30)
```

## Timelock governance v2 (dynamic target via trait)

For dynamic targeting of any vault-like contract, timelock exposes `execute-*-v2` functions that accept a parameter implementing `vault-admin-trait`.

```clj
;; Choose dynamic target that implements vault-admin-trait
(define-constant target .vault)

;; Execute against dynamic target
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

- Queue functions remain unchanged; parameters and ETA are stored on chain.
- Trait references cannot be stored; pass the target contract at execution time.

## Testnet API (Hiro)

Use Stacks Testnet API for read-only calls and tx broadcasting:

- Base: <https://api.testnet.hiro.so/>
- Read-only simulate: `POST /v2/contracts/call-read/{addr}/{name}/{fn}`
- Broadcast signed tx: `POST /v2/transactions`
- Tx status: `GET /extended/v1/tx/{txid}`
- Contract ABI: `GET /v2/contracts/interface/{addr}/{name}`

See `../docs/api.md` for curl examples.

## Verification Script

Run the helper script for compile checks and guided steps:

```bash
./scripts/verify.sh
```

See `../docs/verification.md` for full verification guidance (local console flows, timelock flows, testnet read-only calls).

## Next steps

- Add tests with `clarinet test` (fees, caps, rate-limit, reserve withdrawal).
- Deploy to testnet; set vault token via `set-token` to your chosen SIP-010 asset.
- Configure timelock as admin for production safety.
