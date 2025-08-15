# AutoVault (Stacks DeFi)

Fully on-chain DeFi prototype on Stacks using Clarity smart contracts. This repository has been migrated from a Rust prototype to a Clarity-only codebase.

## Layout

- `stacks/Clarinet.toml` — Clarinet project manifest
- `stacks/contracts/vault.clar` — Vault contract with per-user balances, admin, fees, and events
- `stacks/README.md` — Stacks-specific quickstart and usage
- `docs/` — Design and economics docs

## Requirements

- Clarinet CLI
  - macOS: `brew install hirosystems/tap/clarinet`
  - Linux: `curl -sSfL https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-installer.sh | sh`
  - Releases: https://github.com/hirosystems/clarinet/releases

## Quick start

```bash
cd stacks
clarinet check
clarinet console
```

Console usage examples:

```clj
(contract-call? .vault deposit u100)
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault withdraw u50)
```

## Roadmap

- SIP-010 fungible token integration (deposits/withdrawals with real tokens)
- Events and analytics
- Clarinet tests for accounting and fee logic
- Devnet profile for local chain
- Governance (DAO) for parameters and reserves

## Differentiation: Bitcoin layers

We build on Stacks (settled on Bitcoin), positioning protocol state and logic fully on-chain while leveraging Bitcoin anchoring and sBTC bridges for BTC-native flows.

See `docs/design.md` for business logic and `docs/economics.md` for sustainability/profitability notes.
